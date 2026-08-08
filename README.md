# FlowScope

A focus timer that tracks *how you felt* while you worked, not just how long you
worked. Start a session, log your satisfaction as you go, and see the shape of
your focus over time.

Four platforms, one design: SwiftUI on iOS and macOS, Jetpack Compose on
Android, WinUI 3 on Windows 11.

| | |
| --- | --- |
| **[`FlowScope/`](FlowScope)** | iOS + macOS app — SwiftUI, SwiftData, WidgetKit, Live Activities |
| **[`FlowScopeAndroid/`](FlowScopeAndroid)** | Android app — Kotlin, Jetpack Compose, Room, Glance |
| **[`FlowScopeWindows/`](FlowScopeWindows)** | Windows 11 app — WinUI 3, .NET 8, Mica |

## What it does

- **Focus timer** with a themed progress ring that fills over one focus cycle,
  then resets and counts a lap.
- **Mood logging** — a satisfaction dial, a draggable floating slider that
  follows you across tabs, and one-tap logging from the home-screen widgets.
- **Work log & history** — every session with its mood trace, searchable and
  filterable, plus a calendar view.
- **Session summary** charting satisfaction over the length of a session.
- **Themes** — each with its own particle field, ring design, digit animation,
  typography and synthesised sound profile. Any theme can be recoloured
  (hue / saturation / brightness) without losing its identity.
- **Home-screen widgets** showing the live session, streak, mood trend, weekly
  totals, quick start and top categories — all themed to match the app.

### Theme sets currently differ per platform

The Apple and Windows apps ship the current nine-theme set: **Flame, Cyberpunk,
Lava, Neon 80s, Superman, Batman, Nightwing, Deathstroke, Red Hood**.

The Android app still ships the earlier ten: Flame, Lightning, Laser,
Cyberpunk, Aurora, Dark Matter, Lava, Neon 80s, Galaxy, Burning Ember. Bringing
Android onto the current set is outstanding work.

## The theme engine

Screens never branch on the theme. Every colour, font, shadow, corner radius,
ring shape, particle field and transition lives in a single `ThemeConfiguration`
— the app's set of "CSS variables" — and views just read from it. Adding a new
theme means adding one configuration, not touching any screen.

The particle backgrounds are drawn on a raw canvas on Apple and Android, using
additive blending so overlapping light accumulates and blows out to white,
multi-pass strokes (wide dim halo → mid glow → thin white hot core) so lines
read as *emitted light*, and gradient shading so nothing has a hard edge.

## Timing model

Elapsed time is derived from wall-clock, never counted up. Completed run
segments are banked on pause, and the current segment is measured from the
instant it began. The consequence: the timer cannot drift, and a session
survives the app being killed — relaunching recovers it rather than stranding a
session that only the widget can see. All four apps implement this same rule.

## iOS and macOS build

Open `FlowScope/FlowScope.xcodeproj` in Xcode and run — pick an iPhone
destination for iOS, or **My Mac** for the desktop app. You'll need to set your
own signing team.

The two share one target and one source tree. Platform differences are confined
to [`FlowScope/FlowScope/Extensions/PlatformCompat.swift`](FlowScope/FlowScope/Extensions/PlatformCompat.swift)
plus a handful of `#if os(iOS)` blocks:

- The Mac build uses a `NavigationSplitView` sidebar instead of the iOS tab
  bar, and adds a **Session** menu (⌘P pause/resume, ⌘. end).
- Live Activities, the widget extension and background-task assertions are
  iOS-only, so they compile out on macOS and the widget is not embedded there.
- Haptics map to the Force Touch trackpad; keeping the screen awake becomes a
  power-management activity instead of disabling the idle timer.

## Android build

```bash
cd FlowScopeAndroid && ./gradlew assembleDebug
```

Or grab the APK from the [latest release](../../releases/latest).

Requires Android Studio and JDK 17+. minSdk 26.

## Windows build

```bash
cd FlowScopeWindows && dotnet build FlowScopeWindows.sln -c Debug -p:Platform=x64
```

Requires the .NET 8 SDK and the Windows App SDK. See
[`FlowScopeWindows/README.md`](FlowScopeWindows/README.md) — including the note
that this port was written on a Mac and has **not been compiled yet**.

## Platform differences

The Android and Windows apps are rewrites, not conversions — SwiftUI,
SwiftData, WidgetKit and ActivityKit have no equivalents there. Where the
platforms genuinely diverge (Live Activities, widget chart rendering, rounded
system fonts, blur availability), the reasoning is documented in
[`FlowScopeAndroid/README.md`](FlowScopeAndroid/README.md) and
[`FlowScopeWindows/README.md`](FlowScopeWindows/README.md).
