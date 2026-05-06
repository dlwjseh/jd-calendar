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

    // 셀이 클릭되었을 때 화면 위에 띄우는 modal overlay 상태.
    // nil이면 overlay가 떠 있지 않음. dim 배경 + DayEventsPopover 카드.
    @State private var pickedDay: PickedDay? = nil
    // + 버튼이 트리거하는 새 이벤트 시트의 대상 날짜. .sheet(item:)을 위해 wrapper.
    @State private var newEventDate: PickedDate? = nil
    // 행 클릭이 트리거하는 편집 시트의 대상 이벤트.
    @State private var editingEvent: Event? = nil

    // §6.2 — 가로 스와이프로 월 이동을 처리하는 NSEvent monitor.
    @StateObject private var swipeMonitor = MonthSwipeMonitor()

    // 월 이동 transition 방향 — prev/next/today/swipe가 호출 직전에 세팅 → calendarTransition이 읽음.
    // 시작값은 forward(별 의미 없음 — 첫 렌더에선 transition이 발화되지 않음).
    @State private var navDirection: NavDirection = .forward

    private let theme = CalendarTheme.light

    // 월 이동 방향 — 이전 달인지 다음 달인지에 따라 grid가 좌/우로 슬라이드.
    enum NavDirection {
        case forward, backward
    }

    // modal overlay에 띄울 날짜 + 그 날의 이벤트 묶음. id를 통해 등장/소멸 transition 트리거.
    struct PickedDay: Identifiable {
        let id = UUID()
        let date: Date
        let events: [Event]
    }

    // sheet(item:)을 위한 단순 wrapper — Date 자체는 Identifiable이 아니므로.
    struct PickedDate: Identifiable {
        let id = UUID()
        let date: Date
    }

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
        // ZStack — 아래 layer는 기존 캘린더 화면, 위 layer는 셀 클릭 시 뜨는 dim + 카드 overlay.
        ZStack {
            // 새로운 레이아웃(슬라이스 2) — 위에서 아래로:
            //   1) 상단 띠: 사이드바 토글 버튼(좌상단 고정)
            //   2) 본체: 좌(사이드바, 펼침일 때) | 우(달력 헤더+요일행+그리드)
            VStack(spacing: 0) {
                topStrip
                mainSplit
            }

            // 셀 클릭 modal overlay — 화면 전체 dim + 가운데 카드.
            if let pick = pickedDay {
                // dim 배경 — 캘린더 위에 검정 오버레이로 카드를 도드라지게. 외부 클릭으로 닫힘.
                Color.black.opacity(0.38)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { pickedDay = nil }
                    .transition(.opacity)

                // 헤더(양력+음력+ 버튼) + 카드(이벤트 리스트) — 화면 가운데에 floating.
                DayEventsPopover(
                    date: pick.date,
                    events: pick.events,
                    onAddNew: {
                        // overlay를 먼저 닫고 짧은 지연 후 sheet — 같은 tick에 겹치면 sheet가
                        // 안 뜨는 macOS 사례 회피.
                        let d = pick.date
                        pickedDay = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            newEventDate = PickedDate(date: d)
                        }
                    },
                    onEdit: { ev in
                        pickedDay = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            editingEvent = ev
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
        }
        // overlay 등장/소멸 애니메이션. pickedDay?.id로 같은 셀을 다시 클릭해도 트랜지션 발화.
        .animation(.easeInOut(duration: 0.16), value: pickedDay?.id)
        // 부모(창)가 주는 공간을 끝까지 다 차지하도록 펼친다.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.bg)
        .foregroundStyle(theme.fg)
        // 타이틀바를 숨겼으므로 콘텐츠가 창 가장자리(safe area)를 무시하고 끝까지 그려지게 한다.
        .ignoresSafeArea()
        // 새 이벤트 시트 — overlay의 + 버튼이 트리거.
        .sheet(item: $newEventDate) { wrap in
            EventEditor(initialDate: wrap.date)
        }
        // 편집 시트 — overlay의 행 클릭이 트리거.
        .sheet(item: $editingEvent) { ev in
            EventEditor(editing: ev, initialDate: ev.startAt)
        }
        // 앱이 화면에 뜨자마자 1번만 실행되는 비동기 훅 — 카테고리 시드 + 팔레트 마이그레이션 + 공휴일 동기화.
        // 순서가 중요: seed 가 먼저여야 첫 실행 시 "기본" 사용자 카테고리가 만들어진다.
        // (공휴일 sync 가 먼저 돌면 "공휴일" 카테고리만 존재해서 seed 가 no-op 으로 끝난다.)
        .task {
            EventCategory.seedIfNeeded(in: modelContext)
            EventCategory.migratePaletteIfNeeded(in: modelContext)
            // 일별 1회 휴일 갱신. UserDefaults 의 마지막 sync 일자가 오늘이면 내부에서 즉시 반환.
            await HolidaySyncService.syncIfNeeded(in: modelContext)
        }
        // §6.2 — 가로 스와이프 월 이동: monitor에 prev/next callback을 wire하고 시작.
        .onAppear {
            swipeMonitor.onPrev = prev
            swipeMonitor.onNext = next
            swipeMonitor.start()
        }
        .onDisappear {
            swipeMonitor.stop()
        }
        // cursor 가 움직일 때마다 그리드가 보여주는 연도들을 ensure.
        // year 가 아니라 month 를 watch 하는 이유: 같은 해 안에서 12월↔1월 으로 이동할 때도
        // spillover 연도가 달라지기 때문에 — month 변화가 모든 cursor 이동을 빠짐없이 잡는다.
        // ±1 daily 범위 안 / 이미 fetch 한 연도는 HolidaySyncService 안에서 즉시 no-op 처리.
        .onChange(of: month) { _, _ in
            Task {
                await HolidaySyncService.ensureYearsForCursor(
                    year: year,
                    month: month,
                    in: modelContext
                )
            }
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
                // 월이 바뀔 때 좌/우 슬라이드 + 페이드 transition.
                // .id()로 (year, month) 조합마다 별도 view identity → SwiftUI가 transition 발화.
                // 잘림 방지로 .clipped() — 이전 달 grid가 트랙 바깥으로 밀려나가는 동안 가려짐.
                CalendarGrid(year: year, month: month, onPickDay: { date, events in
                    pickedDay = PickedDay(date: date, events: events)
                })
                    .id("\(year)-\(month)")
                    .transition(calendarTransition)
            }
            .frame(maxWidth: .infinity)
            .clipped()
        }
        // 0.22초의 easeInOut — CATEGORY_FEATURE.md 5.2의 슬라이드 애니메이션 사양.
        .animation(.easeInOut(duration: 0.22), value: sidebarVisible)
    }

    // 월 이동 transition — 방향에 따라 새 grid가 들어오는 / 옛 grid가 나가는 edge가 달라진다.
    // forward: 새 달이 우측에서 들어오고 옛 달이 좌측으로 나감.
    // backward: 새 달이 좌측에서 들어오고 옛 달이 우측으로 나감.
    // 둘 다 .opacity와 결합해 끝점 깜빡임을 부드럽게.
    private var calendarTransition: AnyTransition {
        switch navDirection {
        case .forward:
            return .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
            )
        case .backward:
            return .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            )
        }
    }

    // 월 이동 transition 스펙 — 헤더 버튼/Today/스와이프 모두 같은 곡선·시간으로 이동.
    private static let monthNavAnimation: Animation = .easeInOut(duration: 0.28)

    // 이전 달로 이동 — 1월에서 누르면 작년 12월로 넘어간다. backward 슬라이드 transition.
    private func prev() {
        navDirection = .backward
        withAnimation(Self.monthNavAnimation) {
            if month == 0 {
                year -= 1
                month = 11
            } else {
                month -= 1
            }
        }
    }

    // 다음 달로 이동 — 12월에서 누르면 내년 1월로 넘어간다. forward 슬라이드 transition.
    private func next() {
        navDirection = .forward
        withAnimation(Self.monthNavAnimation) {
            if month == 11 {
                year += 1
                month = 0
            } else {
                month += 1
            }
        }
    }

    // Today 버튼 — 어느 달을 보고 있든 오늘이 속한 달로 점프.
    // 현재 달과의 절대값 비교로 forward/backward 방향 결정 → 자연스러운 슬라이드.
    private func today() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let newYear = cal.component(.year, from: now)
        let newMonth = cal.component(.month, from: now) - 1

        let oldKey = year * 12 + month
        let newKey = newYear * 12 + newMonth
        guard newKey != oldKey else { return }
        navDirection = newKey > oldKey ? .forward : .backward

        withAnimation(Self.monthNavAnimation) {
            year = newYear
            month = newMonth
        }
    }
}

// #Preview: Xcode 캔버스에서 ContentView를 미리 볼 때 쓰는 매크로. 빌드된 앱에는 포함되지 않는다.
#Preview {
    ContentView()
        .frame(width: 1100, height: 720)
}
