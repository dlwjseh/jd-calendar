import Foundation
import SwiftData

// 한국 공휴일을 SwiftData 의 Event 로 영구 저장하고, 일별 1회 갱신을 책임지는 서비스.
//
// 정책 (v1):
//   - 시스템 카테고리 "공휴일" (isSystemManaged = true) 자동 생성/유지.
//   - 현재 연도 ±1 (총 3년) 분의 공휴일을 launch 시 한 번 fetch & 영구저장.
//   - 마지막 sync 가 오늘이면 skip — 같은 날 여러 번 켜도 API 호출 한 번.
//   - 각 연도마다 "그 연도의 휴일 이벤트만 통째 교체" 전략 → idempotent.
//
// SwiftData ModelContext 는 main actor 에서만 다루는 게 안전하므로 enum 자체를 @MainActor 로 묶는다.
// network 호출(URLSession) 은 nonisolated 라 await 시 자동으로 actor 이탈 후 복귀한다.
@MainActor
enum HolidaySyncService {

    // 시스템 카테고리 식별 정보.
    static let systemCategoryName = "공휴일"
    // 일요일 강조색(#E0524A) 과 동일 — v1 weekend Sun 톤과 의미적 일관성.
    static let systemCategoryColor = "#E0524A"

    // UserDefaults 키 — 마지막으로 sync 가 성공적으로 끝난 일자.
    private static let lastSyncDateKey = "JDCalendar.HolidaySync.lastSyncDate"

    // 이번 앱 세션 동안 on-demand fetch 가 끝난 연도. 앱 재실행 시 초기화.
    // 일별 sync 가 커버하는 현재 ±1 범위는 별도라 여기엔 안 들어간다.
    private static var sessionFetchedYears: Set<Int> = []
    // 현재 fetch 중인 연도. 같은 연도에 대한 중복 trigger 를 막기 위함.
    // @MainActor 라 동기 부분(검사 + 삽입)은 직렬화되므로 lock 없이 안전.
    private static var inFlightYears: Set<Int> = []

    // 일별 1회 동기화 진입점.
    // 마지막 sync 가 오늘(local day)이 아니면 sync() 를 호출.
    static func syncIfNeeded(in context: ModelContext) async {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        if let last = UserDefaults.standard.object(forKey: lastSyncDateKey) as? Date,
           calendar.isDate(last, inSameDayAs: today) {
            // 오늘 이미 sync 함 → 네트워크 호출 생략.
            return
        }
        await sync(in: context)
        // 일부 연도가 실패해도 마지막 시도 일자는 갱신 — 같은 날 무한 재시도 방지.
        // 다음 날 다시 시도되므로 손실은 없다.
        UserDefaults.standard.set(today, forKey: lastSyncDateKey)
    }

    // 실제 동기화 — 시스템 카테고리 보장 + 현재 ±1년 데이터 fetch 후 교체.
    static func sync(in context: ModelContext) async {
        let category = ensureSystemCategory(in: context)

        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        let years = Array((currentYear - 1)...(currentYear + 1))

        for year in years {
            do {
                let holidays = try await KASIClient.fetchHolidays(year: year)
                replace(year: year, with: holidays, category: category, in: context)
                print("[HolidaySync] \(year): \(holidays.count) 건 동기화 완료")
            } catch {
                // 한 해가 실패해도 나머지 연도는 진행. 다음 launch 의 daily check 에서 재시도된다.
                print("[HolidaySync] \(year) 실패: \(error)")
            }
        }

        try? context.save()
    }

    // cursor 의 (year, month) 가 가리키는 그리드가 실제로 보여주는 연도들을 모두 ensure.
    // - 일반 달: [year] 만
    // - 1월: [year, year - 1]  ← 전 달 spillover (예: 2030년 1월 화면에 2029년 12월 며칠이 보임)
    // - 12월: [year, year + 1] ← 다음 달 spillover
    static func ensureYearsForCursor(year: Int, month: Int, in context: ModelContext) async {
        var years = [year]
        if month == 0 {
            years.append(year - 1)
        } else if month == 11 {
            years.append(year + 1)
        }
        for y in years {
            await ensureYearAvailable(y, in: context)
        }
    }

