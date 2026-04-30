import SwiftUI

// @main: 이 구조체가 앱의 진입점(entry point)임을 컴파일러에게 알려주는 마커.
// SwiftUI 앱은 main 함수를 직접 쓰지 않고, App 프로토콜을 따르는 구조체에 @main을 붙여서 시작한다.
@main
struct JDCalendarApp: App {
    // App 프로토콜이 요구하는 단 하나의 멤버 — 어떤 Scene(창)들로 앱을 구성할지 선언한다.
    var body: some Scene {
        // WindowGroup: macOS에서 같은 콘텐츠를 가진 창을 여러 개 띄울 수 있게 해주는 컨테이너.
        // 첫 번째 인자 "JD Calendar"는 창 타이틀이지만 아래에서 hiddenTitleBar로 가리고 있다.
        WindowGroup("JD Calendar") {
            ContentView()
                // 사용자가 창을 너무 작게 줄이지 못하도록 최소 크기 지정.
                // minHeight는 콘텐츠 최소치(헤더 64 + 요일행 32 + 6주×96 = 672)보다 살짝 커야 한다.
                // 그렇지 않으면 SwiftUI가 부족한 높이를 메우려고 헤더를 통째로 깎아낸다.
                .frame(minWidth: 720, minHeight: 680)
        }
        // 앱을 처음 실행했을 때 열리는 창의 기본 크기.
        .defaultSize(width: 1100, height: 720)
        // contentMinSize: 위에서 지정한 minWidth/minHeight를 창 리사이즈 한계로 사용.
        .windowResizability(.contentMinSize)
        // hiddenTitleBar: 타이틀바 막대를 숨김 — 신호등 3개는 콘텐츠 위에 그대로 떠 있음.
        .windowStyle(.hiddenTitleBar)
    }
}
