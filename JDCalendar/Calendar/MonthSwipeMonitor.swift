import SwiftUI
import AppKit

// 트랙패드/휠 가로 스와이프를 잡아 월 이동 callback을 호출하는 ObservableObject.
// EVENT_FEATURE.md §6.2 — 좌→우 = 이전, 우→좌 = 다음. 임계 누적 후 한 번만 발화 + cooldown.
//
// NSEvent.localMonitor로 윈도우 전체 scrollWheel을 가로챈다 — NSView 기반 background는
// SwiftUI hit-test와 충돌해 안정성이 떨어지기 때문.
@MainActor
final class MonthSwipeMonitor: ObservableObject {
    // ContentView가 prev/next 함수를 여기에 꽂아넣는다 — onAppear에서 wiring.
    var onPrev: (() -> Void)?
    var onNext: (() -> Void)?

    // NSEvent.removeMonitor에 넘길 토큰.
    private var monitor: Any?
    // 가로 스크롤 누적량.
    private var accumulated: CGFloat = 0
    // 마지막 발화 시각 — cooldown 체크용.
    private var lastFire: Date = .distantPast

    // 발화 임계값 — 트랙패드 가벼운 스와이프로도 닿는 정도.
    private static let threshold: CGFloat = 60
    // 발화 후 잠금 — 한 제스처에 한 달만 이동.
    private static let cooldown: TimeInterval = 0.4

    func start() {
        // 중복 등록 방지.
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handle(event)
            // event를 그대로 return하면 다른 view도 받을 수 있게 통과.
            return event
        }
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
        monitor = nil
    }

    private func handle(_ event: NSEvent) {
        // 세로 스크롤이 더 크면 무시 (§6.2 "세로 스크롤은 별도 동작 없음").
        if abs(event.scrollingDeltaX) <= abs(event.scrollingDeltaY) { return }

        // 트랙패드 제스처 시작 시 누적 reset (마우스 휠은 phase .none이라 패스).
        if event.phase == .began {
            accumulated = 0
        }
        accumulated += event.scrollingDeltaX

        let now = Date()
        guard now.timeIntervalSince(lastFire) >= Self.cooldown else { return }

        if accumulated >= Self.threshold {
            // 좌→우 (콘텐츠가 오른쪽으로 밀림) → 이전 달.
            onPrev?()
            lastFire = now
            accumulated = 0
        } else if accumulated <= -Self.threshold {
            // 우→좌 → 다음 달.
            onNext?()
            lastFire = now
            accumulated = 0
        }
    }

    deinit {
        // monitor cleanup — 인스턴스가 사라질 때 (실제론 ContentView lifetime이라 거의 영구).
        if let m = monitor {
            NSEvent.removeMonitor(m)
        }
    }
}
