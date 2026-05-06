import SwiftUI
import SwiftData
import AppKit

// 셀 안에 한 이벤트를 표시하는 작은 컴포넌트.
// EVENT_FEATURE.md §4.1 — 종일/시간지정에 따라 두 가지 모양.
//
// 종일: 카테고리 색으로 채운 가로 박스 + 흰색 또는 검정 자동 텍스트.
// 시간지정: 좌측 얇은 색 바 + "HH:mm 제목" 한 줄(텍스트 색은 페이지 기본).
//
// 인터랙션: v2 재정립 중 — 표시 + 드래그 + 호버만 남김.
// 잠긴 이벤트(공휴일 등)는 드래그도 막는다.
struct EventChip: View {
    let event: Event

    private let theme = CalendarTheme.light

    // HH:mm 형식 시각 — 매 렌더 시 DateFormatter를 새로 만들지 않도록 static으로.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    // 시스템 관리 카테고리(공휴일 등)의 이벤트는 잠금 — 드래그 차단.
    private var isLocked: Bool { event.category.isSystemManaged }

    var body: some View {
        if isLocked {
            // 잠긴 이벤트 — 드래그 없이 표시 + 호버만.
            chipShape
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.arrow.push() } else { NSCursor.pop() }
                }
        } else {
            // 사용자 이벤트 — 드래그 + 호버.
            chipShape
                .contentShape(Rectangle())
                // 드래그로 날짜 이동. payload는 event.id 문자열, drop 처리는 DayCell이.
                .draggable(event.id.uuidString)
                // chip 위 hover 시 마우스 커서를 기본 화살표로 고정 — Text view 기본 i-beam이나
                // .draggable의 시스템 hand 커서로 바뀌지 않도록(사용자 요청).
                .onHover { hovering in
                    if hovering { NSCursor.arrow.push() } else { NSCursor.pop() }
                }
        }
    }

    // 종일/시간지정 두 모양을 묶은 공통 시각 부분.
    private var chipShape: some View {
        Group {
            if event.isAllDay {
                allDayBox
            } else {
                timedRow
            }
        }
    }

    // 종일 — 카테고리 색 배경 + 자동 대비 텍스트.
    private var allDayBox: some View {
        Text(event.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.contrastingText(forHex: event.category.color))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 5)
            .padding(.vertical, 1)
            // maxWidth로 셀 폭을 거의 채움 — alignment: .leading으로 글자는 좌측 정렬.
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: event.category.color))
            )
    }

    // 시간지정 — 좌측 얇은 색 바 + "HH:mm 제목" 텍스트.
    private var timedRow: some View {
        HStack(spacing: 4) {
            // 얇은 세로 색 바 — 셀 행 높이를 따라 늘어나도록 maxHeight: .infinity.
            RoundedRectangle(cornerRadius: 1)
                .fill(Color(hex: event.category.color))
                .frame(width: 2)
                .frame(maxHeight: .infinity)

            Text("\(Self.timeFormatter.string(from: event.startAt)) \(event.title)")
                .font(.system(size: 11))
                .foregroundStyle(theme.fg)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
        // 16pt 정도 — 종일 박스와 비슷한 행 높이.
        .frame(height: 16)
    }
}
