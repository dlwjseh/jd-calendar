import SwiftUI

// 한 주(7개 셀)를 그리는 컨테이너.
// EVENT_FEATURE.md §4.3 — 멀티데이 막대를 셀 위에 overlay로 그리기 위해 셀 단위 grid가 아닌 주 단위로 묶었다.
//
// 구조:
// - 아래 layer: HStack의 7 DayCell — 날짜 + 단일일 chips + (멀티데이 자리만큼 invisible spacer)
// - 위 layer:  GeometryReader 안에 멀티데이 segment를 절대 위치로 배치
struct WeekRow: View {
    let weekIndex: Int
    let cells: [DayCellModel]                    // 이 주의 7개 셀
    let today: Date
    let isLastRow: Bool
    let perDayEvents: [Date: [Event]]            // 단일일 이벤트 (날짜 키)
    let perDayAllEvents: [Date: [Event]]         // §5.6 popover용 — 단일일 + 멀티데이 모두 (정렬 완료)
    let weekSegments: [MultiDaySegment]          // 이 주의 멀티데이 segment들 (이미 트랙 할당됨)
    let cellTrackCounts: [Int]                   // 7개 — 각 셀이 차지하는 멀티데이 트랙 수
    @Binding var selectedEventId: UUID?

    // 멀티데이 막대 한 줄(트랙)의 시각 높이. EventChip의 종일 박스와 동일.
    private static let trackHeight: CGFloat = 16
    // 트랙 사이 세로 spacing.
    private static let trackSpacing: CGFloat = 2
    // 셀 padding-top(5) + 날짜 라벨 영역(약 20pt) + chips 영역 padding-top(2) — 첫 트랙의 y 위치.
    // 라벨 영역 높이는 today capsule(minHeight 20)을 기준으로 잡았다. 비-오늘 라벨은 더 작지만
    // 한 그리드 안에 오늘 셀이 있을 수도 있어 일관성을 위해 동일 값으로.
    private static let firstTrackTop: CGFloat = 5 + 20 + 2
    // 셀 내부 좌우 padding — DayCell의 .padding(.leading, 6)/.padding(.trailing, 6)와 일치해야
    // 멀티데이 막대 양 끝이 단일일 chip과 같은 좌우 여백을 가진다.
    // segment 양 끝(시작 셀의 좌측 / 끝 셀의 우측)에만 적용 → 같은 segment 안 셀 사이는 가로 연속성 유지.
    private static let cellHorizontalPadding: CGFloat = 6

    var body: some View {
        // 아래 — 셀들. DayCell이 자기 안에서 multiDayTrackCount만큼 자리를 비운다.
        HStack(spacing: 0) {
            ForEach(0..<7, id: \.self) { col in
                let dayKey = Calendar.current.startOfDay(for: cells[col].date)
                DayCell(
                    cell: cells[col],
                    today: today,
                    isLastRow: isLastRow,
                    isLastCol: col == 6,
                    events: perDayEvents[dayKey] ?? [],
                    allEvents: perDayAllEvents[dayKey] ?? [],
                    multiDayTrackCount: cellTrackCounts[col],
                    selectedEventId: $selectedEventId
                )
            }
        }
        // 위 — 멀티데이 막대 overlay. .overlay는 자식이 부모(HStack) 크기를 받게 한다 —
        // ZStack + GeometryReader 조합이 sizing 문제를 일으킬 수 있어 overlay가 더 안전하다.
        // GeometryReader는 부모 영역(HStack 크기) 안에서 가로폭을 측정 → 셀 폭(=w/7) 계산.
        .overlay {
            GeometryReader { geo in
                let cellWidth = geo.size.width / 7
                ForEach(weekSegments) { seg in
                    let segCells = CGFloat(seg.endCol - seg.startCol + 1)
                    MultiDayBar(segment: seg, selectedEventId: $selectedEventId)
                        // 양 끝에 셀 padding 만큼 들여 — 단일일 chip과 같은 좌우 여백.
                        .frame(
                            width: cellWidth * segCells - 2 * Self.cellHorizontalPadding,
                            height: Self.trackHeight
                        )
                        .offset(
                            x: cellWidth * CGFloat(seg.startCol) + Self.cellHorizontalPadding,
                            y: barTopOffset(track: seg.track)
                        )
                }
            }
        }
    }

    // 트랙 번호 → 그 트랙 막대의 y 좌표.
    private func barTopOffset(track: Int) -> CGFloat {
        Self.firstTrackTop + CGFloat(track) * (Self.trackHeight + Self.trackSpacing)
    }
}
