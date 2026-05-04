import SwiftUI
import SwiftData

// 카테고리 신규 생성 / 편집 다이얼로그.
// CATEGORY_FEATURE.md 5.5 — 라벨 없이 placeholder만, 이름 줄 좌측 색 점이 사이드바 미리보기 역할.
//
// editing 인자가 nil이면 신규 생성, EventCategory가 들어오면 그 카테고리 편집 모드.
struct CategoryEditor: View {
    // 편집 대상 — nil이면 신규 생성, 값이 있으면 그 카테고리를 수정한다.
    let editing: EventCategory?

    // 시트 닫기용 — 환경값 dismiss는 sheet/modal이 자동 주입.
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    // 자동 색상 픽 시 "사용 안 된 색" 판정용 — 시트에서도 SwiftData @Query가 동작.
    @Query(sort: \EventCategory.createdAt) private var existingCategories: [EventCategory]

    // 폼 상태 — 사용자 입력에 따라 바뀜.
    @State private var name: String
    @State private var note: String
    // 선택된 색의 hex. 신규 생성 시 onAppear에서 자동 픽으로 덮어쓴다(편집 모드는 init에서 미리 채움).
    @State private var selectedHex: String

    private let theme = CalendarTheme.light

    // 신규/편집 모두 같은 init을 쓴다. 편집이면 기존 값을 @State 초기값으로 넣어 폼이 미리 채워진다.
    init(editing: EventCategory? = nil) {
        self.editing = editing
        // _name 등 underscore 접근 — init에서 @State 직접 초기화하는 SwiftUI 문법.
        _name = State(initialValue: editing?.name ?? "")
        _note = State(initialValue: editing?.note ?? "")
        _selectedHex = State(initialValue: editing?.color ?? CategoryPalette.all[0].hex)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // 5.5 모드 구분 — 신규 시 "새 카테고리", 편집 시 "카테고리 편집".
            Text(editing == nil ? "새 카테고리" : "카테고리 편집")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.fg)
            nameRow
            colorPicker
            noteEditor
            buttonRow
        }
        .padding(20)
        .frame(width: 360)
        .background(theme.bg)
        // 신규 생성일 때만 자동 색상 픽 적용 — 편집 모드는 기존 색을 그대로 유지해야 함.
        .onAppear {
            if editing == nil {
                selectedHex = autoPickColor(from: existingCategories)
            }
        }
    }

    // 이름 줄 — 좌측에 색 점(미리보기), 우측에 텍스트 필드. 외곽선으로 입력 영역을 명시.
    private var nameRow: some View {
        HStack(spacing: 10) {
            // 5.5: 점은 표시 전용(클릭 비활성). 사이드바 행과 같은 모양으로 미리보기.
            Circle()
                .fill(Color(hex: selectedHex))
                .frame(width: 14, height: 14)

            TextField("이름", text: $name)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(theme.line, lineWidth: 1)
        )
    }

    // 색상 영역 — 4 cols × 3 rows의 12색 + 마지막 행에 자유 색(⊕) 한 칸 추가.
    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            paletteRow(0..<4)
            paletteRow(4..<8)
            HStack(spacing: 10) {
                ForEach(Array(CategoryPalette.all[8..<12]), id: \.index) { swatch in
                    swatchView(swatch)
                }
                customSwatchView
            }
        }
    }

    // 한 행에 4개의 팔레트 스와치를 가로로 나열 — colorPicker에서 0~7번을 두 행으로 그릴 때 재사용.
    private func paletteRow(_ range: Range<Int>) -> some View {
        HStack(spacing: 10) {
            ForEach(Array(CategoryPalette.all[range]), id: \.index) { swatch in
                swatchView(swatch)
            }
        }
    }

    // 한 칸의 팔레트 스와치 — 클릭하면 해당 hex가 선택됨. 선택 시 외곽 링으로 표시.
    private func swatchView(_ swatch: CategoryPalette.Swatch) -> some View {
        let isSelected = selectedHex.uppercased() == swatch.hex.uppercased()
        return ZStack {
            // 항상 28pt 자리를 차지하도록 바깥 프레임을 미리 깔아둔다 — 외곽 링이 붙고 떨어질 때 시프트 방지.
            Color.clear.frame(width: 28, height: 28)
            Circle()
                .fill(Color(hex: swatch.hex))
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .strokeBorder(theme.fg, lineWidth: 2)
                    .frame(width: 28, height: 28)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedHex = swatch.hex
        }
    }

    // 자유 색 ⊕ 타일 — SwiftUI ColorPicker를 거의 투명하게 깔아 클릭 영역으로만 쓰고,
    // 그 위에 점선 원 + "+" 아이콘으로 우리가 원하는 모양을 그린다.
    // ColorPicker가 클릭되면 macOS의 NSColorPanel이 자동으로 떠 색 선택을 받는다.
    private var customSwatchView: some View {
        // 현재 선택된 색이 팔레트의 어떤 hex와도 일치하지 않으면 "자유 색"이 선택된 상태.
        let isPaletteColor = CategoryPalette.all.contains { $0.hex.uppercased() == selectedHex.uppercased() }
        let isCustomSelected = !isPaletteColor

        return ZStack {
            Color.clear.frame(width: 28, height: 28)

            if isCustomSelected {
                // 자유 색이 선택된 상태 — 그 색으로 채운 원 + 외곽 링.
                Circle()
                    .fill(Color(hex: selectedHex))
                    .frame(width: 22, height: 22)
                Circle()
                    .strokeBorder(theme.fg, lineWidth: 2)
                    .frame(width: 28, height: 28)
            } else {
                // 미선택 상태 — 점선 외곽 원 + "+" 아이콘으로 "사용자 지정" 의도 표시.
                Circle()
                    .strokeBorder(
                        theme.fg.opacity(0.35),
                        style: StrokeStyle(lineWidth: 1, dash: [3])
                    )
                    .frame(width: 22, height: 22)
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.fg.opacity(0.6))
            }

            // 거의 투명한 ColorPicker — 클릭 시 NSColorPanel 호출.
            // opacity 0이면 hit testing이 빠지므로 0.011로 살짝 띄워둔다(흔히 쓰는 트릭).
            ColorPicker(
                "",
                selection: Binding(
                    get: { Color(hex: selectedHex) },
                    set: { selectedHex = $0.toHexString() }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 28, height: 28)
            .opacity(0.011)
        }
    }

    // 노트 영역 — TextEditor에 placeholder가 없어서 ZStack 오버레이로 직접 그린다(5.5 구현 노트).
    private var noteEditor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $note)
                .font(.system(size: 13))
                .scrollContentBackground(.hidden)  // 시스템 기본 흰 배경 끄기 → theme.bg 비치게
                .frame(height: 80)
                .padding(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.line, lineWidth: 1)
                )

            if note.isEmpty {
                Text("노트 (옵션)")
                    .font(.system(size: 13))
                    .foregroundStyle(theme.muted)
                    // TextEditor 내부 텍스트 시작 위치에 맞춤:
                    // - 가로: 외곽 padding 8 + NSTextView lineFragmentPadding ≈ 5 = 13
                    // - 세로: 외곽 padding 8 + NSTextView textContainer top inset ≈ 0 = 8
                    .padding(.leading, 13)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
    }

    // 버튼 줄 — 우측 정렬 [취소][저장]. 단축키: Esc=취소, Enter=저장.
    private var buttonRow: some View {
        HStack {
            Spacer()
            Button("취소") { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button("저장") { save() }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
        }
    }

    // 저장 가능 여부 — 1~20자, 공백 제거 후 비어 있지 않아야 함.
    private var isValid: Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 20
    }

    // 5.5 자동 색상 픽 — 팔레트 10색 중 다른 카테고리에서 사용되지 않은 첫 색.
    // 자유 색은 비교 대상에서 제외. 팔레트가 다 차면 #1 Brick으로 폴백.
    private func autoPickColor(from existing: [EventCategory]) -> String {
        let used = Set(existing.map { $0.color.uppercased() })
        for swatch in CategoryPalette.all where !used.contains(swatch.hex.uppercased()) {
            return swatch.hex
        }
        return CategoryPalette.all[0].hex
    }

    // 저장 — 신규면 새 EventCategory 삽입, 편집이면 기존 인스턴스 필드 갱신.
    // SwiftData는 @Model 클래스의 프로퍼티 변경을 자동으로 추적·저장한다.
    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cat = editing {
            cat.name = trimmed
            cat.color = selectedHex
            cat.note = note
        } else {
            let cat = EventCategory(name: trimmed, color: selectedHex, note: note)
            modelContext.insert(cat)
        }
        try? modelContext.save()
        dismiss()
    }
}
