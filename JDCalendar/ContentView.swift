import SwiftUI

// 앱의 최상위 화면 — 헤더 + 요일행 + 6주 그리드를 세로로 쌓아서 보여준다.
// 현재 어느 달을 보고 있는지(year, month)를 상태로 들고 있다가 헤더의 ‹/›/Today 버튼으로 갱신한다.
struct ContentView: View {
    // @State: SwiftUI가 값의 변화를 감지해서 화면을 다시 그리도록 만드는 속성 래퍼.
    // year/month는 사용자가 ‹/›를 누를 때마다 바뀌므로 @State로 선언한다.
    @State private var year: Int
    // month는 0~11 (1월=0, 12월=11) 형태로 저장. 표시할 때만 +1 한다.
    @State private var month: Int

    private let theme = CalendarTheme.light

    // init: 앱이 시작되면 무조건 "오늘이 속한 달"로 초기화한다.
    // CLAUDE.md의 v1 규칙: cursor persistence 없음 — 항상 오늘 달로 연다.
    init() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        // _year / _month: @State 프로퍼티의 내부 저장소에 직접 접근하는 문법.
        // init 안에서 @State 초기화는 이 underscore 형태로만 가능하다.
        _year = State(initialValue: cal.component(.year, from: now))
        _month = State(initialValue: cal.component(.month, from: now) - 1)
    }

    var body: some View {
        // 창 전체를 달력이 가득 채우는 단일 레이아웃 — 둥근 모서리/그림자/페이지 배경 없음.
        // 위에서 아래로 헤더 → 요일행 → 6×7 그리드 순으로 쌓는다.
        VStack(spacing: 0) {
            CalendarHeader(
                year: year,
                month: month,
                // 함수 자체를 클로저로 넘김 — 버튼이 눌리면 헤더가 이걸 호출한다.
                onPrev: prev,
                onNext: next,
                onToday: today
            )
            WeekdayRow()
            CalendarGrid(year: year, month: month)
        }
        // 부모(창)가 주는 공간을 끝까지 다 차지하도록 펼친다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .foregroundStyle(theme.fg)
        // 타이틀바를 숨겼으므로 콘텐츠가 창 가장자리(safe area)를 무시하고 끝까지 그려지게 한다.
        .ignoresSafeArea()
    }

    // 이전 달로 이동 — 1월에서 누르면 작년 12월로 넘어간다.
    private func prev() {
        if month == 0 {
            year -= 1
            month = 11
        } else {
            month -= 1
        }
    }

    // 다음 달로 이동 — 12월에서 누르면 내년 1월로 넘어간다.
    private func next() {
        if month == 11 {
            year += 1
            month = 0
        } else {
            month += 1
        }
    }

    // Today 버튼 — 어느 달을 보고 있든 즉시 오늘이 속한 달로 점프한다.
    private func today() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        year = cal.component(.year, from: now)
        month = cal.component(.month, from: now) - 1
    }
}

// #Preview: Xcode 캔버스에서 ContentView를 미리 볼 때 쓰는 매크로. 빌드된 앱에는 포함되지 않는다.
#Preview {
    ContentView()
        .frame(width: 1100, height: 720)
}
