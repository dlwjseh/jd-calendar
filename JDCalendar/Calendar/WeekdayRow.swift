import SwiftUI

// 헤더 바로 아래에 표시되는 요일 행 — 일/월/화/수/목/금/토.
// 일요일은 빨강, 토요일은 파랑, 평일은 흐린 회색으로 칠한다.
struct WeekdayRow: View {
    // 일요일을 첫 칼럼으로 쓰는 한국식 배치.
    private let labels = ["일", "월", "화", "수", "목", "금", "토"]
    private let theme = CalendarTheme.light

    var body: some View {
        // spacing: 0 — 7개 셀이 빈틈 없이 붙어 있어야 아래 그리드와 컬럼이 정확히 정렬된다.
        HStack(spacing: 0) {
            // labels.indices를 돌리는 이유: 인덱스(0=일, 6=토)에 따라 색을 다르게 줘야 하기 때문.
            ForEach(labels.indices, id: \.self) { i in
                Text(labels[i])
                    .font(.system(size: 11, weight: .medium))
                    .tracking(0.5)
                    .foregroundStyle(color(for: i))
                    // maxWidth: .infinity — 7개 셀이 가로 공간을 균등하게 1/7씩 차지하게 만든다.
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
        }
        // 행 아래쪽에 1px 가로 구분선 — 헤더와 그리드를 시각적으로 분리.
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.line)
                .frame(height: 1)
        }
    }

    // 인덱스에 따라 일요일=sun, 토요일=sat, 그 외=평일색을 돌려준다.
    private func color(for index: Int) -> Color {
        switch index {
        case 0: return theme.sun
        case 6: return theme.sat
        default: return theme.headerInk
        }
    }
}
