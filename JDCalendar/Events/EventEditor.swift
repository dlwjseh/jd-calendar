import SwiftUI
import SwiftData

// 이벤트 신규 생성 / 편집 다이얼로그.
// EVENT_FEATURE.md §3 — 라벨 없이 placeholder/짧은 인라인 라벨만, 화면 중앙 모달 시트.
//
// editing 인자가 nil이면 신규 생성, Event가 들어오면 그 이벤트 편집 모드.
// initialDate는 신규일 때 시작·종료 날짜의 디폴트(§3.4) — 편집 모드에선 무시된다.
struct EventEditor: View {
    let editing: Event?
    let initialDate: Date

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 카테고리 드롭다운 후보. 사이드바와 같은 정렬(생성 순) 사용.
    @Query(sort: \EventCategory.createdAt) private var categories: [EventCategory]

    // 마지막에 사용한 카테고리 id를 UUID 문자열로 저장(§3.4).
    // 다음 신규 생성 시 이 값을 우선 픽한다.
    @AppStorage("eventEditorLastCategoryId") private var lastUsedCategoryId: String = ""

    // 폼 상태.
    @State private var selectedCategory: EventCategory?
    @State private var title: String
    @State private var isAllDay: Bool
    // 종일이든 시간지정이든 같은 Date에 시각까지 함께 들고 다닌다.
    // 종일 토글이 on일 때도 시각 부분(09:00/10:00)을 유지 — off로 토글 시 그대로 사용 가능.
    @State private var startAt: Date
    @State private var endAt: Date
    @State private var note: String
    // 메모 영역 표시 모드 — false면 "메모 추가" 버튼만, true면 TextEditor (§3.3.6).
    @State private var noteEditorVisible: Bool

    // §5.2 / §5.4 — 편집 모드의 좌측 하단 삭제 버튼이 띄우는 확인 다이얼로그.
    @State private var showingDeleteAlert = false

    // 시트 등장 시 제목 필드에 자동 포커스 — 사용자가 바로 타자 칠 수 있게.
    @FocusState private var titleFocused: Bool

    private let theme = CalendarTheme.light

