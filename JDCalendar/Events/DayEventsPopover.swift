import SwiftUI

// `+M more` 클릭 시 뜨는 popover — 그 날의 모든 이벤트를 chip 리스트로 보여준다.
// EVENT_FEATURE.md §5.6 — 단일일 + 그 날에 걸치는 멀티데이 모두 포함, §4.5 정렬.
//
// 닫기/한 번에 한 개 표시는 SwiftUI .popover의 native 동작에 의존(외부 클릭 / Esc).
struct DayEventsPopover: View {
    let date: Date
    let events: [Event]                    // 부모(CalendarGrid)에서 §4.5 순으로 정렬해 넘김
    @Binding var selectedEventId: UUID?

    private let theme = CalendarTheme.light

    // "5월 12일 (월)" 같은 한글 헤더용. static으로 매 렌더 재생성 방지.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (EEE)"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(Self.dateFormatter.string(from: date))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.fg)
                .padding(.bottom, 2)

            // EventChip을 그대로 재사용 — 종일/시간지정 모양 분기를 chip이 알아서.
            // 멀티데이도 chip 형태로 표시(§5.6) — 시간지정 멀티데이의 HH:mm는 startAt 기준.
            ForEach(events, id: \.id) { ev in
                EventChip(event: ev, selectedEventId: $selectedEventId)
            }
        }
        .padding(12)
        .frame(width: 220)
        .background(theme.bg)
    }
}
