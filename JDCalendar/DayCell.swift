import SwiftUI

// 한 칸(하루)을 그리는 데 필요한 최소 정보.
// Hashable을 채택한 이유: SwiftUI의 ForEach/diff 비교에 쓰기 좋게 하기 위함.
struct DayCellModel: Hashable {
    let date: Date    // 이 셀이 가리키는 실제 날짜.
    let inMonth: Bool // 이번 달이면 true, 지난/다음 달의 채움용 셀이면 false.
    let dow: Int      // 요일 인덱스 0=일 ~ 6=토. 색을 결정할 때 사용.
}

// 달력 그리드의 셀 하나.
// 왼쪽 위에 날짜 숫자만 작게 표시하고, 일정 영역(아래 빈 공간)은 v1에서는 비워둔다.
struct DayCell: View {
    let cell: DayCellModel
    let today: Date
    // 격자선을 마지막 행/칼럼에는 그리지 않기 위해 부모(CalendarGrid)가 알려주는 플래그.
    let isLastRow: Bool
    let isLastCol: Bool

    private let theme = CalendarTheme.light

    // 이 셀이 "오늘"인지 — 같은 날짜면 빨간 캡슐로 강조.
    // computed property라서 매 렌더링마다 다시 계산되지만, 단순 비교라 비용 무시 가능.
    private var isToday: Bool {
        Calendar.current.isDate(cell.date, inSameDayAs: today)
    }

    // Date에서 일(day) 숫자(1~31)만 뽑는다.
    private var dayNumber: Int {
        Calendar.current.component(.day, from: cell.date)
    }

    // 날짜 글자 색을 상황에 맞게 결정.
    // 우선순위: 이번 달이 아님(흐림) → 일요일(빨강) → 토요일(파랑) → 평일(검정).
    private var dayColor: Color {
        if !cell.inMonth { return theme.muted }
        if cell.dow == 0 { return theme.sun }
        if cell.dow == 6 { return theme.sat }
        return theme.fg
    }

    var body: some View {
        // VStack + Spacer — 날짜 숫자를 좌상단에 두고 나머지 공간은 비워서 일정용 영역으로 남긴다.
        VStack(alignment: .leading, spacing: 0) {
            label
            Spacer(minLength: 0)
        }
        // 셀이 그리드의 한 칸 전체를 채우게 늘리고, 글자는 좌상단 정렬.
        // maxHeight: .infinity로 설정해서 부모(VStack of HStacks)가 가용 높이를 균등 분배할 때 같이 커진다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 창이 너무 작아져도 셀이 96pt 아래로 줄지 않도록 안전장치 — 6주짜리 달의 최소 가독성 보장.
        .frame(minHeight: 96)
        // 안쪽 여백 — 위/좌/우/하를 따로 잡아서 디자인 원본과 동일한 간격으로 맞춤.
        .padding(.top, 5)
        .padding(.leading, 6)
        .padding(.trailing, 6)
        .padding(.bottom, 4)
        // 이번 달이 아닌 셀은 전체적으로 살짝 투명하게 — 흐리게 표시 효과.
        .opacity(cell.inMonth ? 1 : 0.55)
        // 오른쪽 세로 1px 격자선 — 단, 마지막 칼럼(토요일)에는 그리지 않아 바깥선 두꺼워짐 방지.
        .overlay(alignment: .trailing) {
            if !isLastCol {
                Rectangle().fill(theme.line).frame(width: 1)
            }
        }
        // 아래쪽 가로 1px 격자선 — 마지막 행에는 그리지 않음.
        .overlay(alignment: .bottom) {
            if !isLastRow {
                Rectangle().fill(theme.line).frame(height: 1)
            }
        }
    }

    // 날짜 숫자 라벨. 오늘이면 빨간 캡슐 + 흰 글자, 아니면 평범한 글자만.
    // @ViewBuilder: if/else로 서로 다른 View를 한 프로퍼티에서 반환할 수 있게 해주는 어트리뷰트.
    @ViewBuilder
    private var label: some View {
        if isToday {
            Text("\(dayNumber)")
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.2)
                .foregroundStyle(theme.todayInk)
                .padding(.horizontal, 6)
                // 한 자리/두 자리 숫자 모두 캡슐 모양이 균일해 보이게 최소 폭/높이 지정.
                .frame(minWidth: 20, minHeight: 20)
                // Capsule: 양 끝이 반원인 둥근 사각형 — 오늘 표시 모양.
                .background(Capsule().fill(theme.today))
        } else {
            Text("\(dayNumber)")
                .font(.system(size: 11, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(dayColor)
                .padding(.horizontal, 2)
        }
    }
}
