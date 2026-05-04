import SwiftUI
import AppKit

// 디자인 토큰(색상 팔레트)을 한 곳에 모아두는 구조체.
// 뷰 안에 색상 값을 직접 박지 않고 여기를 통해서만 쓰면, 나중에 색을 바꿀 때 한 파일만 수정하면 된다.
struct CalendarTheme {
    let bg: Color          // 달력 본문 배경색 (거의 흰색에 가까운 미색)
    let sidebarBg: Color   // 좌측 사이드바 배경색 (본문보다 살짝 진한 베이지)
    let fg: Color          // 본문 글자 기본 색 (거의 검정)
    let muted: Color       // 흐리게 표시할 글자 (이전/다음 달의 날짜 등)
    let line: Color        // 셀 사이의 가는 격자선
    let sun: Color         // 일요일/일요일 칼럼 색 (붉은 톤)
    let sat: Color         // 토요일/토요일 칼럼 색 (푸른 톤)
    let today: Color       // 오늘 날짜의 배경 캡슐 색
    let todayInk: Color    // 오늘 날짜의 글자 색 (배경이 진하므로 흰색)
    let headerInk: Color   // 요일 헤더(일~토)에서 평일에 쓰는 흐린 글자 색
    let hover: Color       // 셀 마우스 호버 시 옅은 그레이 틴트(중성 — 강조색 아님)

    // 라이트 테마 프리셋 — v1에서는 이것 하나만 사용한다.
    // Color(red:green:blue:)는 0.0~1.0 범위라서 16진수(0x1a 등)를 255로 나눠 변환했다.
    static let light = CalendarTheme(
        bg: Color(red: 0xfd / 255, green: 0xfc / 255, blue: 0xfa / 255),
        // sidebarBg: 본문보다 살짝 어두운 중성 그레이 — 베이지/웜 톤 제거. (#FDFCFA → #F2F2F2)
        sidebarBg: Color(red: 0xf2 / 255, green: 0xf2 / 255, blue: 0xf2 / 255),
        fg: Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255),
        // 같은 진한 색을 32% 투명도로 → 흐린 회색 느낌. 별도 회색 토큰을 만들지 않아도 톤이 맞는다.
        muted: Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255).opacity(0.32),
        // 격자선은 검정의 8% 투명 — 배경에 자연스럽게 묻히면서도 1px 선이 보일 정도.
        line: Color.black.opacity(0.08),
        sun: Color(red: 0xe0 / 255, green: 0x52 / 255, blue: 0x4a / 255),
        sat: Color(red: 0x3a / 255, green: 0x7b / 255, blue: 0xd5 / 255),
        today: Color(red: 0xe0 / 255, green: 0x52 / 255, blue: 0x4a / 255),
        todayInk: .white,
        headerInk: Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255).opacity(0.55),
        // 검정 4% — 격자선(8%)보다 옅게 잡아 호버 박스가 격자선보다 도드라지지 않게.
        hover: Color.black.opacity(0.04)
    )
}

// 카테고리 색상 팔레트 — 파스텔 12색.
// 사용자에게 노출되는 라벨은 색 자체이므로 key는 코드 식별/디버깅 용도.
struct CategoryPalette {
    // 팔레트 한 칸의 정보 — 표시 순서(index), 코드 키, hex 문자열만 들고 있는다.
    struct Swatch {
        let index: Int
        let key: String
        let hex: String
    }

    // 4 cols × 3 rows로 표시되는 12색. 따뜻한 색(노랑→주황→핑크) → 핑크/보라 → 차가운 색(블루→그린) 순.
    static let all: [Swatch] = [
        Swatch(index: 1,  key: "butter",   hex: "#F6C67A"),
        Swatch(index: 2,  key: "apricot",  hex: "#F0A274"),
        Swatch(index: 3,  key: "salmon",   hex: "#F09372"),
        Swatch(index: 4,  key: "coral",    hex: "#EF888C"),
        Swatch(index: 5,  key: "blush",    hex: "#ED9FB9"),
        Swatch(index: 6,  key: "magenta",  hex: "#DF85A8"),
        Swatch(index: 7,  key: "orchid",   hex: "#DE9FD6"),
        Swatch(index: 8,  key: "lavender", hex: "#A3AFE1"),
        Swatch(index: 9,  key: "sky",      hex: "#A4C8E8"),
        Swatch(index: 10, key: "aqua",     hex: "#9BD8DD"),
        Swatch(index: 11, key: "mint",     hex: "#81C8BA"),
        Swatch(index: 12, key: "lime",     hex: "#BEDA83"),
    ]

    // 주어진 hex와 RGB 거리(유클리드) 가장 가까운 팔레트 색의 hex를 반환.
    // 팔레트 교체 시 기존 색을 새 팔레트로 매핑하기 위해 사용.
    static func nearest(toHex hex: String) -> String {
        let target = parseRGB(hex)
        var bestHex = all[0].hex
        var bestDist = Double.infinity
        for swatch in all {
            let rgb = parseRGB(swatch.hex)
            let dr = Double(rgb.r - target.r)
            let dg = Double(rgb.g - target.g)
            let db = Double(rgb.b - target.b)
            let dist = dr*dr + dg*dg + db*db
            if dist < bestDist {
                bestDist = dist
                bestHex = swatch.hex
            }
        }
        return bestHex
    }

    // hex → (r,g,b). 형식이 깨지면 (0,0,0) — 호출 측이 정상 hex만 넘긴다고 가정.
    private static func parseRGB(_ hex: String) -> (r: Int, g: Int, b: Int) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        return (
            Int((rgb & 0xFF0000) >> 16),
            Int((rgb & 0x00FF00) >> 8),
            Int(rgb & 0x0000FF)
        )
    }
}

// 카테고리 색상은 hex 문자열로 저장되므로(자유 색까지 받기 위함, 1번 참조) 매번 Color로 바꿔주는 헬퍼.
// 잘못된 형식이면 검정색으로 폴백 — 저장 단계에서 검증할 거라 호출자에서 따로 처리하지 않는다.
extension Color {
    init(hex: String) {
        // "#" 접두사 허용/생략 모두 받아서 6자리 16진수만 파싱.
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        self.init(red: r, green: g, blue: b)
    }

    // Color → "#RRGGBB" 변환. 자유 색 픽(SwiftUI ColorPicker)에서 받은 Color를 모델 저장용 hex로 바꿀 때 사용.
    // NSColor를 거쳐 sRGB 컴포넌트를 추출해 16진수로 포매팅한다.
    func toHexString() -> String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? NSColor.black
        let r = Int(round(nsColor.redComponent * 255))
        let g = Int(round(nsColor.greenComponent * 255))
        let b = Int(round(nsColor.blueComponent * 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    // 주어진 hex 색을 배경으로 썼을 때 가독성이 좋은 텍스트 색(흰색 또는 검정).
    // EVENT_FEATURE.md §4.1 — 종일 이벤트의 색 배경 박스 위 글자 색을 자동으로 정한다.
    // 가중 휘도(perceptual luminance) 임계값 0.6 — 팔레트의 lightGray(#BFBFBF, 휘도≈0.75)는 검정,
    // 나머지 채도 있는 색들은 휘도 0.6 미만이라 흰색이 된다.
    static func contrastingText(forHex hex: String) -> Color {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        let r = Double((rgb & 0xFF0000) >> 16) / 255
        let g = Double((rgb & 0x00FF00) >> 8) / 255
        let b = Double(rgb & 0x0000FF) / 255
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.6 ? .black : .white
    }
}
