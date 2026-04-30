import SwiftUI

// 사이드바 펼침/접힘을 토글하는 아이콘 버튼.
// CATEGORY_FEATURE.md 5.2: SF Symbol "sidebar.leading", 윈도우 좌상단 띠에 위치.
struct SidebarToggleButton: View {
    // 부모(ContentView)가 가진 사이드바 상태를 양방향으로 묶어 — 누르면 그 값을 직접 토글.
    @Binding var isVisible: Bool

    // 마우스가 위에 올라왔는지 추적해 호버 강조에 사용.
    @State private var hovered = false

    private let theme = CalendarTheme.light

    var body: some View {
        Button {
            isVisible.toggle()
        } label: {
            // SF Symbol "sidebar.leading" — macOS 사이드바 토글 표준 아이콘.
            // 크림 배경에 묻히지 않도록 16pt + medium + 거의 진한 검정으로.
            Image(systemName: "sidebar.leading")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(theme.fg.opacity(hovered ? 1.0 : 0.85))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovered ? theme.line : .clear)
                )
        }
        // .plain: macOS 기본 파란색 버튼 스타일을 끄고 우리가 그린 모양만 사용.
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        // 호버 툴팁 — 현재 상태에 따라 동작 안내가 뒤집히도록.
        .help(isVisible ? "사이드바 숨기기" : "사이드바 보이기")
    }
}
