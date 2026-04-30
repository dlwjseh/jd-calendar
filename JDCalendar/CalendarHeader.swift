import SwiftUI

// 달력 상단 헤더 — 왼쪽에 "YYYY년 M월", 오른쪽에 Today 버튼 + 이전/다음(‹ ›) 버튼.
struct CalendarHeader: View {
    let year: Int
    let month: Int
    // 버튼이 눌렸을 때 부모(ContentView)가 처리하도록 함수를 받아둔다 — 헤더 자신은 상태를 안 바꾼다.
    let onPrev: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void

    private let theme = CalendarTheme.light

    var body: some View {
        // 가로 한 줄에 [연·월 표기] + Spacer + [Today] + [‹ ›] 순으로 배치.
        HStack(alignment: .center, spacing: 16) {
            // firstTextBaseline: 크기가 다른 글자(24pt 숫자와 12pt 한글)를 같은 글자 밑선에 맞춘다.
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                // verbatim: 숫자에 천 단위 콤마(2,026)가 붙지 않게 그대로 출력하기 위함.
                Text(verbatim: "\(year)")
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(theme.fg)
                Text("년")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.fg.opacity(0.45))
                    .padding(.horizontal, 4)
                // month는 0~11 저장이므로 사람이 읽을 때는 +1.
                Text(verbatim: "\(month + 1)")
                    .font(.system(size: 24, weight: .semibold))
                    .tracking(-0.5)
                    .foregroundStyle(theme.fg)
                Text("월")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(theme.fg.opacity(0.45))
                    .padding(.leading, 4)
            }

            // Spacer: 좌측 그룹과 우측 버튼들을 양 끝으로 밀어낸다.
            Spacer(minLength: 0)

            TodayButton(action: onToday)

            // ‹ 와 › 를 거의 붙여서 한 쌍처럼 보이게.
            HStack(spacing: 2) {
                NavButton(symbol: "chevron.left", action: onPrev)
                NavButton(symbol: "chevron.right", action: onNext)
            }
        }
        // 헤더 영역의 안쪽 여백 — 위 20, 아래 16.
        // leading은 88로 늘려서 macOS 신호등(빨/노/초, 대략 x=20~82)이 차지하는 자리를 비워둔다.
        // 이렇게 해야 창을 줄여도 "YYYY년 M월"이 신호등에 가려지지 않는다.
        .padding(.leading, 88)
        .padding(.trailing, 32)
        .padding(.top, 20)
        .padding(.bottom, 16)
    }
}

// "Today" 버튼 — 누르면 onToday를 호출. 마우스 올리면 살짝 강조된다.
private struct TodayButton: View {
    let action: () -> Void
    // 마우스가 위에 있는지 추적 — true가 되면 배경색이 채워진다.
    @State private var hovered = false

    private let theme = CalendarTheme.light

    var body: some View {
        Button(action: action) {
            Text("Today")
                .font(.system(size: 12, weight: .medium))
                .tracking(0.2)
                .foregroundStyle(theme.fg.opacity(0.85))
                .padding(.horizontal, 12)
                .frame(height: 28)
                // 호버 시에만 안쪽이 채워지도록 분기.
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovered ? theme.line : .clear)
                )
                // overlay로 테두리를 그림 — 호버 여부와 관계없이 항상 표시.
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(theme.line, lineWidth: 1)
                )
        }
        // .plain: 기본 macOS 버튼 스타일(파란 배경 등)을 끄고 우리가 그린 모양만 사용.
        .buttonStyle(.plain)
        // onHover: 마우스가 들어오면 true, 나가면 false로 hovered 상태를 갱신.
        .onHover { hovered = $0 }
    }
}

// ‹ / › 화살표 한 짝을 만들기 위한 재사용 컴포넌트.
private struct NavButton: View {
    // SF Symbols 이름 — "chevron.left", "chevron.right" 같은 시스템 아이콘 키.
    let symbol: String
    let action: () -> Void
    @State private var hovered = false

    private let theme = CalendarTheme.light

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                // 호버 시 글자(아이콘) 색을 진하게 — 시각적 피드백.
                .foregroundStyle(theme.fg.opacity(hovered ? 1.0 : 0.55))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(hovered ? theme.line : .clear)
                )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }
}
