import SwiftUI
import SwiftData

// 6주 × 7일 = 42칸짜리 달력 그리드.
// 이번 달 날짜만으로는 항상 42칸을 못 채우므로, 앞은 지난 달 끝부분, 뒤는 다음 달 앞부분으로 메운다.
struct CalendarGrid: View {
    let year: Int
    let month: Int
    // §5.1 — 한 번에 한 이벤트만 선택. ContentView에서 끌어내려 모든 셀에 같은 binding 전달.
    @Binding var selectedEventId: UUID?

    // 모든 이벤트를 한 번에 fetch — v1엔 데이터가 적으니 충분하다.
    // 데이터가 늘어나면 (year, month) 범위 predicate로 좁히는 최적화로 대체한다.
    @Query private var events: [Event]

    private let theme = CalendarTheme.light

    var body: some View {
        // 매번 buildMonthGrid를 호출 — 해/달이 바뀌면 새로 계산해서 5주(35칸) 또는 6주(42칸) 셀 모델을 받는다.
        let cells = buildMonthGrid(year: year, month: month)
        // 셀 개수에서 주 수를 역산 — 35면 5주, 42면 6주.
        let weekCount = cells.count / 7
        let today = Date()
        // §4.4 카테고리 필터를 한 번만 — 단일일/멀티데이가 같이 사용한다.
        let visibleEvents = events.filter { $0.category.isVisible }
        let perDay = singleDayEventsByDay(visibleEvents)
        // §5.6 popover용 — 그 날에 걸치는 모든 이벤트(단일일 + 멀티데이).
        let perDayAll = allEventsByDay(visibleEvents)
        let allSegments = MultiDayLayout.buildSegments(events: visibleEvents, cells: cells)
        let trackCounts = MultiDayLayout.cellTrackCounts(segments: allSegments, weekCount: weekCount)

        // VStack 안에 주(WeekRow)를 쌓는 구조. 각 행이 maxHeight: .infinity인 셀을 담아
        // SwiftUI가 부모가 준 세로 공간을 weekCount(5 또는 6)로 균등하게 자동 배분한다.
        VStack(spacing: 0) {
            ForEach(0..<weekCount, id: \.self) { week in
                let weekCells = Array(cells[week*7..<(week+1)*7])
                let weekSegs = allSegments.filter { $0.weekIndex == week }
                let weekTracks = Array(trackCounts[week*7..<(week+1)*7])
                WeekRow(
                    weekIndex: week,
                    cells: weekCells,
                    today: today,
                    isLastRow: week == weekCount - 1,
                    perDayEvents: perDay,
                    perDayAllEvents: perDayAll,
                    weekSegments: weekSegs,
                    cellTrackCounts: weekTracks,
                    selectedEventId: $selectedEventId
                )
            }
        }
        // 그리드 맨 위에도 1px 가로선 — 요일행과 첫 주를 분리.
        .overlay(alignment: .top) {
            Rectangle().fill(theme.line).frame(height: 1)
        }
    }

    // 단일일 이벤트만 (시작 날짜 00:00) 키로 묶어 dict로 반환. 멀티데이는 MultiDayLayout이 따로 처리.
    // - 호출자가 §4.4 카테고리 필터를 이미 적용한 visibleEvents를 넘긴다(중복 작업 방지).
    // - §4.5 셀 내 정렬: 종일 먼저 → startAt 오름차순 → createdAt 오름차순 타이브레이커.
    private func singleDayEventsByDay(_ visibleEvents: [Event]) -> [Date: [Event]] {
        var dict: [Date: [Event]] = [:]
        let cal = Calendar.current

        for ev in visibleEvents where !MultiDayLayout.isMultiDay(ev) {
            let key = cal.startOfDay(for: ev.startAt)
            dict[key, default: []].append(ev)
        }

        for key in dict.keys {
            dict[key]?.sort(by: eventOrdering)
        }
        return dict
    }

    // §4.5 정렬 함수(단일일 셀 내) — 종일 우선, 그 다음 startAt, 마지막에 createdAt.
    private func eventOrdering(_ lhs: Event, _ rhs: Event) -> Bool {
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
        return lhs.createdAt < rhs.createdAt
    }

    // §5.6 popover용 — 그 날(date 키)에 걸치는 모든 이벤트(단일일 + 멀티데이) 묶어 반환.
    // 정렬은 §4.5 트랙 우선순위: 멀티데이 → 단일일 종일 → 단일일 시간지정 → createdAt 타이.
    // 멀티데이는 걸치는 모든 날짜에 똑같이 등록된다 — 같은 이벤트가 여러 키에 들어감.
    private func allEventsByDay(_ visibleEvents: [Event]) -> [Date: [Event]] {
        var dict: [Date: [Event]] = [:]
        let cal = Calendar.current

        for ev in visibleEvents {
            let startDay = cal.startOfDay(for: ev.startAt)
            // endAt은 배타적이라 1초 빼서 "포함되는 마지막 날"의 startOfDay.
            let endDay = cal.startOfDay(for: ev.endAt.addingTimeInterval(-1))
            var day = startDay
            while day <= endDay {
                dict[day, default: []].append(ev)
                guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
                day = next
            }
        }

        for key in dict.keys {
            dict[key]?.sort(by: popoverOrdering)
        }
        return dict
    }