    // 사용자가 cursor 를 ±1년 범위 밖 연도로 옮길 때마다 호출.
    // 그 연도의 공휴일을 이번 세션 처음 보는 거면 fetch & 영구 저장. 두 번째부터는 즉시 반환.
    // ±1년 범위 안이면 daily sync 가 책임지므로 여기선 no-op.
    static func ensureYearAvailable(_ year: Int, in context: ModelContext) async {
        // daily sync 가 커버하는 범위.
        let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
        if abs(year - currentYear) <= 1 {
            return
        }
        // 이번 세션에서 이미 fetch 했거나 fetch 중이면 skip.
        if sessionFetchedYears.contains(year) || inFlightYears.contains(year) {
            return
        }

        // in-flight 표시 — 같은 연도에 대한 동시 trigger 를 막는다.
        inFlightYears.insert(year)
        defer { inFlightYears.remove(year) }

        let category = ensureSystemCategory(in: context)
        do {
            let holidays = try await KASIClient.fetchHolidays(year: year)
            replace(year: year, with: holidays, category: category, in: context)
            try? context.save()
            sessionFetchedYears.insert(year)
            print("[HolidaySync] \(year) (on-demand): \(holidays.count) 건")
        } catch {
            // 실패 시 sessionFetchedYears 에 안 넣음 → 같은 세션 내 재시도 가능.
            print("[HolidaySync] \(year) (on-demand) 실패: \(error)")
        }
    }

    // "공휴일" 시스템 카테고리를 보장 — 없으면 생성, 있으면 그대로 반환.
    // isSystemManaged 플래그로 식별 — 이름이나 색이 사용자에 의해 변경되더라도(현재는 막혀 있지만 미래에)
    // 같은 카테고리로 인식 가능.
    private static func ensureSystemCategory(in context: ModelContext) -> EventCategory {
        let descriptor = FetchDescriptor<EventCategory>(
            predicate: #Predicate { $0.isSystemManaged == true }
        )
        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let cat = EventCategory(
            name: systemCategoryName,
            color: systemCategoryColor,
            isSystemManaged: true
        )
        context.insert(cat)
        // 즉시 저장 — 이후 fetch / replace 가 같은 객체를 안전하게 참조하도록.
        try? context.save()
        print("[HolidaySync] seeded system category: \(systemCategoryName) \(systemCategoryColor)")
        return cat
    }

    // 한 해의 공휴일 이벤트만 통째 교체.
    // 같은 카테고리에 속하는 이벤트 중 startAt 이 그 해 안에 있는 것들을 모두 삭제 후 재삽입.
    // category.events 관계를 직접 순회 — SwiftData 가 inverse 로 자동 관리.
    private static func replace(
        year: Int,
        with holidays: [KASIHoliday],
        category: EventCategory,
        in context: ModelContext
    ) {
        let calendar = Calendar(identifier: .gregorian)
        guard let yearStart = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let yearEnd = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else {
            return
        }

        // 해당 연도 범위의 기존 이벤트 제거.
        let toDelete = category.events.filter { event in
            event.startAt >= yearStart && event.startAt < yearEnd
        }
        for event in toDelete {
            context.delete(event)
        }

        // 새 이벤트 삽입 — 종일 이벤트의 endAt 은 다음 날 00:00 (iCal 관행, Event.swift §1.2).
        for holiday in holidays {
            guard let endAt = calendar.date(byAdding: .day, value: 1, to: holiday.date) else { continue }
            let event = Event(
                title: holiday.dateName,
                startAt: holiday.date,
                endAt: endAt,
                isAllDay: true,
                category: category
            )
            context.insert(event)
        }
    }
}
