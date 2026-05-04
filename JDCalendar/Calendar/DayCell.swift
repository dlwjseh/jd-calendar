import SwiftUI
import SwiftData

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
    // 격자선을 마지막 행/칼럼에는 그리지 않기 위해 부모(WeekRow)가 알려주는 플래그.
    let isLastRow: Bool
    let isLastCol: Bool
    // 이 셀 날짜에 표시할 단일일 이벤트들 — 부모(WeekRow)에서 §4.4 필터/§4.5 정렬을 거쳐 넘겨준다.
    let events: [Event]
    // §5.6 popover용 — 그 날에 걸치는 모든 이벤트(단일일 + 멀티데이), §4.5 정렬 완료.
    let allEvents: [Event]
    // 이 셀 위로 지나가는 멀티데이 막대의 트랙 수(§4.3) — 그만큼 셀 안에 invisible spacer를 둬서
    // 단일일 chip이 막대 아래에 깔끔히 정렬되도록 한다. 실제 막대는 WeekRow의 overlay가 그린다.
    let multiDayTrackCount: Int
    // §5.1 — 한 번에 한 이벤트만 선택. 자식 EventChip에 그대로 binding으로 내려준다.
    @Binding var selectedEventId: UUID?

    // EVENT_FEATURE.md §3.1 — 셀 더블클릭 시 새 이벤트 시트.
    // 셀마다 자체 sheet 상태를 들고 있지만 SwiftUI 모달은 한 번에 하나만 뜨므로 충돌 없음.
    @State private var showingEditor = false
    // §5.6 — +M more 클릭 시 그 날의 모든 이벤트 popover.
    @State private var showingDayPopover = false
    // §6.1 — 드래그된 이벤트가 이 셀 위에 있을 때 외곽 강조용 플래그.
    @State private var isDropTarget = false
    // 마우스가 이 셀 위에 올라와 있는지 — 옅은 배경 틴트로 어떤 셀이 클릭 대상인지 알려준다.
    @State private var isHovered = false

    // §6.1 — 드롭된 이벤트를 fetch / 저장하기 위한 컨텍스트.
    @Environment(\.modelContext) private var modelContext

    private let theme = CalendarTheme.light

    // §4.2 — 셀당 최대 트랙 합계. v1 고정 3 (멀티데이 트랙 + 단일일 chip 합산).
    private static let maxTracks = 3
    // 멀티데이 막대 한 줄 트랙 높이 — WeekRow.trackHeight와 같아야 막대와 spacer가 정렬된다.
    private static let trackHeight: CGFloat = 16
    private static let trackSpacing: CGFloat = 2

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
        // VStack + Spacer — 날짜 숫자를 좌상단에 두고 그 아래 (멀티데이 자리) → 단일일 chips → 비움.
        VStack(alignment: .leading, spacing: 0) {
            label
            multiDaySpacer
            eventsList
            Spacer(minLength: 0)
        }
        // 셀이 그리드의 한 칸 전체를 채우게 늘리고, 글자는 좌상단 정렬.
        // maxHeight: .infinity로 설정해서 부모(VStack of HStacks)가 가용 높이를 균등 분배할 때 같이 커진다.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // 창이 너무 작아져도 셀이 96pt 아래로 줄지 않도록 안전장치 — 6주짜리 달의 최소 가독성 보장.
        .frame(minHeight: 96)
        // 안쪽 여백 — 위/좌/우/하를 따로 잡아서 디자인 원본과 동일한 간격으로 맞춤.
        .padding(.top, 5)
        .padding(.leading, 5)
        .padding(.trailing, 5)
        .padding(.bottom, 4)
        // 이번 달이 아닌 셀은 전체적으로 살짝 투명하게 — 흐리게 표시 효과.
        .opacity(cell.inMonth ? 1 : 0.55)
        // 빈 영역까지 더블클릭 대상이 되도록 셀 전체에 히트 영역.
        .contentShape(Rectangle())
        // §3.1 — 셀 더블클릭으로 새 이벤트 시트 열기.
        .onTapGesture(count: 2) {
            showingEditor = true
        }
        // §5.1 — 셀 빈 영역 single-click은 "consume만" — ContentView outer로 bubble되지 않아
        // 선택이 해제되지 않게. count: 2와 같이 두기 때문에 셀 빈 영역 자체는 약 250ms double-click
        // 대기가 있지만 액션이 빈 핸들러라 사용자가 인지할 일 없음. +M more / chip은 자체 핸들러로 처리.
        .onTapGesture(count: 1) {
            // intentionally empty — consume only.
        }
        // §6.1 — 다른 chip/막대를 끌어와 이 셀에 드롭하면 그 이벤트의 날짜를 평행 이동.
        // payload는 event.id 문자열.
        .dropDestination(for: String.self) { items, _ in
            guard let idString = items.first,
                  let id = UUID(uuidString: idString) else { return false }
            moveEvent(id: id, to: cell.date)
            return true
        } isTargeted: { hovering in
            isDropTarget = hovering
        }
        // 시트는 셀 단위 — initialDate로 셀 날짜를 넘긴다.
        .sheet(isPresented: $showingEditor) {
            EventEditor(initialDate: cell.date)
        }
        // 마우스 호버 감지 — 들어왔다/나갔다 boolean만 토글. 진입/이탈 즉시 반응(애니메이션 없음).
        .onHover { hovering in
            isHovered = hovering
        }
        // 호버 시 셀 전체에 옅은 그레이 틴트. 이번 달(cell.inMonth==true) 셀에만 적용 —
        // 흐림 처리된 채움 셀까지 호버 효과가 뜨면 시선이 분산되기 때문.
        // 격자선/드롭타겟 외곽선 overlay보다 앞 단계에 두어 그 위에 정상적으로 그려지게 함.
        .background(cell.inMonth && isHovered ? theme.hover : Color.clear)
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
        // §6.1 — 드래그된 항목이 이 셀 위에 호버 중이면 외곽 강조(theme.fg, 2pt).
        .overlay {
            if isDropTarget {
                Rectangle()
                    .strokeBorder(theme.fg, lineWidth: 2)
            }
        }
    }

    // §6.1 — 드롭된 이벤트를 새 시작 날짜로 평행 이동(시각·길이 보존).
    // - 멀티데이는 startAt/endAt 둘 다 같은 일 수만큼 shift → 길이 자동 유지.
    // - 같은 시작 날짜에 드롭하면 변경 없음(noop).
    // - 드롭 즉시 저장 — 확인 다이얼로그 없음(§6.1).
    // - withAnimation으로 chip의 사라짐/등장이 부드럽게 페이드.
    private func moveEvent(id: UUID, to targetDay: Date) {
        let descriptor = FetchDescriptor<Event>(predicate: #Predicate { $0.id == id })
        guard let ev = try? modelContext.fetch(descriptor).first else { return }

        let cal = Calendar.current
        let originDay = cal.startOfDay(for: ev.startAt)
        let target = cal.startOfDay(for: targetDay)
        let delta = cal.dateComponents([.day], from: originDay, to: target).day ?? 0
        guard delta != 0 else { return }

        if let newStart = cal.date(byAdding: .day, value: delta, to: ev.startAt),
           let newEnd = cal.date(byAdding: .day, value: delta, to: ev.endAt) {
            withAnimation(.easeInOut(duration: 0.22)) {
                ev.startAt = newStart
                ev.endAt = newEnd
            }
            try? modelContext.save()
        }
    }

    // 멀티데이 막대 자리 — overlay에 그려지는 막대들의 영역만큼 빈 공간.
    // 트랙 N개라면 (N * trackHeight) + ((N-1) * trackSpacing) 만큼 비움.
    @ViewBuilder
    private var multiDaySpacer: some View {
        if multiDayTrackCount > 0 {
            let h = CGFloat(multiDayTrackCount) * Self.trackHeight
                  + CGFloat(max(0, multiDayTrackCount - 1)) * Self.trackSpacing
            // 첫 트랙 직전 padding(2pt)도 함께 — WeekRow.firstTrackTop 계산과 일치.
            Spacer().frame(height: h + 2)
        }
    }

    // 셀 안 단일일 이벤트 목록 — §4.2 트랙 합계 max 3 기준으로 표시 가능 슬롯 계산.
    // 멀티데이 트랙이 3개 이상이면 단일일 chip은 한 개도 못 들어가고, 모자란 만큼 +M more에 합산.
    // +M more 클릭 → §5.6 popover로 그 날의 모든 이벤트 표시.
    @ViewBuilder
    private var eventsList: some View {
        let availableSlots = max(0, Self.maxTracks - multiDayTrackCount)
        let visibleSingles = events.prefix(availableSlots)
        let hiddenSingles = max(0, events.count - visibleSingles.count)
        // overflow는 표시 못한 단일일 수만 — 멀티데이는 overlay로 이미 보이고 있으니 카운트하지 않는다.
        let overflow = hiddenSingles

        VStack(alignment: .leading, spacing: 1) {
            ForEach(Array(visibleSingles), id: \.id) { ev in
                EventChip(event: ev, selectedEventId: $selectedEventId)
            }
            if overflow > 0 {
                // Button 대신 Text + .onTapGesture — Button의 macOS press feedback latency를 피해
                // popover가 더 즉각적으로 뜬다. Text 자체에 count:1만 있으므로 double-click 대기도 없음.
                Text("+\(overflow) more")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.muted)
                    .padding(.leading, 4)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showingDayPopover = true
                    }
                    // §5.6 — popover로 그 날의 모든 이벤트(단일일 + 멀티데이) 표시.
                    // 외부 클릭/Esc로 자동 닫힘은 .popover의 native 동작.
                    .popover(isPresented: $showingDayPopover, arrowEdge: .top) {
                        DayEventsPopover(
                            date: cell.date,
                            events: allEvents,
                            selectedEventId: $selectedEventId
                        )
                    }
            }
        }
        // 멀티데이 트랙이 없는 셀은 라벨 직후 작은 padding으로 시작.
        .padding(.top, multiDayTrackCount == 0 ? 2 : 0)
    }

    // 날짜 숫자 라벨. 오늘이면 빨간 캡슐 + 흰 글자, 아니면 평범한 글자만.
    // 둘 다 minHeight: 20으로 통일 — 셀 안 콘텐츠(멀티데이 spacer/단일일 chip) 시작 높이가 일정해야
    // WeekRow overlay의 막대 y 좌표(firstTrackTop)와 정렬된다.
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
                // today 셀과 같은 minHeight로 정렬.
                .frame(minHeight: 20, alignment: .topLeading)
        }
    }
}
