//
//  SettingsView.swift
//  FlowScope
//
//  "Super Settings" — one screen that controls the entire experience:
//  theme, visual effects, motion, timing, feedback and layout.
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var customStore = ThemeCustomizationStore.shared
    @State private var showResetConfirm = false

    private var config: ThemeConfiguration { themeManager.configuration }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundView

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        ThemePreviewCard(config: config)
                            .padding(.horizontal)
                            .padding(.top, 8)

                        // MARK: Theme
                        section("Theme", "paintpalette.fill") {
                            ThemeSelectionView()
                        }

                        // MARK: Customize this theme
                        section("Customize \(themeManager.currentTheme.displayName)", "paintbrush.pointed.fill") {
                            ThemeCustomizerPanel(theme: themeManager.currentTheme, config: config)
                        }

                        // MARK: Visual effects
                        section("Visual Effects", "sparkles") {
                            VStack(spacing: 14) {
                                segmented("Effect Intensity",
                                          EffectIntensity.allCases,
                                          settings.effectIntensity,
                                          \.label) { settings.effectIntensity = $0 }

                                caption(intensityHint)

                                segmented("Animation Speed",
                                          AnimationSpeed.allCases,
                                          settings.animationSpeed,
                                          \.label) { settings.animationSpeed = $0 }

                                toggle("Depth / Parallax", "square.3.layers.3d",
                                       "Renders a second slower layer behind the effects.",
                                       $settings.parallaxEnabled)
                                toggle("Animated Digits", "textformat.123",
                                       "Breathing, flicker and glow on the timer.",
                                       $settings.animatedDigits)
                                toggle("Glow", "light.max",
                                       "Outer bloom on digits, rings and buttons.",
                                       $settings.glowEnabled)

                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Label("Background Blur", systemImage: "drop.halffull")
                                            .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                                            .foregroundStyle(config.textPrimary)
                                        Spacer()
                                        Text("\(Int(settings.backgroundBlur))%")
                                            .font(.system(.caption, design: config.fontDesign))
                                            .foregroundStyle(config.textSecondary)
                                    }
                                    Slider(value: $settings.backgroundBlur, in: 0...100, step: 1)
                                        .tint(config.primary)
                                    Text("Softens the animated background so the timer stands out. 0% is sharp.")
                                        .font(.system(.caption2, design: config.fontDesign))
                                        .foregroundStyle(config.textSecondary)
                                }
                                .padding()
                                .themedSurface(config)
                            }
                        }

                        // MARK: Focus ring & timing
                        section("Focus Ring & Timing", "timer") {
                            VStack(spacing: 14) {
                                segmented("Ring Shows",
                                          RingMode.allCases,
                                          settings.ringMode,
                                          \.label) { settings.ringMode = $0 }

                                caption(settings.ringMode.explanation)

                                if settings.ringMode == .cycle {
                                    stepperRow("Cycle Length",
                                               value: settings.cycleMinutes,
                                               options: AppSettings.cycleOptions) {
                                        settings.cycleMinutes = $0
                                    }
                                    caption("The ring fills once every \(settings.cycleMinutes) minutes, then starts a new lap. “Left in cycle” counts down to that.")
                                }

                                if settings.ringMode == .sessionGoal {
                                    stepperRow("Session Goal",
                                               value: settings.goalMinutes,
                                               options: AppSettings.goalOptions) {
                                        settings.goalMinutes = $0
                                    }
                                    caption("The ring fills once over your \(settings.goalMinutes)-minute target.")
                                }

                                toggle("Cycle Complete Alert", "bell.badge",
                                       "Flash, haptic and chime when a lap finishes.",
                                       $settings.cycleAlert)
                            }
                        }

                        // MARK: Feedback
                        section("Sound & Haptics", "speaker.wave.3.fill") {
                            VStack(spacing: 14) {
                                toggle("Sound Effects", "music.note",
                                       "Synthesized cues that match your theme.",
                                       $settings.soundEnabled)

                                if settings.soundEnabled {
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Volume")
                                                .font(.system(.subheadline, design: config.fontDesign))
                                                .foregroundStyle(config.textPrimary)
                                            Spacer()
                                            Text("\(Int(settings.soundVolume * 100))%")
                                                .font(.system(.caption, design: config.fontDesign))
                                                .foregroundStyle(config.textSecondary)
                                        }
                                        Slider(value: $settings.soundVolume, in: 0...1)
                                            .tint(config.primary)
                                    }
                                    .padding()
                                    .themedSurface(config)

                                    Button {
                                        SoundManager.shared.play(.cycleComplete, theme: themeManager.currentTheme)
                                    } label: {
                                        Label("Preview Sound", systemImage: "play.circle.fill")
                                            .font(.system(.subheadline, design: config.fontDesign).weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(config.primary.opacity(0.18))
                                            .foregroundStyle(config.primary)
                                            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                                    }
                                    .buttonStyle(.plain)

                                    caption("Profile for \(themeManager.currentTheme.displayName): \(SoundProfile.matching(themeManager.currentTheme).label)")
                                }

                                toggle("Haptics", "hand.tap.fill",
                                       "Vibration on taps, logs and cycle completion.",
                                       $settings.hapticsEnabled)
                            }
                        }

                        // MARK: Layout & behavior
                        section("Layout & Behavior", "slider.horizontal.3") {
                            VStack(spacing: 14) {
                                toggle("Floating Log Control", "circle.grid.cross",
                                       "Draggable satisfaction slider on every tab.",
                                       $settings.floatingControlEnabled)
                                toggle("Dynamic Island / Lock Screen", "iphone.gen3",
                                       "Show the running session outside the app.",
                                       $settings.liveActivityEnabled)
                                toggle("Keep Screen Awake", "sun.max.fill",
                                       "Prevent auto-lock while a session runs.",
                                       $settings.keepScreenAwake)
                                toggle("Hide Status Bar", "rectangle.topthird.inset.filled",
                                       "Fullscreen focus mode.",
                                       $settings.hideStatusBar)
                            }
                        }

                        // MARK: Reset
                        Button(role: .destructive) { showResetConfirm = true } label: {
                            Label("Reset Everything", systemImage: "arrow.counterclockwise")
                                .font(.system(.headline, design: config.fontDesign))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .foregroundStyle(.white)
                                .background(Color.red.opacity(0.8))
                                .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog("Reset all settings?", isPresented: $showResetConfirm, titleVisibility: .visible) {
                Button("Reset Everything", role: .destructive) {
                    settings.resetAll()
                    themeManager.resetToDefault()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Restores the default theme, effects, timing and feedback. Your sessions are not affected.")
            }
        }
        .applyTheme(config)
    }

    // MARK: - Building blocks

    private var intensityHint: String {
        switch settings.effectIntensity {
        case .off:      return "No particle effects — solid gradient only. Best for battery."
        case .subtle:   return "Barely-there ambience."
        case .balanced: return "Recommended."
        case .intense:  return "Denser, brighter, more particles."
        case .maximum:  return "Everything at full bloom. Heaviest on battery."
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String,
                                        _ icon: String,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(.headline, design: config.fontDesign))
                .foregroundStyle(config.primary)
            content()
        }
        .padding(.horizontal)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.system(.caption2, design: config.fontDesign))
            .foregroundStyle(config.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func segmented<T: Hashable & Identifiable>(
        _ title: String,
        _ options: [T],
        _ selection: T,
        _ label: KeyPath<T, String>,
        onChange: @escaping (T) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                .foregroundStyle(config.textPrimary)

            HStack(spacing: 6) {
                ForEach(options) { option in
                    let isOn = option == selection
                    Button { onChange(option) } label: {
                        Text(option[keyPath: label])
                            .font(.system(.caption, design: config.fontDesign).weight(isOn ? .bold : .regular))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: config.cornerRadius * 0.7, style: .continuous)
                                    .fill(isOn ? AnyShapeStyle(config.accentGradient) : AnyShapeStyle(config.surface))
                            )
                            .foregroundStyle(isOn ? Color.black : config.textSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? [.isSelected] : [])
                }
            }
        }
    }

    private func stepperRow(_ title: String,
                            value: Int,
                            options: [Int],
                            onChange: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                    .foregroundStyle(config.textPrimary)
                Spacer()
                Text("\(value) min")
                    .font(.system(.subheadline, design: config.fontDesign).weight(.bold))
                    .foregroundStyle(config.primary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isOn = option == value
                        Button { onChange(option) } label: {
                            Text("\(option)")
                                .font(.system(.caption, design: config.fontDesign).weight(isOn ? .bold : .regular))
                                .frame(minWidth: 40)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule().fill(isOn ? AnyShapeStyle(config.accentGradient) : AnyShapeStyle(config.surface))
                                )
                                .foregroundStyle(isOn ? Color.black : config.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 16)
            }
        }
        .padding()
        .themedSurface(config)
    }

    private func toggle(_ title: String, _ icon: String, _ subtitle: String, _ binding: Binding<Bool>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(config.primary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                    .foregroundStyle(config.textPrimary)
                Text(subtitle)
                    .font(.system(.caption2, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
            }
            Spacer()
            Toggle("", isOn: binding)
                .labelsHidden()
                .tint(config.primary)
        }
        .padding()
        .themedSurface(config)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Per-theme Customizer

/// Recolor and reshape a single theme without leaving its identity.
private struct ThemeCustomizerPanel: View {
    @ObservedObject private var store = ThemeCustomizationStore.shared
    let theme: AppTheme
    let config: ThemeConfiguration

    private var custom: ThemeCustomization { store.customization(for: theme) }

    private func update(_ transform: (inout ThemeCustomization) -> Void) {
        var copy = custom
        transform(&copy)
        store.set(copy, for: theme)
    }

    var body: some View {
        VStack(spacing: 14) {
            // Live swatch strip
            HStack(spacing: 10) {
                swatch(config.primary, "Accent")
                swatch(config.secondary, "Secondary")
                swatch(config.backgroundTop, "Background")
                Spacer()
                if custom.isCustomized {
                    Button("Reset") { store.reset(theme) }
                        .font(.system(.caption, design: config.fontDesign).weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .themedSurface(config)

            // Hue — the "blue fire" control
            slider("Color", value: Binding(
                get: { custom.hueShift },
                set: { v in update { $0.hueShift = v } }
            ), range: -180...180, display: "\(Int(custom.hueShift))°", showsHueBar: true)

            slider("Saturation", value: Binding(
                get: { custom.saturation },
                set: { v in update { $0.saturation = v } }
            ), range: 0...1.6, display: String(format: "%.0f%%", custom.saturation * 100))

            slider("Brightness", value: Binding(
                get: { custom.brightness },
                set: { v in update { $0.brightness = v } }
            ), range: 0.6...1.5, display: String(format: "%.0f%%", custom.brightness * 100))

            // Quick presets
            VStack(alignment: .leading, spacing: 6) {
                Text("Quick Colors")
                    .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                    .foregroundStyle(config.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Self.presets, id: \.0) { name, shift in
                            Button {
                                update { $0.hueShift = shift }
                            } label: {
                                Text(name)
                                    .font(.system(.caption2, design: config.fontDesign))
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(config.surface))
                                    .overlay(Capsule().stroke(config.primary.opacity(0.3), lineWidth: 1))
                                    .foregroundStyle(config.textPrimary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.trailing, 16)
                }
            }
            .padding()
            .themedSurface(config)

            // Ring design
            VStack(alignment: .leading, spacing: 8) {
                Text("Ring Design")
                    .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                    .foregroundStyle(config.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88), spacing: 8)], spacing: 8) {
                    ForEach(RingDesign.allCases) { design in
                        let isOn = config.ring.design == design
                        Button {
                            update { $0.ringDesign = design }
                        } label: {
                            Text(design.label)
                                .font(.system(.caption2, design: config.fontDesign).weight(isOn ? .bold : .regular))
                                .lineLimit(1).minimumScaleFactor(0.7)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(
                                    RoundedRectangle(cornerRadius: config.cornerRadius * 0.7, style: .continuous)
                                        .fill(isOn ? AnyShapeStyle(config.accentGradient) : AnyShapeStyle(config.surface))
                                )
                                .foregroundStyle(isOn ? Color.black : config.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .themedSurface(config)
        }
    }

    /// Named hue offsets — "Blue Fire" is just Flame at +210°.
    static let presets: [(String, Double)] = [
        ("Original", 0), ("Blue", 210), ("Cyan", 170), ("Violet", 260),
        ("Magenta", 300), ("Green", 110), ("Gold", 40), ("Crimson", -20)
    ]

    private func swatch(_ color: Color, _ label: String) -> some View {
        VStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(Circle().stroke(.white.opacity(0.25), lineWidth: 1))
            Text(label)
                .font(.system(size: 9, design: config.fontDesign))
                .foregroundStyle(config.textSecondary)
        }
    }

    private func slider(_ title: String,
                        value: Binding<Double>,
                        range: ClosedRange<Double>,
                        display: String,
                        showsHueBar: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: config.fontDesign).weight(.medium))
                    .foregroundStyle(config.textPrimary)
                Spacer()
                Text(display)
                    .font(.system(.caption, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
            }
            if showsHueBar {
                LinearGradient(
                    colors: stride(from: 0.0, through: 1.0, by: 0.1).map {
                        Color(hue: $0, saturation: 0.85, brightness: 0.95)
                    },
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(height: 6)
                .clipShape(Capsule())
            }
            Slider(value: value, in: range)
                .tint(config.primary)
        }
        .padding()
        .themedSurface(config)
    }
}

// MARK: - Preview Card

private struct ThemePreviewCard: View {
    let config: ThemeConfiguration

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Deep Work")
                    .font(.system(.headline, design: config.fontDesign).weight(config.fontWeight))
                    .foregroundStyle(config.textPrimary)
                Spacer()
                Text("Coding")
                    .font(.system(.caption, design: config.fontDesign))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(config.primary.opacity(0.2))
                    .foregroundStyle(config.primary)
                    .clipShape(Capsule())
            }

            ZStack {
                ThemedProgressRing(progress: 0.62, config: config, diameter: 120)
                Text("32:18")
                    .font(.system(.title3, design: config.fontDesign).weight(config.fontWeight))
                    .foregroundStyle(config.digitGradient)
            }
            .frame(height: 130)

            ThemedIconButton(systemName: "play.fill", config: config, size: 56) { }
        }
        .padding(18)
        .themedSurface(config)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager.shared)
}
