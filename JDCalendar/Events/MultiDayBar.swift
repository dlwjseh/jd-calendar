import SwiftUI
import SwiftData

// 멀티데이 이벤트의 한 segment(주 한 줄)를 그리는 가로 막대.
// EVENT_FEATURE.md §4.3 — 종일/시간지정 둘 다 같은 모양: 카테고리 색 박스 + 좌측 정렬 제목.
// 같은 이벤트가 여러 주에 걸치면 주마다 별도 segment가 만들어지고, 각 segment의 시작 셀에 제목이 표시된다.
//
// 인터랙션은 EventChip과 동일 — 단일 클릭(선택) / 더블 클릭(편집) / 우클릭(편집·삭제).
struct MultiDayBar: View {
    let segment: MultiDaySegment
    @Binding var selectedEventId: UUID?

    @Environment(\.modelContext) private var modelContext

    @State private var showingEditor = false
    @State private var showingDeleteAlert = false

    private let theme = CalendarTheme.light

    private var event: Event { segment.event }
    private var isSelected: Bool { selectedEventId == event.id }

    var body: some View {
        // §4.3 — 모든 주 segment의 시작 셀에서 제목을 표시한다(주 경계를 넘으면 다음 주 첫 셀에서도 다시).
        // 제목은 leading 정렬이라 막대가 길어도 항상 좌측에 붙고, 잘리면 ellipsis(…).
        Text(event.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Color.contrastingText(forHex: event.category.color))
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.horizontal, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: event.category.color))
            )
        // 선택 강조 — chip과 같은 외곽 링.
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(theme.fg, lineWidth: 1.5)
            }
        }
        .contentShape(Rectangle())
        // 더블 클릭 = 편집(§5.1).
        .onTapGesture(count: 2) {
            selectedEventId = event.id
            showingEditor = true
        }
        // 단일 클릭 = 선택(§5.1).
        .onTapGesture(count: 1) {
            selectedEventId = event.id
        }
        // 우클릭 컨텍스트 메뉴(§5.5).
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
        // 편집 시트 — EventChip과 동일.
        .sheet(isPresented: $showingEditor) {
            EventEditor(editing: event, initialDate: event.startAt)
        }
        // 삭제 확인 — §5.4 스타일.
        .alert("\"\(event.title)\"을 삭제할까요?", isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
                .keyboardShortcut(.defaultAction)
            Button("삭제", role: .destructive) {
                if selectedEventId == event.id { selectedEventId = nil }
                modelContext.delete(event)
                try? modelContext.save()
            }
        }
    }
}
