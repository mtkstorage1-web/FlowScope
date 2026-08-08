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

- **Background art is simplified.** The Apple app draws a bespoke `Canvas`
  particle system per theme (embers, scanlines, lava cracks, retro grid). The
  Windows build draws static geometry in the same colours and densities.
  `Views/TimerPage.xaml.cs → DrawParticles()` is where that would grow.
- **No theme emblems.** The hand-drawn per-theme emblems in
  `ThemeEmblems.swift` have no Windows equivalent yet; the theme grid shows
  gradient swatches.
- **No widgets or Live Activities.** There is no Windows counterpart to the
  Home Screen widget or the Dynamic Island. Windows widgets would be a
  separate host app.
- **No per-theme customisation UI.** The hue/saturation/brightness overrides
  from `ThemeCustomization.swift` are not exposed yet.
