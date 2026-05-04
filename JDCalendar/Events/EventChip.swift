import SwiftUI
import SwiftData

// 셀 안에 한 이벤트를 표시하는 작은 컴포넌트.
// EVENT_FEATURE.md §4.1 — 종일/시간지정에 따라 두 가지 모양.
//
// 종일: 카테고리 색으로 채운 가로 박스 + 흰색 또는 검정 자동 텍스트.
// 시간지정: 좌측 얇은 색 바 + "HH:mm 제목" 한 줄(텍스트 색은 페이지 기본).
//
// §5.1 인터랙션:
// - 단일 클릭 → 선택 상태(외곽 링)
// - 더블 클릭 → 편집 시트
// - 우클릭 → 컨텍스트 메뉴(편집/삭제)
// 선택 상태는 부모(ContentView)의 selectedEventId binding으로 끌어올림 — 한 번에 한 항목만(§5.1).
struct EventChip: View {
    let event: Event
    @Binding var selectedEventId: UUID?

    @Environment(\.modelContext) private var modelContext

    @State private var showingEditor = false
    @State private var showingDeleteAlert = false

    private let theme = CalendarTheme.light

    // HH:mm 형식 시각 — 매 렌더 시 DateFormatter를 새로 만들지 않도록 static으로.
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var isSelected: Bool { selectedEventId == event.id }

    var body: some View {
        Group {
            if event.isAllDay {
                allDayBox
            } else {
                timedRow
            }
        }
        // §5.1 선택 강조 — 두 모드 공통으로 외곽 링.
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(theme.fg, lineWidth: 1.5)
            }
        }
        // 빈 영역까지 클릭 가능하도록 chip 전체에 히트 영역.
        .contentShape(Rectangle())
        // 더블 클릭 = 편집 시트(§5.1). count: 2를 먼저 등록해야 single과 충돌 시 우선.
        .onTapGesture(count: 2) {
            selectedEventId = event.id
            showingEditor = true
        }
        // 단일 클릭 = 선택. SwiftUI는 single/double 둘 다 등록 시 약 200ms delay 후 single 발화.
        .onTapGesture(count: 1) {
            selectedEventId = event.id
        }
        // §5.5 우클릭 컨텍스트 메뉴 — 편집 / 삭제.
        .contextMenu {
            Button("편집") {
                selectedEventId = event.id
                showingEditor = true
            }
            Button("삭제", role: .destructive) {
                selectedEventId = event.id
                showingDeleteAlert = true
            }
        }
        // §5.2 편집 시트 — 같은 EventEditor를 editing 인자에 자기 이벤트 넣어 재사용.
        .sheet(isPresented: $showingEditor) {
            EventEditor(editing: event, initialDate: event.startAt)
        }
        // §5.4 삭제 확인 다이얼로그 — 본문 없음, 기본 버튼은 취소.
        .alert(deleteTitle, isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
                .keyboardShortcut(.defaultAction)
            Button("삭제", role: .destructive) {
                delete()
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
        // 16pt 정도 — 종일 박스와 비슷한 행 높이. fixedSize로 vertical만 콘텐츠에 맞춤.
        .frame(height: 16)
    }

    // §5.4 — 제목은 항상 "<제목>"을 삭제할까요?
    private var deleteTitle: String {
        "\"\(event.title)\"을 삭제할까요?"
    }

    // 삭제 — 선택 해제하고 modelContext에서 제거.
    private func delete() {
        if selectedEventId == event.id { selectedEventId = nil }
        modelContext.delete(event)
        try? modelContext.save()
    }
}