    // 신규/편집 공용 init. 편집이면 기존 이벤트 값을 @State 초기값으로 채운다.
    // 종일 이벤트의 endAt은 모델에선 배타적(다음날 00:00)이지만 폼에선 "끝나는 날 포함"으로 보여줘야 하므로 -1일 보정.
    init(editing: Event? = nil, initialDate: Date) {
        self.editing = editing
        self.initialDate = initialDate

        if let ev = editing {
            _title = State(initialValue: ev.title)
            _isAllDay = State(initialValue: ev.isAllDay)
            _startAt = State(initialValue: ev.startAt)
            // 종일이면 모델의 배타적 endAt에서 1일 빼서 "포함되는 마지막 날"로 폼에 표시.
            if ev.isAllDay {
                let cal = Calendar.current
                _endAt = State(initialValue: cal.date(byAdding: .day, value: -1, to: ev.endAt) ?? ev.endAt)
            } else {
                _endAt = State(initialValue: ev.endAt)
            }
            _note = State(initialValue: ev.note)
            // 편집 모드에서 기존 메모가 비어있지 않으면 처음부터 TextEditor 표시(§3.3.6).
            _noteEditorVisible = State(initialValue: !ev.note.isEmpty)
            _selectedCategory = State(initialValue: ev.category)
        } else {
            // 신규 — initialDate 기준으로 09:00/10:00 디폴트.
            // 종일 toggle은 on이지만 시각은 미리 채워둬서 토글 off 시 자동 사용된다.
            _title = State(initialValue: "")
            _isAllDay = State(initialValue: true)
            let cal = Calendar.current
            let day = cal.startOfDay(for: initialDate)
            let nineAM = cal.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
            let tenAM  = cal.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day
            _startAt = State(initialValue: nineAM)
            _endAt   = State(initialValue: tenAM)
            _note = State(initialValue: "")
            _noteEditorVisible = State(initialValue: false)
            // 카테고리는 onAppear에서 채움 — @Query 결과를 init에서 못 읽기 때문.
            _selectedCategory = State(initialValue: nil)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 5.5 모드 구분 — 신규 시 "새 이벤트", 편집 시 "이벤트 편집"(§3.2).
            Text(editing == nil ? "새 이벤트" : "이벤트 편집")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.fg)

            categoryRow
            titleRow
            allDayToggle
            dateRow(label: "시작", date: $startAt)
            dateRow(label: "종료", date: $endAt)
            noteSection
            buttonRow
        }
        .padding(20)
        .frame(width: 400)
        .background(theme.bg)
        // 신규 생성일 때만 카테고리 자동 선택 — 편집 모드는 init에서 이미 채움.
        .onAppear {
            if editing == nil && selectedCategory == nil {
                selectedCategory = pickInitialCategory()
            }
            // 약간 지연시켜 시트 애니메이션 후 포커스 — macOS에서 즉시 포커스 시 가끔 무시됨.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                titleFocused = true
            }
        }
        // 시작 시각이 바뀌면 종료가 같은 길이를 유지하도록 평행 이동(§3.5, EventKit 표준).
        .onChange(of: startAt) { oldValue, newValue in
            let delta = newValue.timeIntervalSince(oldValue)
            endAt = endAt.addingTimeInterval(delta)
        }
        // 종일 ↔ 시간지정 토글(§3.5).
        // on → off: 시각을 09:00/10:00으로 자동 채움(이미 디폴트가 그렇게 들어있지만, 편집 중 사용자가
        //          한번 시간지정으로 바꿨다가 종일로 돌리고 다시 시간지정으로 바꾸면 09:00/10:00로 리셋).
        // off → on: 시각은 그대로 두고(저장 시 정규화로 버려짐) 날짜만 의미 있음.
        .onChange(of: isAllDay) { oldValue, newValue in
            if oldValue == true && newValue == false {
                let cal = Calendar.current
                startAt = cal.date(bySettingHour: 9, minute: 0, second: 0, of: startAt) ?? startAt
                endAt   = cal.date(bySettingHour: 10, minute: 0, second: 0, of: endAt) ?? endAt
            }
        }
        // §5.4 — 삭제 확인 다이얼로그(편집 모드 전용). 본문 없음, 기본 버튼은 취소.
        .alert(deleteTitle, isPresented: $showingDeleteAlert) {
            Button("취소", role: .cancel) { }
                .keyboardShortcut(.defaultAction)
            Button("삭제", role: .destructive) {
                deleteEvent()
            }
        }
    }

    // §5.4 — 제목은 항상 "<제목>"을 삭제할까요?
    private var deleteTitle: String {
        editing.map { "\"\($0.title)\"을 삭제할까요?" } ?? ""
    }

    // 카테고리 줄 — Menu로 직접 그려 색 점이 드롭다운 아이템에도 보이게.
    // SwiftUI Picker(.menu)는 macOS에서 색 원이 잘 안 그려져서 Menu 사용.
    private var categoryRow: some View {
        Menu {
            ForEach(categories, id: \.id) { cat in
                Button {
                    selectedCategory = cat
                } label: {
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: cat.color)).frame(width: 10, height: 10)
                        Text(cat.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let cat = selectedCategory {
                    Circle().fill(Color(hex: cat.color)).frame(width: 10, height: 10)
                    Text(cat.name).foregroundStyle(theme.fg)
                } else {
                    Text("카테고리").foregroundStyle(theme.muted)
                }
                Spacer()
                // 드롭다운임을 알리는 인디케이터.
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.fg.opacity(0.5))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .overlay(
                RoundedRectangle(cornerRadius: 6).stroke(theme.line, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize(horizontal: false, vertical: true)
    }

    // 제목 줄 — 좌측에 카테고리 색 점(표시 전용, §3.3.2) + 한 줄 텍스트 필드.
    private var titleRow: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: selectedCategory?.color ?? "#BFBFBF"))
                .frame(width: 14, height: 14)

            TextField("제목", text: $title)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($titleFocused)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 6).stroke(theme.line, lineWidth: 1)
        )
    }

    // 종일 토글 한 개. 켜져 있으면 dateRow의 시각 부분이 숨겨진다.
    private var allDayToggle: some View {
        Toggle("종일", isOn: $isAllDay)
            .toggleStyle(.switch)
            .controlSize(.small)
    }

    // 시작/종료 줄 공용 — 라벨 + 날짜 picker (+ 시각 picker, 시간지정일 때만).
    // 디자인 §3.3에는 "라벨 없이"라고 적혀 있지만 DatePicker는 placeholder 개념이 없어 시작/종료 구분이 필요.
    // 짧은 인라인 라벨로 최소한의 신호만 준다.
    private func dateRow(label: String, date: Binding<Date>) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(theme.fg.opacity(0.75))
                .frame(width: 36, alignment: .leading)

            DatePicker("", selection: date, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .environment(\.locale, Locale(identifier: "ko_KR"))

            if !isAllDay {
                DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .environment(\.locale, Locale(identifier: "ko_KR"))
            }

            Spacer(minLength: 0)
        }
    }

    // 메모 영역 — 처음엔 "메모 추가" 버튼, 클릭하면 TextEditor로 교체(§3.3.6).
    @ViewBuilder
    private var noteSection: some View {
        if noteEditorVisible {
            // 카테고리 노트 에디터와 동일한 패턴 — TextEditor에 placeholder가 없어서 ZStack 오버레이로 직접.
            ZStack(alignment: .topLeading) {
                TextEditor(text: $note)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(height: 80)
                    .padding(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6).stroke(theme.line, lineWidth: 1)
                    )

                if note.isEmpty {
                    Text("메모 (옵션)")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.muted)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
        } else {
            Button {
                noteEditorVisible = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                    Text("메모 추가")
                        .font(.system(size: 13))
                }
                .foregroundStyle(theme.fg.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6).stroke(theme.line, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // 버튼 줄 — 우측 정렬 [취소][저장]. 편집 모드에선 좌측 하단에 [삭제]도(§5.2).
    // 단축키: Esc=취소, Enter=저장. §3.5의 Cmd+Enter는 v1엔 미지원(Enter만으로 충분).
    private var buttonRow: some View {
        HStack {
            // 편집 모드 전용 destructive 좌측 정렬 — macOS HIG 패턴.
            if editing != nil {
                Button("삭제", role: .destructive) {
                    showingDeleteAlert = true
                }
            }
            Spacer()
            Button("취소") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("저장") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
    }

    // 저장 가능 여부.
    // - 제목이 공백 제외 비어있지 않음
    // - 카테고리 선택됨
    // - 종일: 종료 날짜 ≥ 시작 날짜 (단일일 허용)
    // - 시간지정: endAt > startAt (분 단위 정규화 후 strict)
    private var isValid: Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, selectedCategory != nil else { return false }

        let cal = Calendar.current
        if isAllDay {
            return cal.startOfDay(for: endAt) >= cal.startOfDay(for: startAt)
        } else {
            return normalizeToMinute(endAt) > normalizeToMinute(startAt)
        }
    }

    // §3.4 — 마지막 사용한 카테고리 우선, 없으면 첫 카테고리(=시드 "기본").
    private func pickInitialCategory() -> EventCategory? {
        if !lastUsedCategoryId.isEmpty,
           let id = UUID(uuidString: lastUsedCategoryId),
           let cat = categories.first(where: { $0.id == id }) {
            return cat
        }
        return categories.first
    }

    // 시간지정 이벤트의 초 이하 정규화 — 분 단위까지만 의미 있게 저장(§1.2).
    private func normalizeToMinute(_ d: Date) -> Date {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: d)
        return cal.date(from: comps) ?? d
    }

    // 저장용 정규화 — 종일이면 §1.2의 iCal식 배타적 endAt으로 변환.
    private func normalizedSaveDates() -> (Date, Date) {
        let cal = Calendar.current
        if isAllDay {
            let startDay = cal.startOfDay(for: startAt)
            let endDay = cal.startOfDay(for: endAt)
            // "끝나는 날 포함" → "끝나는 날 + 1일 00:00"으로 변환.
            let endNextDay = cal.date(byAdding: .day, value: 1, to: endDay) ?? endDay
            return (startDay, endNextDay)
        } else {
            return (normalizeToMinute(startAt), normalizeToMinute(endAt))
        }
    }

    // 편집 모드 삭제 — 이벤트 제거 후 시트 닫기(§5.2).
    private func deleteEvent() {
        if let ev = editing {
            modelContext.delete(ev)
            try? modelContext.save()
        }
        dismiss()
    }

    // 저장 — 신규면 새 Event 삽입, 편집이면 기존 인스턴스 필드 갱신.
    private func save() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cat = selectedCategory else { return }

        let (normStart, normEnd) = normalizedSaveDates()

        if let ev = editing {
            ev.title = trimmed
            ev.startAt = normStart
            ev.endAt = normEnd
            ev.isAllDay = isAllDay
            ev.note = note
            ev.category = cat
        } else {
            let ev = Event(
                title: trimmed,
                startAt: normStart,
                endAt: normEnd,
                isAllDay: isAllDay,
                note: note,
                category: cat
            )
            modelContext.insert(ev)
        }

        // 마지막 사용 카테고리 갱신 — 다음 신규 생성 시 이 카테고리가 디폴트로.
        lastUsedCategoryId = cat.id.uuidString

        try? modelContext.save()
        dismiss()
    }
}
