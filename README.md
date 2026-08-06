# FlowScope

A focus timer that tracks *how you felt* while you worked, not just how long you
worked. Start a session, log your satisfaction as you go, and see the shape of
your focus over time.

Two native apps, one design: SwiftUI on iOS, Jetpack Compose on Android.

| | |
| --- | --- |
| **[`FlowScope/`](FlowScope)** | iOS app — SwiftUI, SwiftData, WidgetKit, Live Activities |
| **[`FlowScopeAndroid/`](FlowScopeAndroid)** | Android app — Kotlin, Jetpack Compose, Room, Glance |

## What it does

- **Focus timer** with a themed progress ring that fills over one focus cycle,
  then resets and counts a lap.
- **Mood logging** — a satisfaction dial, a draggable floating slider that
  follows you across tabs, and one-tap logging from the home-screen widgets.
- **Work log & history** — every session with its mood trace, searchable and
  filterable, plus a calendar view.
- **Session summary** charting satisfaction over the length of a session.
- **Ten themes** — Flame, Lightning, Laser, Cyberpunk, Aurora, Dark Matter,
  Lava, Neon 80s, Galaxy and Burning Ember — each with its own particle field,
  ring design, digit animation, typography and synthesised sound profile. Any
  theme can be recoloured (hue / saturation / brightness) without losing its
  identity.
- **Home-screen widgets** showing the live session, streak, mood trend, weekly
  totals, quick start and top categories — all themed to match the app.

## The theme engine

Screens never branch on the theme. Every colour, font, shadow, corner radius,
ring shape, particle field and transition lives in a single `ThemeConfiguration`
— the app's set of "CSS variables" — and views just read from it. Adding an
eleventh theme means adding one configuration, not touching any screen.

The particle backgrounds are drawn on a raw canvas on both platforms, using
additive blending so overlapping light accumulates and blows out to white,
multi-pass strokes (wide dim halo → mid glow → thin white hot core) so lines
read as *emitted light*, and gradient shading so nothing has a hard edge.

## Timing model

Elapsed time is derived from wall-clock, never counted up. Completed run
segments are banked on pause, and the current segment is measured from the
instant it began. The consequence: the timer cannot drift, and a session
survives the app being killed — relaunching recovers it rather than stranding a
session that only the widget can see.

## Android build

```bash
cd FlowScopeAndroid && ./gradlew assembleDebug
```

Or grab the APK from the [latest release](../../releases/latest).

Requires Android Studio and JDK 17+. minSdk 26.

## iOS build

Open `FlowScope/FlowScope.xcodeproj` in Xcode and run. You'll need to set your
own signing team.

## Platform differences

The Android app is a rewrite, not a conversion — SwiftUI, SwiftData, WidgetKit
and ActivityKit have no Android equivalents. Where the platforms genuinely
diverge (Live Activities, widget chart rendering, rounded system fonts, blur
availability), the reasoning is documented in
[`FlowScopeAndroid/README.md`](FlowScopeAndroid/README.md).
