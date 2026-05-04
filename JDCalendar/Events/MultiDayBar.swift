import SwiftUI
import SwiftData
import AppKit

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
    // 시스템 관리 카테고리(공휴일 등)의 이벤트는 잠금 — 편집/삭제/드래그 모두 차단.
    private var isLocked: Bool { event.category.isSystemManaged }

    var body: some View {
        if isLocked {
            // 공휴일 등 잠긴 이벤트 — 단일 클릭 선택만 허용.
            barShape
                .contentShape(Rectangle())
                .onHover { hovering in
                    if hovering { NSCursor.arrow.push() } else { NSCursor.pop() }
                }
                .onTapGesture(count: 1) {
                    selectedEventId = event.id
                }
        } else {
            // 사용자 이벤트 — 기존 인터랙션 그대로.
            barShape
                .contentShape(Rectangle())
                // §6.1 — 드래그로 날짜 이동. 막대의 어느 위치를 잡아도 startAt 기준으로 평행 이동.
                // payload는 event.id 문자열, drop 처리는 DayCell이.
                .draggable(event.id.uuidString)
                // 막대 위 hover 시 마우스 커서를 기본 화살표로 고정 (사용자 요청).
                .onHover { hovering in
                    if hovering { NSCursor.arrow.push() } else { NSCursor.pop() }
                }
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

    // 카테고리 색 박스 + 제목 + 선택 외곽 링까지 합친 공통 시각 부분.
    // 잠금 분기와 무관하게 공유되므로 별도 프로퍼티로 추출.
    private var barShape: some View {
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
    }
}
