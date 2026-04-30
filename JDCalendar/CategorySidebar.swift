import SwiftUI
import SwiftData

// 좌측 사이드바 — 헤더("카테고리" 라벨 + "+" 버튼) + 카테고리 목록.
// CATEGORY_FEATURE.md 5.2~5.4 합의 사항을 그대로 구현.
struct CategorySidebar: View {
    // 5.2: 너비 220pt 고정. 부모가 이 뷰를 그릴지 말지(펼침/접힘)를 결정한다.
    static let width: CGFloat = 220

    // SwiftData가 카테고리를 createdAt 오름차순으로 자동 갱신해서 흘려준다.
    // @Query는 ModelContainer의 변경을 관찰해 뷰를 자동 재렌더한다.
    @Query(sort: \EventCategory.createdAt) private var categories: [EventCategory]

    private let theme = CalendarTheme.light

    var body: some View {
        VStack(spacing: 0) {
            header
            list
        }
        .frame(width: Self.width)
        // 본문보다 살짝 진한 베이지로 좌·우 구분 — Divider 없이 색만으로 분리.
        .background(theme.sidebarBg)
    }

    // 5.4: 좌측에 "카테고리" 라벨, 우측에 "+" 추가 버튼.
    private var header: some View {
        HStack {
            Text("카테고리")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.fg.opacity(0.85))
            Spacer()
            AddCategoryButton()
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
    }

    // 카테고리 행 목록. 행이 많아질 때를 대비해 스크롤뷰 + LazyVStack으로 감싼다.
    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // SwiftData @Model에 우리가 정의한 id: UUID를 명시적으로 지정해 ForEach 식별 키로 사용.
                ForEach(categories, id: \.id) { cat in
                    // isLastCategory: 8.1 정책상 마지막 1개는 삭제 불가 — 메뉴 비활성용 신호.
                    CategoryRow(category: cat, isLastCategory: categories.count == 1)
                }
            }
        }
    }
}

// "+" 버튼 — 누르면 카테고리 생성 다이얼로그(`CategoryEditor`)가 시트로 뜬다.
// CategorySidebar 내부에서만 쓰이는 작은 컴포넌트라 같은 파일의 private struct로.
private struct AddCategoryButton: View {
    // 시트 표시 여부 — Button과 .sheet가 같은 뷰에 있으면 토글이 자연스럽다.
    @State private var showingEditor = false
    @State private var hovered = false

    private let theme = CalendarTheme.light

    var body: some View {
        Button {
            showingEditor = true
        } label: {
            // CATEGORY_FEATURE.md Q-3 결정: SF Symbol "plus" 단독.
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.fg.opacity(hovered ? 1.0 : 0.55))
                .frame(width: 22, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(hovered ? theme.line : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("새 카테고리")
        // .sheet: 부모 윈도우 위에 모달로 뜨는 시트. macOS에서는 윈도우 중앙에 배치된다.
        .sheet(isPresented: $showingEditor) {
            CategoryEditor()
        }
    }
}
