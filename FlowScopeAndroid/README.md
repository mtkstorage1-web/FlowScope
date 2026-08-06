# FlowScope for Android

A native Android rewrite of the FlowScope iOS app, built with Kotlin and Jetpack
Compose. The iOS project at `../FlowScope` is untouched — this is a parallel
codebase, not a conversion.

## Why a rewrite and not a conversion

The iOS app is 37 Swift files built entirely on Apple-only frameworks: SwiftUI,
SwiftData, WidgetKit, ActivityKit, AppIntents, Swift Charts and AVAudioEngine.
None of them exist on Android, and Android Studio compiles Kotlin/Java rather
than Swift. There is no tool that converts one into the other, so every file
here was written against the Swift source as its specification.

## Open it

```bash
open -a "Android Studio" /Users/kngightzzy/Desktop/FlowScope/FlowScopeAndroid
```

Let Gradle sync, then press Run. To build an APK from the terminal:

```bash
cd /Users/kngightzzy/Desktop/FlowScope/FlowScopeAndroid && ./gradlew assembleDebug
```

The APK lands in `app/build/outputs/apk/debug/app-debug.apk`.

For a release build you'll need to add a signing config to `app/build.gradle.kts`
first — minification is deliberately off so the release build behaves exactly
like the debug one until you set that up.

## How the pieces map

| iOS | Android |
| --- | --- |
| `ThemeEngine.swift` / `ThemeProvider` | `theme/ThemeModels.kt`, `theme/ThemeProvider.kt` |
| `ThemeParticles.swift` (Canvas) | `theme/ThemeParticles.kt` (Compose Canvas) |
| `View+Theme.swift` | `ui/components/ThemedComponents.kt` |
| `ThemeCustomization.swift` | `theme/ThemeCustomization.kt` |
| `AppSettings.swift` (`@AppStorage`) | `theme/AppSettings.kt` (SharedPreferences + Compose state) |
| `Session.swift` (SwiftData `@Model`) | `data/Entities.kt` (Room) |
| `DataManager.swift` | `data/SessionRepository.kt` |
| `SessionManager.swift` | `session/SessionManager.kt` (ViewModel) |
| Live Activity (ActivityKit) | `session/SessionService.kt` (foreground service) |
| App Group `UserDefaults` | `data/SharedState.kt` (SharedPreferences) |
| `SoundManager.swift` (AVAudioEngine) | `audio/SoundManager.kt` (AudioTrack) |
| `HapticManager.swift` | `util/Haptics.kt` (Vibrator) |
| WidgetKit widgets | `widget/` (Glance) |
| Swift Charts | Hand-drawn Compose Canvas chart |
| `TimerView`, `WorkLogView`, `CalenderView`, `SettingsView` | `ui/timer`, `ui/worklog`, `ui/calendar`, `ui/settings` |

The timing model is preserved exactly: elapsed time is derived from wall-clock
rather than counted up, banked into `accumulated` on pause, so it cannot drift
and survives process death.

## Where Android differs, and why

These are platform limits, not shortcuts:

- **No Live Activity / Dynamic Island.** Android has no equivalent surface. A
  foreground service with an ongoing notification does the same two jobs —
  keeping the session alive in the background and showing it at a glance — and
  carries the same three quick-log buttons (20 / 60 / 95). It uses a chronometer
  anchored to the session's wall-clock start, so the system ticks it without the
  app pushing per-second updates.
- **Widget charts are bars, not lines.** Glance renders through RemoteViews,
  which cannot draw arbitrary paths. The mood sparkline and weekly chart are
  composed from laid-out rectangles. The in-app chart, which runs on a real
  Compose Canvas, is a smooth curve exactly as on iOS.
- **No lock-screen / accessory widget families.** Android's widget system has no
  counterpart to `.accessoryCircular` / `.accessoryRectangular` / `.accessoryInline`,
  so each widget ships its home-screen layout only.
- **No SF Rounded.** Aurora and Galaxy specify a rounded font design; Android's
  system font has no rounded variant, so those fall back to the system sans. Their
  weight, corner radius, palette and motion still carry the theme's character. Drop
  a rounded font into `res/font/` and point `FontDesign.Rounded` at it if you want
  an exact match.
- **Glow is drawn, not a shadow.** Compose can't attach a coloured drop shadow to
  an arbitrary drawn arc, so ring and button glows are built the same way the
  particle field builds its bloom: wider, dimmer passes underneath. Digit glows
  are offset blurred copies, which also preserves Cyberpunk's chromatic aberration.
- **Blur needs API 31+.** Compose's blur modifier is a no-op below that, so on
  older devices the background renders sharp and the soft digit glow drops out.
  Cyberpunk's hard-offset chromatic aberration, and every other themed element,
  are unaffected.
- **Named colours were re-pinned.** The Swift themes lean on SwiftUI's `.red`,
  `.cyan` and friends, which differ noticeably from Android's defaults. `IOSColors`
  in `util/ColorUtil.kt` mirrors the iOS dark-mode system palette so each theme
  keeps its intended look.

## Build setup notes

- AGP 9 ships built-in Kotlin support, so the standalone `org.jetbrains.kotlin.android`
  plugin must **not** be applied — doing so fails with a duplicate `kotlin`
  extension.
- KSP (Room's processor) registers its generated sources through the
  `kotlin.sourceSets` DSL, which AGP 9 rejects by default. `android.disallowKotlinSourceSets=false`
  in `gradle.properties` allows it.
- `compileSdk`/`targetSdk` are 37, matching the only platform installed locally.
  minSdk is 26.
