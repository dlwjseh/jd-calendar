import SwiftUI
import SwiftData

// 사이드바의 카테고리 한 줄 — [색상 점(체크박스)] + [이름] + 우클릭 메뉴(편집 / 삭제).
// CATEGORY_FEATURE.md 5.3 / 7 / 8.x.
struct CategoryRow: View {
    let category: EventCategory
    // 마지막 1개 카테고리는 삭제 불가(8.1) — 부모(CategorySidebar)가 판단해 전달.
    let isLastCategory: Bool

    @Environment(\.modelContext) private var modelContext

    // 우클릭 메뉴에서 시트/얼럿을 띄우기 위한 자체 상태.
    @State private var showingEditor = false
    @State private var showingDeleteAlert = false
    // 마우스가 행 위에 올라왔는지 — true면 행 배경이 살짝 강조된다.
    @State private var hovered = false

    private let theme = CalendarTheme.light

    var body: some View {
        HStack(spacing: 0) {
            colorDotCheckbox

            // 이름 — 한 줄 제한, 길면 줄임표. 필터 꺼진 상태에선 흐리게.
            Text(category.name)
                .font(.system(size: 13))
                .foregroundStyle(theme.fg.opacity(category.isVisible ? 1.0 : 0.45))
                .lineLimit(1)

            // Spacer로 행이 사이드바 폭만큼 늘어나도록 — 우클릭/콘텍스트 영역을 행 전체로 키운다.
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        // 호버 강조 — 다른 버튼들과 같은 theme.line 톤으로 행 배경에 둥근 직사각형을 깐다.
        // 좌·우 4pt 인셋으로 사이드바 가장자리에 딱 붙지 않게 — Finder/Mail의 사이드바 행 강조 톤.
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(hovered ? theme.line : .clear)
                .padding(.horizontal, 4)
        }
        // contentShape: 빈 영역(Spacer)도 우클릭/호버 대상이 되도록 행 전체에 히트 영역을 깐다.
        .contentShape(Rectangle())
        // 호버 진입/이탈에 따라 hovered 토글 — 아래 .background가 자동으로 다시 그려진다.
        .onHover { hovered = $0 }
        // 호버 강조 톤 페이드 — 갑자기 켜고 꺼지는 대신 살짝의 보간.
        .animation(.easeInOut(duration: 0.12), value: hovered)
        // 우클릭(혹은 Control+클릭) 시 컨텍스트 메뉴 — 5.3.
        // 시스템 관리 카테고리(예: 공휴일)는 편집/삭제 모두 막혀 있으므로 메뉴 자체를 띄우지 않는다.
        // (@ViewBuilder 가 빈 결과를 반환하면 SwiftUI 가 컨텍스트 메뉴를 등록하지 않음.)
        .contextMenu {
            if !category.isSystemManaged {
                Button("편집") {
                    showingEditor = true
                }
                // 8.1: 마지막 1개 카테고리는 삭제 불가 — 메뉴 항목 자체를 비활성.
                Button("삭제", role: .destructive) {
                    showingDeleteAlert = true
                }
                .disabled(isLastCategory)
            }
        }
        // 편집 시트 — CategoryEditor에 기존 카테고리를 넘겨 편집 모드로 띄움.
        .sheet(isPresented: $showingEditor) {
            CategoryEditor(editing: category)
        }
        // 삭제 확인 다이얼로그 — 8.2 / 8.3.
        // 기본 버튼은 "취소"(안전 우선) — `.defaultAction` 단축키로 Enter도 취소가 동작하게.
        // "삭제"는 .destructive 역할 → macOS에서 빨간 텍스트로 강조됨.
        .alert(deleteTitle, isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
                .keyboardShortcut(.defaultAction)
            Button("삭제", role: .destructive) {
                delete()
            }
        } message: {
            Text(deleteMessage)
        }
    }

    // 5.3: 색상 점이 체크박스 역할.
    // 체크(보이기): 카테고리 색으로 꽉 찬 원.
    // 해제(숨기기): 같은 색의 외곽 링만 — 색은 유지해서 어떤 카테고리인지 식별은 가능.
    // 클릭 영역은 시각적 14pt 원 주변에 padding 7pt를 더해 28pt 정사각형 — 작은 점도 클릭하기 쉽도록.
    private var colorDotCheckbox: some View {
        Group {
            if category.isVisible {
                Circle()
                    .fill(Color(hex: category.color))
            } else {
                Circle()
                    .strokeBorder(Color(hex: category.color), lineWidth: 1.5)
            }
        }
        .frame(width: 14, height: 14)
        // padding 7 → 28x28 히트 영역. HStack spacing 0 + 이 padding의 우측 7 = 텍스트와의 시각적 간격 7pt.
        .padding(7)
        .contentShape(Rectangle())
        .onTapGesture {
            // SwiftData @Model의 프로퍼티를 바꾸면 자동으로 변경 추적·저장됨.
            category.isVisible.toggle()
            try? modelContext.save()
        }
        // 호버 시 어떤 동작이 일어나는지 알려주는 툴팁.
        .help(category.isVisible ? "이 카테고리 숨기기" : "이 카테고리 보이기")
        // 토글 시 점·외곽 링이 부드럽게 전환되도록 살짝의 애니메이션.
        .animation(.easeInOut(duration: 0.15), value: category.isVisible)
    }

    // 8.2: 제목은 항상 ""<이름>"을 삭제할까요?".
    private var deleteTitle: String {
        "\"\(category.name)\"을 삭제할까요?"
    }

    // 8.2: 본문은 카테고리에 속한 이벤트 수에 따라 분기.
    // v1 카테고리 단계에서는 이벤트 모델이 아직 없으므로 항상 0개로 간주 → "되돌릴 수 없습니다."만 표시.
    // 이벤트 기능 도입 시 N>0 분기를 활성화한다(EVENT_FEATURE.md 작업).
    private var deleteMessage: String {
        "이 동작은 되돌릴 수 없습니다."
    }

    // 카테고리 삭제 — SwiftData에서 제거하고 즉시 디스크에 반영.
    // 8번 정책상 cascade 삭제(이벤트 함께 제거)는 모델의 @Relationship에서 자동 처리될 예정.
    private func delete() {
        modelContext.delete(category)
        try? modelContext.save()
    }
}
