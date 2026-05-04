import Foundation
import SwiftData

// 이벤트 분류 단위. CATEGORY_FEATURE.md 1번 데이터 모델 그대로 구현.
//
// 타입명을 그냥 `Category`로 두지 않은 이유: 시스템 프레임워크(`OpaquePointer.Category` 등)와
// 이름이 충돌해 `.modelContainer(for: [Category.self])`에서 컴파일 에러가 난다.
// `EventCategory`로 두면 의미(="이벤트 분류")도 더 명확해진다.
//
// SwiftData가 영속화·관계·관찰을 모두 책임진다(4번 저장소).
// @Model 매크로는 이 클래스를 SwiftData가 관리할 수 있는 "엔티티"로 변환한다.
// 클래스로 선언해야 하는 이유: SwiftData는 객체의 변경을 추적하기 위해 참조 타입을 요구한다.
@Model
final class EventCategory {
    // 카테고리의 고유 식별자. UUID는 충돌 가능성이 사실상 없어 동기화/마이그레이션에 안전하다.
    // @Attribute(.unique)로 SwiftData에 "이 필드는 중복 불가"라고 알려준다.
    @Attribute(.unique) var id: UUID

    // 사이드바와 다이얼로그에 표시되는 이름. 1~20자 검증은 입력 단(편집 다이얼로그)에서 한다.
    var name: String

    // 색상은 hex 문자열로 저장한다("#RRGGBB").
    // 팔레트 색이든 사용자 자유 색이든 모두 같은 형식 → 모델은 단일 String으로 단순화.
    var color: String

    // 사용자가 자유롭게 적는 메모. 빈 문자열 허용으로 옵셔널 의미를 표현.
    var note: String

    // 생성 시각. v1에서는 사이드바 정렬 기준으로 사용된다(생성 순서대로 보임).
    var createdAt: Date

    // 사이드바의 색상 점 체크박스가 켜져 있는지 여부.
    // 다음 실행에도 유지하기로 했으므로(Q-1 결정) 모델 필드로 저장한다.
    var isVisible: Bool

    // 시스템(앱)이 자동 생성/관리하는 카테고리인지 여부.
    // true면 사용자는 색상점 토글(보이기/숨기기)만 할 수 있고 편집/삭제는 불가 — UI(CategoryRow)가 강제.
    // 예: 한국천문연구원 API에서 가져오는 "공휴일" 카테고리.
    // 새 필드라 기본값 false 를 둬서 SwiftData lightweight migration 시 기존 행이 자동 채워지도록.
    var isSystemManaged: Bool = false

    // 이 카테고리에 속한 이벤트들 — EVENT_FEATURE.md §1.4.
    // deleteRule: .cascade → 카테고리 삭제 시 그 카테고리의 이벤트도 함께 삭제(CATEGORY_FEATURE.md §1/§8).
    // inverse는 Event.category — 이쪽에서 inverse를 선언하면 SwiftData가 양방향을 자동 관리한다.
    @Relationship(deleteRule: .cascade, inverse: \Event.category)
    var events: [Event] = []

    // 기본 생성자 — 모든 필드를 받지만 실용적인 디폴트를 깔아둠.
    // id/createdAt/isVisible/isSystemManaged 는 호출자에서 명시 안 해도 자연스러운 값으로 채워진다.
    init(
        id: UUID = UUID(),
        name: String,
        color: String,
        note: String = "",
        createdAt: Date = Date(),
        isVisible: Bool = true,
        isSystemManaged: Bool = false
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.note = note
        self.createdAt = createdAt
        self.isVisible = isVisible
        self.isSystemManaged = isSystemManaged
    }
}

// 시드(첫 실행 시 기본 카테고리 생성) 정책 — CATEGORY_FEATURE.md 3번/4.2번.
// 모델과 같은 파일에 두는 이유: 시드 값이 모델의 의미와 직결되어 있고 양이 작아서.
extension EventCategory {
    // 3번 섹션이 정한 기본값 — 사용자가 바꿀 수 있으므로 "초기값"이라는 표현이 맞다.
    static let seedName = "기본"
    // 새 파스텔 팔레트의 sky(#A4C8E8) — 차분한 톤이라 첫 카테고리 색으로 무난.
    static let seedColor = "#A4C8E8"

    // 팔레트 교체 전 사용되던 10색의 hex. 이 hex들과 정확히 일치하는 카테고리만
    // 새 팔레트의 가장 가까운 색으로 자동 변경한다. 사용자 자유 색은 건드리지 않는다.
    static let legacyPaletteHexes: Set<String> = [
        "#C8483D", "#D67857", "#BFA13A", "#8C9B55", "#3F8C85",
        "#4A7DBE", "#5C5FA8", "#C46881", "#8A7E73", "#BFBFBF",
    ]

    // ModelContext 안의 카테고리가 비어 있으면 기본 카테고리 한 건을 삽입한다.
    // 4.2: 별도 firstLaunch 플래그 없음. 비어 있다는 사실 자체가 트리거(idempotent).
    static func seedIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<EventCategory>(sortBy: [SortDescriptor(\.createdAt)])
        let existing = (try? context.fetch(descriptor)) ?? []

        if existing.isEmpty {
            let seed = EventCategory(name: seedName, color: seedColor)
            context.insert(seed)
            // 시드 직후 즉시 디스크에 반영 — 다음 fetch가 일관되게 보이도록.
            try? context.save()
            print("[JDCalendar] seeded default category: \(seedName) \(seedColor)")
        } else {
            // 슬라이스 1 검증용 로그 — 슬라이스 2에서 사이드바가 실제로 목록을 보여주면 제거한다.
            let summary = existing.map { "\($0.name)/\($0.color)" }.joined(separator: ", ")
            print("[JDCalendar] existing categories(\(existing.count)): \(summary)")
        }
    }

    // 구 팔레트 hex와 정확히 일치하는 카테고리 색을 새 팔레트의 가장 가까운 색으로 변경.
    // - 자유 색 픽으로 만들어진 색(legacyPaletteHexes 외)은 손대지 않는다.
    // - 이미 새 팔레트 색이거나 자유 색인 경우 no-op (idempotent).
    static func migratePaletteIfNeeded(in context: ModelContext) {
        let descriptor = FetchDescriptor<EventCategory>()
        guard let existing = try? context.fetch(descriptor) else { return }

        var migrated = 0
        for cat in existing where legacyPaletteHexes.contains(cat.color.uppercased()) {
            let newHex = CategoryPalette.nearest(toHex: cat.color)
            print("[JDCalendar] migrate category color: \(cat.name) \(cat.color) → \(newHex)")
            cat.color = newHex
            migrated += 1
        }
        if migrated > 0 {
            try? context.save()
        }
    }
}
