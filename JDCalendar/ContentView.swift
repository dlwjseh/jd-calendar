import SwiftUI
import SwiftData

// 앱의 최상위 화면 — 헤더 + 요일행 + 6주 그리드를 세로로 쌓아서 보여준다.
// 현재 어느 달을 보고 있는지(year, month)를 상태로 들고 있다가 헤더의 ‹/›/Today 버튼으로 갱신한다.
struct ContentView: View {
    // SwiftData가 흘려준 ModelContext — 시드 / 조회 / 저장 모두 이걸로 한다.
    @Environment(\.modelContext) private var modelContext

    // 사이드바 펼침 상태. @AppStorage는 UserDefaults에 자동 저장 → 다음 실행에 복원된다(5.2).
    // 기본값 true는 첫 실행 시 펼친 상태로 시작한다는 의미(첫 실행 후엔 사용자 마지막 값을 따름).
    @AppStorage("sidebarVisible") private var sidebarVisible: Bool = true

    // @State: SwiftUI가 값의 변화를 감지해서 화면을 다시 그리도록 만드는 속성 래퍼.
    // year/month는 사용자가 ‹/›를 누를 때마다 바뀌므로 @State로 선언한다.
    @State private var year: Int
    // month는 0~11 (1월=0, 12월=11) 형태로 저장. 표시할 때만 +1 한다.
    @State private var month: Int

    // §5.1 — 한 번에 한 이벤트만 선택. CalendarGrid → DayCell → EventChip으로 binding을 흘려보낸다.
    @State private var selectedEventId: UUID? = nil

    // §5.4 — Delete 키로 삭제 시 띄울 확인 alert의 대상.
    // chip 자체의 우클릭 삭제는 chip 안에서 처리하지만, 글로벌 키 핸들러(Delete)는 여기서.
    @State private var pendingDeleteEvent: Event? = nil

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
        // 새로운 레이아웃(슬라이스 2) — 위에서 아래로:
        //   1) 상단 띠: 사이드바 토글 버튼(좌상단 고정)
        //   2) 본체: 좌(사이드바, 펼침일 때) | 우(달력 헤더+요일행+그리드)
        VStack(spacing: 0) {
            topStrip
            mainSplit
        }
        // 부모(창)가 주는 공간을 끝까지 다 차지하도록 펼친다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .foregroundStyle(theme.fg)
        // 타이틀바를 숨겼으므로 콘텐츠가 창 가장자리(safe area)를 무시하고 끝까지 그려지게 한다.
        .ignoresSafeArea()
        // §5.1 글로벌 background tap — 셀/chip/버튼 등 자식이 잡지 않은 빈 영역 클릭 시 선택 해제.
        // DayCell 안에 single tap을 두면 .onTapGesture(count:2)와 충돌해 250ms 지연이 발생하므로
        // 모든 single-click 응답성을 위해 outer 한 군데에서만 처리한다.
        .contentShape(Rectangle())
        .onTapGesture {
            selectedEventId = nil
        }
        // 앱이 화면에 뜨자마자 1번만 실행되는 비동기 훅 — 카테고리 시드 트리거 자리.
        .task {
            EventCategory.seedIfNeeded(in: modelContext)
        }
        // 글로벌 키 핸들러 — Esc(선택 해제), Delete/Backspace(선택된 이벤트 삭제 요청).
        // .background에 hidden 버튼 + .keyboardShortcut으로 등록하는 SwiftUI macOS 관용 패턴.
        // sheet/alert가 떠 있을 때는 그쪽 키 핸들러가 우선이라 모달 동작과 충돌하지 않는다.
        .background {
            keyboardHandlers
        }
        // §5.4 — Delete 키로 삭제 요청 시 뜨는 확인 다이얼로그. chip 자체 우클릭 삭제는 chip 안에서 별도로 처리.
        .alert(
            pendingDeleteEvent.map { "\"\($0.title)\"을 삭제할까요?" } ?? "",
            isPresented: Binding(
                get: { pendingDeleteEvent != nil },
                set: { if !$0 { pendingDeleteEvent = nil } }
            ),
            presenting: pendingDeleteEvent
        ) { ev in
            Button("취소", role: .cancel) { }
                .keyboardShortcut(.defaultAction)
            Button("삭제", role: .destructive) {
                modelContext.delete(ev)
                try? modelContext.save()
                selectedEventId = nil
            }
        }
    }

    // 글로벌 키 핸들러 모음 — invisible 버튼들을 zero size로 깔아 단축키만 받는다.
    private var keyboardHandlers: some View {
        ZStack {
            Button {
                selectedEventId = nil
            } label: { EmptyView() }
                .keyboardShortcut(.escape, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)

            // KeyEquivalent.delete = macOS의 Backspace. forward delete(fn+Backspace)도 같이 등록.
            Button {
                requestDeleteSelected()
            } label: { EmptyView() }
                .keyboardShortcut(.delete, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)

            Button {
                requestDeleteSelected()
            } label: { EmptyView() }
                .keyboardShortcut(.deleteForward, modifiers: [])
                .opacity(0)
                .frame(width: 0, height: 0)
        }
    }

    // 선택된 이벤트가 있으면 modelContext에서 fetch해서 alert 대상으로 세팅.
    private func requestDeleteSelected() {
        guard let id = selectedEventId else { return }
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
        if let ev = try? modelContext.fetch(descriptor).first {
            pendingDeleteEvent = ev
        }
    }

    // 상단 띠 — A2 안. 토글 버튼이 좌측에, 우측은 비워둠.
    // leading 88pt는 macOS 신호등(빨/노/초)이 차지하는 자리(약 x=20~82)를 비우기 위함.
    // 높이 40pt: 토글 버튼(28pt)이 잘리지 않으면서 신호등과 거의 같은 세로선에 오도록.
    private var topStrip: some View {
        HStack {
            SidebarToggleButton(isVisible: $sidebarVisible)
            Spacer()
        }
        .padding(.leading, 88)
        .padding(.trailing, 16)
        .frame(height: 40)
    }

    // 본체 — HStack으로 사이드바와 캘린더를 좌·우로 나눈다.
    // sidebarVisible이 false면 사이드바와 그 옆의 Divider를 통째로 빼서 캘린더가 전체 폭을 차지.
    // 부모 뷰의 .animation 모디파이어가 if 분기 등장/사라짐을 부드럽게 보간한다.
    private var mainSplit: some View {
        HStack(spacing: 0) {
            if sidebarVisible {
                CategorySidebar()
                    // .move(edge: .leading): 사이드바가 좌측에서 슬라이드해 들어오고/나간다.
                    // .opacity 결합: 슬라이드 동안 페이드도 함께 — 끝점에서 깜빡임 방지.
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            // 캘린더 영역. 사이드바 펼침/접힘에 따라 자동으로 가용 폭 전체를 채운다.
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
                CalendarGrid(year: year, month: month, selectedEventId: $selectedEventId)
            }
            .frame(maxWidth: .infinity)
        }
        // 0.22초의 easeInOut — CATEGORY_FEATURE.md 5.2의 슬라이드 애니메이션 사양.
        .animation(.easeInOut(duration: 0.22), value: sidebarVisible)
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
