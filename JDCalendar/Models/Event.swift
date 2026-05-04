import Foundation
import SwiftData

// 이벤트 — 캘린더에 찍히는 한 건의 일정.
// EVENT_FEATURE.md §1 데이터 모델 그대로 구현.
//
// SwiftData가 영속화/관계/관찰을 모두 책임진다(§2 저장소).
// @Model은 클래스(참조 타입)에만 붙일 수 있다 — 변경 추적을 위해서.
@Model
final class Event {
    // 이벤트의 고유 식별자. UUID는 충돌 가능성이 사실상 없어 동기화/마이그레이션에 안전하다.
    // @Attribute(.unique)로 SwiftData에 "이 필드는 중복 불가"라고 알려준다.
    @Attribute(.unique) var id: UUID

    // 사용자에게 보여지는 제목. 빈 문자열·공백만 금지는 입력 단(에디터)에서 검증한다.
    // v1엔 길이 상한 두지 않음(§1.1).
    var title: String

    // 시작 시각. 종일이면 시작 날짜의 00:00으로 정규화해서 저장(§1.2).
    var startAt: Date

    // 종료 시각. 종일이면 마지막 날 + 1일의 00:00 (iCal 관행과 동일하게 배타적).
    // 시간지정이면 분 단위까지 의미 있게 저장 — 저장 직전에 초 이하는 0으로 정규화.
    var endAt: Date

    // 종일 여부. true면 시각 인풋이 숨겨지고 §1.2 정규화가 적용된다.
    var isAllDay: Bool

    // 사용자가 자유롭게 적는 메모. 옵셔널 의미를 빈 문자열로 표현(EventCategory.note와 동일 방식).
    var note: String

    // 생성 시각. v1에선 §4.5 정렬의 타이브레이커로만 사용된다(메타데이터 용도).
    var createdAt: Date

    // 이벤트가 속한 카테고리 — 정확히 1개, 비옵셔널(§1.1).
    // 색상은 카테고리에서 오므로 이벤트는 별도 색 필드를 두지 않는다.
    // inverse는 EventCategory 측의 events 컬렉션에서 deleteRule: .cascade로 선언한다(§1.4).
    var category: EventCategory

    // 기본 생성자 — 호출자에서 명시 안 해도 자연스러운 값으로 채워지는 것은 디폴트로.
    // category는 디폴트가 없으므로 호출자가 반드시 지정해야 한다.
    init(
        id: UUID = UUID(),
        title: String,
        startAt: Date,
        endAt: Date,
        isAllDay: Bool,
        note: String = "",
        createdAt: Date = Date(),
        category: EventCategory
    ) {
        self.id = id
        self.title = title
        self.startAt = startAt
        self.endAt = endAt
        self.isAllDay = isAllDay
        self.note = note
        self.createdAt = createdAt
        self.category = category
    }
}
