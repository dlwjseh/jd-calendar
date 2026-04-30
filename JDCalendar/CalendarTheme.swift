import SwiftUI

// 디자인 토큰(색상 팔레트)을 한 곳에 모아두는 구조체.
// 뷰 안에 색상 값을 직접 박지 않고 여기를 통해서만 쓰면, 나중에 색을 바꿀 때 한 파일만 수정하면 된다.
struct CalendarTheme {
    let bg: Color          // 달력 본문 배경색 (거의 흰색에 가까운 미색)
    let fg: Color          // 본문 글자 기본 색 (거의 검정)
    let muted: Color       // 흐리게 표시할 글자 (이전/다음 달의 날짜 등)
    let line: Color        // 셀 사이의 가는 격자선
    let sun: Color         // 일요일/일요일 칼럼 색 (붉은 톤)
    let sat: Color         // 토요일/토요일 칼럼 색 (푸른 톤)
    let today: Color       // 오늘 날짜의 배경 캡슐 색
    let todayInk: Color    // 오늘 날짜의 글자 색 (배경이 진하므로 흰색)
    let headerInk: Color   // 요일 헤더(일~토)에서 평일에 쓰는 흐린 글자 색

    // 라이트 테마 프리셋 — v1에서는 이것 하나만 사용한다.
    // Color(red:green:blue:)는 0.0~1.0 범위라서 16진수(0x1a 등)를 255로 나눠 변환했다.
    static let light = CalendarTheme(
        bg: Color(red: 0xfd / 255, green: 0xfc / 255, blue: 0xfa / 255),
        fg: Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255),
        // 같은 진한 색을 32% 투명도로 → 흐린 회색 느낌. 별도 회색 토큰을 만들지 않아도 톤이 맞는다.
        muted: Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255).opacity(0.32),
        // 격자선은 검정의 8% 투명 — 배경에 자연스럽게 묻히면서도 1px 선이 보일 정도.
        line: Color.black.opacity(0.08),
        sun: Color(red: 0xe0 / 255, green: 0x52 / 255, blue: 0x4a / 255),
        sat: Color(red: 0x3a / 255, green: 0x7b / 255, blue: 0xd5 / 255),
        today: Color(red: 0xe0 / 255, green: 0x52 / 255, blue: 0x4a / 255),
        todayInk: .white,
        headerInk: Color(red: 0x1a / 255, green: 0x1a / 255, blue: 0x1a / 255).opacity(0.55)
    )
}
