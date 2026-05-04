import Foundation

// 한 멀티데이 이벤트가 한 주(week) 안에서 차지하는 한 토막.
// EVENT_FEATURE.md §4.3 — 멀티데이는 주 경계마다 끊어져 다음 주에서 새로 시작한다.
//
// 예: 5/3(일) ~ 5/12(화) 종일 이벤트 → 한 주(5/3~5/9)에 segment 한 개, 다음 주(5/10~5/12)에 또 한 개.
// 각 segment는 그 주 안에서 (startCol, endCol) 범위와 자신의 트랙 번호를 들고 있다.
struct MultiDaySegment: Identifiable {
    let event: Event
    let weekIndex: Int       // 그리드 내 주 인덱스 (0 ~ weekCount-1)
    let startCol: Int        // 0(일) ~ 6(토) — 이 주 안에서 시작 칼럼
    let endCol: Int          // 0 ~ 6 — 이 주 안에서 마지막 칼럼(포함)
    var track: Int           // 트랙 번호 (0이 가장 위) — 트랙 할당 단계에서 채워진다.

    // ForEach 식별 키 — 같은 이벤트가 여러 주에 걸치면 weekIndex로 구분.
    var id: String { "\(event.id.uuidString)-w\(weekIndex)" }
}

// 멀티데이 segment 빌더 + 트랙 할당.
// CalendarGrid에서 호출되며, 셀 배열과 visible 이벤트들을 받아 그리는 데 필요한 segment 리스트를 만든다.
enum MultiDayLayout {
    // 단일 day 판정 — endAt은 배타적이라 1초 빼서 "마지막 포함 시점"으로 비교.
    // 종일 단일일: 5/15 00:00 ~ 5/16 00:00 → endInclusive 5/15 23:59:59 → 같은 날.
    // 종일 멀티: 5/15 00:00 ~ 5/17 00:00 → endInclusive 5/16 23:59:59 → 다른 날.
    // 시간지정도 동일 — 자정 넘으면 멀티로 간주.
    static func isMultiDay(_ ev: Event) -> Bool {
        let cal = Calendar.current
        let endInclusive = ev.endAt.addingTimeInterval(-1)
        return !cal.isDate(ev.startAt, inSameDayAs: endInclusive)
    }

    // 주어진 그리드 셀들과 이벤트들로 segment 배열 생성.
    // - §4.4 카테고리 필터(`isVisible == false`)는 호출자에서 이미 거른 events만 넘긴다고 가정.
    // - §4.5 트랙 우선순위: 시작 빠른 이벤트가 위 트랙(같은 startAt이면 createdAt 빠른 것).
    static func buildSegments(events: [Event], cells: [DayCellModel]) -> [MultiDaySegment] {
        let cal = Calendar.current
        let weekCount = cells.count / 7

        // 멀티데이만 추리고, 트랙 할당 우선순위대로 정렬.
        let multi = events
            .filter { isMultiDay($0) }
            .sorted { lhs, rhs in
                if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
                return lhs.createdAt < rhs.createdAt
            }

        // 1차 — 트랙 미할당 segment 만들기.
        var raw: [MultiDaySegment] = []
        for ev in multi {
            let evStartDay = cal.startOfDay(for: ev.startAt)
            // 표시는 "포함되는 마지막 날" 기준. endAt은 배타적이라 1초 빼서 그 날의 startOfDay로.
            let evEndDay = cal.startOfDay(for: ev.endAt.addingTimeInterval(-1))

            // §4.3 — 주 경계마다 segment를 만들고, 각 segment의 시작 셀에서 제목을 다시 표시한다.
            // (제목 표시는 MultiDayBar가 항상 하므로 별도 플래그 필요 없음.)
            for week in 0..<weekCount {
                let weekStart = cal.startOfDay(for: cells[week * 7].date)
                let weekEnd   = cal.startOfDay(for: cells[week * 7 + 6].date)

                // 이 주와 이벤트의 (날짜 단위) 겹치는 범위.
                let segStart = max(weekStart, evStartDay)
                let segEnd   = min(weekEnd, evEndDay)
                guard segStart <= segEnd else { continue }

                let startCol = cal.dateComponents([.day], from: weekStart, to: segStart).day ?? 0
                let endCol   = cal.dateComponents([.day], from: weekStart, to: segEnd).day ?? 0

                raw.append(MultiDaySegment(
                    event: ev,
                    weekIndex: week,
                    startCol: startCol,
                    endCol: endCol,
                    track: 0  // 다음 단계에서 채움
                ))
            }
        }

        // 2차 — 주별로 트랙 greedy 할당. 안 겹치는 가장 낮은 트랙에 배치.
        return assignTracks(raw)
    }

    // 주별 트랙 할당. 시작 칼럼 빠른 segment부터 처리, 안 겹치는 가장 낮은 트랙에 넣는다.
    private static func assignTracks(_ segments: [MultiDaySegment]) -> [MultiDaySegment] {
        // 주 단위로 그룹.
        var byWeek: [Int: [MultiDaySegment]] = [:]
        for seg in segments {
            byWeek[seg.weekIndex, default: []].append(seg)
        }

        var result: [MultiDaySegment] = []
        for (_, segs) in byWeek {
            // 시작 col 빠른 것부터, 동률이면 startAt 빠른 것부터.
            let sorted = segs.sorted { lhs, rhs in
                if lhs.startCol != rhs.startCol { return lhs.startCol < rhs.startCol }
                return lhs.event.startAt < rhs.event.startAt
            }

            // 각 트랙의 마지막 endCol 추적. 새 segment의 startCol > endCol[t]이면 그 트랙 재사용 가능.
            var trackEnds: [Int] = []
            for var seg in sorted {
                let trackIdx = trackEnds.firstIndex { $0 < seg.startCol } ?? trackEnds.count
                if trackIdx == trackEnds.count {
                    trackEnds.append(seg.endCol)
                } else {
                    trackEnds[trackIdx] = seg.endCol
                }
                seg.track = trackIdx
                result.append(seg)
            }
        }
        return result
    }

    // 셀별 트랙 점유 수 — 그 셀 위로 지나가는 막대 트랙의 (max track + 1).
    // DayCell이 이만큼의 invisible spacer를 만들어 단일일 chip이 막대 아래에 자리잡게 한다.
    static func cellTrackCounts(segments: [MultiDaySegment], weekCount: Int) -> [Int] {
        var counts = Array(repeating: 0, count: weekCount * 7)
        for seg in segments {
            for col in seg.startCol...seg.endCol {
                let idx = seg.weekIndex * 7 + col
                counts[idx] = max(counts[idx], seg.track + 1)
            }
        }
        return counts
    }
}
