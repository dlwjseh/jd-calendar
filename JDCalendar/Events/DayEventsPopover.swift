import SwiftUI
import AppKit

// 셀 클릭 시 화면 위에 떠있는 modal 카드 — 그 날의 이벤트 목록 + 새 이벤트 추가 버튼.
//
// 구조 (디자인 기준):
//   상단 row: 좌측 "M월 d일 (요일) 음 lunarMonth.lunarDay"  +  우측 파란 + 버튼
//             (이 row는 카드 밖, 위에 떠있음)
//   카드:    둥근 흰 사각형 + 그림자, 안에 이벤트 행 리스트
//
// 행 hover → 옅은 배경 강조
// 행 클릭 → onEdit 콜백 (부모가 편집 시트)
// + 버튼 클릭 → onAddNew 콜백 (부모가 새 이벤트 시트)
struct DayEventsPopover: View {
    let date: Date
    let events: [Event]                   // 정렬 완료 — 잠긴 이벤트(공휴일)도 포함.
    let onAddNew: () -> Void
    let onEdit: (Event) -> Void

    private let theme = CalendarTheme.light

    // 카드 폭 — 디자인의 floating 카드. 이벤트 목록 영역을 조금 더 넓게.
    private static let cardWidth: CGFloat = 370
    // 헤더 좌우 인셋 — "월일" 텍스트와 + 버튼이 흰 카드 가장자리보다 안쪽에 놓이게.
    private static let headerInset: CGFloat = 14

    // "4월 20일 (월)" 형식. static으로 매 렌더 재생성 방지.
    private static let solarFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일 (EEE)"
        return f
    }()

    var body: some View {
        // 헤더 row와 카드를 세로로 쌓고, 둘을 각각 .leading 정렬.
        VStack(alignment: .leading, spacing: 14) {
            header
            card
        }
        // 외곽 폭을 카드 폭에 맞춰서, 헤더의 좌우 인셋이 그대로 흰 카드 안쪽으로 들어가게.
        .frame(width: Self.cardWidth, alignment: .leading)
    }

    // 헤더 — 좌측 양력+음력 텍스트, 우측 + 버튼.
    // 어두운 캘린더 배경 위에 떠 있으므로 흰 글씨 + 그림자로 가독성 확보.
    private var header: some View {
        HStack(alignment: .center, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Self.solarFormatter.string(from: date))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text(lunarString)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.85))
            }
            // 두 텍스트를 한 번에 감싸는 그림자 — 어두운 배경에서 또렷하게.
            .shadow(color: .black.opacity(0.55), radius: 3, x: 0, y: 1)
            Spacer(minLength: 8)
            // + 버튼 — 새 이벤트 추가. 파란 원형.
            Button(action: onAddNew) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: "#3a7bd5")))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
            }
        }
        // 좌우를 흰 카드 가장자리보다 한 단계 안쪽으로 들이기.
        .padding(.horizontal, Self.headerInset)
    }

    // 흰색 둥근 카드 — 안에 이벤트 행 리스트(또는 비어있다는 안내).
    private var card: some View {
        VStack(alignment: .leading, spacing: 2) {
            if events.isEmpty {
                Text("이 날에는 이벤트가 없습니다")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                ForEach(events, id: \.id) { ev in
                    EventRow(event: ev, onTap: { onEdit(ev) })
                }
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .frame(width: Self.cardWidth, alignment: .leading)
        .background(
            // theme.bg가 light에서 흰색 — 그림자와 함께 카드처럼 보이게.
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.bg)
                .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 4)
        )
    }

    // 양력 → 음력 변환. Foundation의 .chinese 캘린더는 한국 음력과 month/day 값이 동일.
    // (KASI 대비 절기 정보는 다르지만 월·일 표기에는 차이 없음.)
    private var lunarString: String {
        let cal = Calendar(identifier: .chinese)
        let comps = cal.dateComponents([.month, .day], from: date)
        let month = comps.month.map(String.init) ?? "?"
        let day = comps.day.map(String.init) ?? "?"
        return "음 \(month).\(day)"
    }
}

// 이벤트 한 행 — 좌측 색점, 가운데 제목, 우측 시간/날짜 텍스트.
// hover 강조 + 클릭(편집).
private struct EventRow: View {
    let event: Event
    let onTap: () -> Void

    @State private var isHovered = false
    private let theme = CalendarTheme.light

    // "9:00" 형식 — 24시간, 분은 두 자리 고정.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "H:mm"
        return f
    }()

    // "4월 20일" 형식 — 멀티데이 우측 표기용.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ko_KR")
        f.dateFormat = "M월 d일"
        return f
    }()

    var body: some View {
        HStack(spacing: 10) {
            // 카테고리 색 점.
            Circle()
                .fill(Color(hex: event.category.color))
                .frame(width: 8, height: 8)
            // 제목 — 길면 ellipsis.
            Text(event.title)
                .font(.system(size: 13))
                .foregroundStyle(theme.fg)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 6)
            // 우측 시간/날짜 — 회색.
            Text(rightText)
                .font(.system(size: 11))
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        // hover 시 옅은 배경.
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? theme.hover : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
            if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
        }
        .onTapGesture(perform: onTap)
    }

    // 우측 텍스트 결정:
    //  - 멀티데이 → "M월 d일-M월 d일"
    //  - 종일 → "종일"
    //  - 시간지정 → "H:mm-H:mm"
    private var rightText: String {
        if MultiDayLayout.isMultiDay(event) {
            let s = Self.dateFormatter.string(from: event.startAt)
            // endAt은 배타적 — 1초 빼서 "포함되는 마지막 날"을 표시.
            let e = Self.dateFormatter.string(from: event.endAt.addingTimeInterval(-1))
            return "\(s)-\(e)"
        }
        if event.isAllDay {
            return "종일"
        }
        let s = Self.timeFormatter.string(from: event.startAt)
        let e = Self.timeFormatter.string(from: event.endAt)
        return "\(s)-\(e)"
    }
}