    // §4.5 — popover 내 이벤트 정렬: 멀티데이 → 단일일 종일 → 단일일 시간지정 → createdAt 타이.
    private func popoverOrdering(_ lhs: Event, _ rhs: Event) -> Bool {
        let lhsMulti = MultiDayLayout.isMultiDay(lhs)
        let rhsMulti = MultiDayLayout.isMultiDay(rhs)
        if lhsMulti != rhsMulti { return lhsMulti }
        if lhs.isAllDay != rhs.isAllDay { return lhs.isAllDay }
        if lhs.startAt != rhs.startAt { return lhs.startAt < rhs.startAt }
        return lhs.createdAt < rhs.createdAt
    }

    // 주어진 연/월에 대해 화면에 띄울 42개 날짜 셀을 만들어 돌려준다.
    // 흐름: (1) 이번 달 1일의 요일을 알아내서 그 앞을 지난 달로 채우고, (2) 이번 달 1~말일을 채우고,
    //       (3) 42칸이 될 때까지 다음 달 1일부터 이어 붙인다.
    private func buildMonthGrid(year: Int, month: Int) -> [DayCellModel] {
        // 그레고리력 + 한국식 시작 요일(일=1) 사용.
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        cal.timeZone = .current

        // 이번 달 1일 Date를 만든다. month는 0~11 저장이라 +1로 보정.
        // guard let: 만들기 실패하면(이론상 거의 없지만) 빈 배열로 조용히 종료.
        guard let first = cal.date(from: DateComponents(year: year, month: month + 1, day: 1)) else {
            return []
        }

        // weekday는 1~7(일~토). 0~6 인덱스로 쓰려고 -1 보정.
        let firstDow = cal.component(.weekday, from: first) - 1
        // 이번 달의 마지막 날 숫자(28~31). nil이면 0으로 폴백.
        let dim = cal.range(of: .day, in: .month, for: first)?.count ?? 0

        // 이번 달이 5주 안에 들어가는지(35칸) 6주가 필요한지(42칸) 판단.
        // 1일 요일(앞쪽 빈 칸 수) + 일수가 35 이하면 5주로 충분. 그 외엔 6주가 필요하다.
        let target = (firstDow + dim) <= 35 ? 35 : 42

        var cells: [DayCellModel] = []

        // (1) 1일이 일요일이 아니면(firstDow > 0), 그 앞을 지난 달의 끝쪽 날짜로 채운다.
        if firstDow > 0,
           let prev = cal.date(byAdding: .month, value: -1, to: first),
           let prevRange = cal.range(of: .day, in: .month, for: prev) {
            let prevDim = prevRange.count
            // stride(from: firstDow-1, through: 0, by: -1) — 큰 인덱스부터 0까지 거꾸로 순회.
            // 그래야 화면상 왼쪽부터 "지난달 27, 28, 29, 30" 순으로 자연스럽게 들어간다.
            for i in stride(from: firstDow - 1, through: 0, by: -1) {
                var comps = cal.dateComponents([.year, .month], from: prev)
                comps.day = prevDim - i
                if let d = cal.date(from: comps) {
                    cells.append(DayCellModel(
                        date: d,
                        inMonth: false, // 이번 달이 아니므로 흐리게 표시될 셀.
                        dow: cal.component(.weekday, from: d) - 1
                    ))
                }
            }
        }

        // (2) 이번 달 1일부터 말일까지 차례로 추가. max(dim, 1)은 dim이 0인 극단적 폴백 안전장치.
        for day in 1...max(dim, 1) {
            var comps = cal.dateComponents([.year, .month], from: first)
            comps.day = day
            if let d = cal.date(from: comps) {
                cells.append(DayCellModel(
                    date: d,
                    inMonth: true,
                    dow: cal.component(.weekday, from: d) - 1
                ))
            }
        }

        // (3) target(35 또는 42)이 될 때까지 다음 달 1, 2, 3 … 순으로 채워서 그리드를 완성.
        if let nextMonth = cal.date(byAdding: .month, value: 1, to: first) {
            var trailingDay = 1
            while cells.count < target {
                var comps = cal.dateComponents([.year, .month], from: nextMonth)
                comps.day = trailingDay
                if let d = cal.date(from: comps) {
                    cells.append(DayCellModel(
                        date: d,
                        inMonth: false,
                        dow: cal.component(.weekday, from: d) - 1
                    ))
                }
                trailingDay += 1
            }
        }

        return cells
    }
}
