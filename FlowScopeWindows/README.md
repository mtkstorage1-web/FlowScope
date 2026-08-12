# FlowScope for Windows 11

A native WinUI 3 / .NET 8 build of FlowScope — the focus timer that tracks how
the work *felt*, not just how long it ran.

This is the third native port, alongside the SwiftUI app (iOS + macOS) in
`../FlowScope` and the Jetpack Compose app in `../FlowScopeAndroid`. The data
model, the nine themes and the session rules are ported value-for-value, so the
three apps behave the same way and their exports read the same.

## Status

> **Not yet compiled.** This port was written on a Mac, where neither the
> Windows App SDK nor the WinUI XAML compiler can run. The code is complete and
> self-consistent, but it has never been through `dotnet build`. Expect to fix a
> handful of compile errors on first run — most likely around XAML `x:Bind`
> types and the `AudioGraph` synthesiser in `Services/SoundService.cs`.
>
> Everything else in this repo (iOS, macOS, Android) has been built and run.

## Requirements

- Windows 11 (or Windows 10 1809+)
- .NET 8 SDK
- Visual Studio 2022 17.10+ with the **Windows App SDK C# templates**
  workload, or the `Microsoft.WindowsAppSDK` NuGet package restored from CLI
- Windows App Runtime 1.6 installed (the app is configured **unpackaged**, so
  it needs the runtime present rather than bundling it)

## Running it

```bash
dotnet restore FlowScopeWindows.sln
dotnet build FlowScopeWindows.sln -c Debug -p:Platform=x64
```

Then either press F5 in Visual Studio, or:

```bash
dotnet run --project FlowScopeWindows/FlowScopeWindows.csproj -p:Platform=x64
```

To ship it through the Store instead, set `<WindowsPackageType>MSIX</WindowsPackageType>`
in the csproj and add a `Package.appxmanifest`.

## How it is put together

| Area | File | Notes |
| --- | --- | --- |
| Session rules | `Services/SessionManager.cs` | Elapsed time is always derived from wall-clock stamps, never counted by the tick handler, so sleep/resume and clock changes can't make it drift. Mirrors `SessionManager.swift`. |
| Recovery | `Services/SessionManager.cs` | A snapshot of the in-flight session is written every second, so closing the window mid-session doesn't discard the focus time. |
| Storage | `Data/SessionStore.cs` | Sessions live in a single `sessions.json` in local app data, written via a temp-file swap. JSON rather than SQLite keeps the app free of native dependencies so an unpackaged run just works. |
| Themes | `Theme/ThemeProvider.cs` | All nine palettes, hexes copied from `ThemeEngine.swift`. |
| Theme plumbing | `Theme/ThemeManager.cs` | Publishes the palette into `Application.Resources`, so pages bind `{ThemeResource FlowScope*Brush}` and restyle together. |
| Keep awake | `Services/KeepAwake.cs` | `SetThreadExecutionState`, the Windows analogue of `isIdleTimerDisabled`. |
| Sound | `Services/SoundService.cs` | Synthesises the cues with `AudioGraph` rather than shipping audio files, the same approach `SoundManager.swift` takes with `AVAudioEngine`. Degrades to silence if audio is unavailable. |
| Shell | `MainWindow.xaml` | Mica backdrop, extended title bar, `NavigationView` sidebar — the Windows 11 counterpart to the Mac sidebar. |

## Known gaps against the Apple build

These are deliberate, not oversights:

- **Background art is a simplified, retained-tree approximation, not the
  immediate-mode Canvas art.** `Controls/ParticleField.cs` now drives real
  per-frame motion (`CompositionTarget.Rendering`) with a distinct pool/motion
  pattern per `ParticleStyle` (drifting embers, pulsing cracks, drifting
  speckle, a scrolling retro grid, a flickering scanline band) instead of the
  one-shot static geometry the port originally shipped with. It still isn't
  the bespoke shader-like Canvas rendering `ThemeParticles.swift` does on
  Apple — fewer particles, simpler per-particle math — but it now actually
  moves and differs by theme.
- **Theme emblems exist and are used in two places.** `Theme/ThemeEmblems.cs`
  is a complete, hand-ported vector emblem system (Superman, Batman,
  Nightwing, Deathstroke, Red Hood) with an animated edge-light while a
  session runs. It's used in the timer ring (`TimerPage`) and now also in the
  Appearance theme picker (`AppearancePage.BuildThemeGrid()`), layered over
  the gradient swatch for the five character themes. It deliberately skips
  the Apple build's struck-metal wear texture (mottling/scratches) — cheap on
  an immediate-mode Canvas, expensive in XAML's retained tree.
- **Theme customization exists.** `Theme/ThemeCustomization.cs` ports
  `ThemeCustomization.swift`'s hue/saturation/brightness delta + explicit hex
  overrides for Primary/Secondary/Background, exposed via sliders and hex
  fields on the Appearance page. Each theme remembers its own adjustment
  (`ThemeCustomizationStore`, keyed by theme id) the same way the base theme
  choice already persists.
- **No widgets or Live Activities.** There is no Windows counterpart to the
  Home Screen widget or the Dynamic Island. Windows widgets would be a
  separate host app.
- **Not yet run through a compiler.** The additions above were written and
  reviewed on a Mac against the Windows App SDK 1.6 API surface from
  documentation, the same constraint the rest of this port was written under
  — they have the same "should compile, unverified" status as everything
  else in this file until the first `dotnet build` on Windows.
