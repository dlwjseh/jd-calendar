# JD Calendar

A personal macOS/iMac calendar app written in SwiftUI. The visual design was
prototyped in Claude Design (HTML/CSS) and ported natively to SwiftUI.

## Collaboration rules

- **If anything is ambiguous, ask before implementing.** Do not guess scope or
  defaults — clarify first. (Explicit user preference.)
- Reply to the user in Korean. Code identifiers stay in English.
- Build the smallest useful version first ("가장 최소단위"), then grow. Do not
  pre-abstract or generalize ahead of need.

## Code style

- **Write comments in Korean.** The user is learning Swift, so favor readability
  over brevity. Add a short `//` line above each non-trivial view, modifier
  chain, helper, or state mutation explaining *what* it does and *why*. Skip
  comments only for one-liners that are obvious from the identifier name.
  This overrides the "default to no comments" rule for this project.
- **Componentize aggressively.** Each visible UI piece should be its own
  `struct ...: View` in its own file under the appropriate subfolder
  (`JDCalendar/<Group>/<Name>.swift`), so a future edit touches one file.
  Rules of thumb:
  - If a view body has more than ~30 lines, split it.
  - If the same modifier chain appears in two places, extract a `View` or
    `ViewModifier`.
  - Prefer many small `private struct`s in the same file over deeply nested
    `@ViewBuilder` blocks.
  - Keep design tokens (colors, sizes, paddings) in `CalendarTheme.swift`,
    never inlined in views.

## v1 locked options (do not unlock without explicit request)

The original design prototype exposes a Tweaks panel (theme / font / line /
weekend / chrome toggles). In v1 these are **fixed**, not configurable:

- Theme: light only (`CalendarTheme.light`)
- Font: system sans (`-apple-system`)
- Grid lines: thin (1px)
- Weekend emphasis: both Sun (red `#e0524a`) and Sat (blue `#3a7bd5`)
- Fake macOS chrome: off — only the real OS window chrome
- Cursor (current month) persistence: none — always opens on today's month

Do not reintroduce the Tweaks panel or make any of the above configurable
unless the user asks for it.

## Project layout

```
JDCalendar.xcodeproj/         # Xcode 16+ filesystem-synchronized group, objectVersion 77
JDCalendar/                   # synced folder — adding .swift files / subfolders needs no pbxproj edit
  JDCalendarApp.swift         # @main, WindowGroup (1100×720, min 720×680), modelContainer
  ContentView.swift           # top strip + sidebar/calendar split + cursor (year/month) state
  Theme/
    CalendarTheme.swift       # design tokens (light only) + CategoryPalette + Color(hex:)
  Models/                     # SwiftData @Model classes
    EventCategory.swift       # category entity + seed-if-needed
    Event.swift               # event entity (one category required, iCal-style endAt)
  Calendar/                   # 월 그리드 표시
    CalendarHeader.swift      # "YYYY년 M월" + Today + ‹ ›
    WeekdayRow.swift          # 일/월/화/수/목/금/토 (Korean weekday labels)
    CalendarGrid.swift        # 6×7 LazyVGrid + buildMonthGrid()
    DayCell.swift             # one cell + DayCellModel
  Categories/                 # 카테고리 사이드바
    CategorySidebar.swift     # sidebar container (220pt) + AddCategoryButton
    CategoryRow.swift         # 색 점 체크박스 + 이름 + 우클릭 메뉴
    CategoryEditor.swift      # 신규/편집 시트
    SidebarToggleButton.swift # 좌상단 펼침/접힘 버튼
  Events/                     # (예정) 이벤트 시트·셀 표시 컴포넌트가 여기로
  Assets.xcassets/            # AppIcon, AccentColor placeholders
```

- Bundle id: `com.jd.JDCalendar`
- Minimum macOS deployment target: 14.0
- Swift 5.0 language mode, Swift 6 toolchain

## Build / run

- Primary: open `JDCalendar.xcodeproj` in Xcode → `Cmd+R`.
- Quick syntax check from CLI:
  `swiftc -typecheck -sdk "$(xcrun --show-sdk-path --sdk macosx)" $(find JDCalendar -name "*.swift")`
- If `xcodebuild` fails to load `IDESimulatorFoundation`, run
  `xcodebuild -runFirstLaunch` once. This is an Xcode 26.4.1 install issue,
  unrelated to the project.

## Design source

- Handoff bundle URL:
  `https://api.anthropic.com/v1/design/h/TnTXVTtJylMGZuW2EbD86w`
- Temporary extraction path: `/tmp/jd-design/extracted/jd-calendar/`
  (cleared on reboot — re-fetch from the URL above if needed).
- Key reference files: `project/JD Calendar.html`, `project/calendar.jsx`.
