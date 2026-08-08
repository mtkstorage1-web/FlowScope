//
//  ThemeManager.swift
//  FlowScope
//
//  Holds theme *state* only. All styling logic is injected via a
//  `ThemeEngine`, so this type never branches on the theme itself.
//

import SwiftUI
import Combine
import WidgetKit

final class ThemeManager: ObservableObject {

    /// Shared instance used by the app. Tests/previews can construct their own
    /// with a different engine via the initializer below.
    static let shared = ThemeManager()

    @Published var currentTheme: AppTheme {
        didSet {
            storedTheme = currentTheme.rawValue
            publishPaletteToWidgets()
        }
    }

    /// Injected styling engine — the manager holds no styling logic itself.
    private let engine: ThemeEngine

    @AppStorage("theme.selectedTheme") private var storedTheme: String = AppTheme.flame.rawValue

    init(engine: ThemeEngine = ThemeProvider(), initialTheme: AppTheme? = nil) {
        self.engine = engine
        let saved = UserDefaults.standard.string(forKey: "theme.selectedTheme")
        self.currentTheme = initialTheme ?? AppTheme(rawValue: saved ?? "") ?? .flame
        // A retired theme resolves to nil above and falls back to Flame; write
        // that back so the dead value doesn't linger in defaults forever.
        storedTheme = currentTheme.rawValue
        publishPaletteToWidgets()
    }

    /// Called when the per-theme customization store changes. The palette is
    /// derived, not stored, so the manager only has to announce that anything
    /// reading `configuration` is now stale.
    func themeCustomizationDidChange() {
        objectWillChange.send()
        publishPaletteToWidgets()
    }

    /// Mirrors the active palette into the App Group so the Home Screen widget,
    /// Lock Screen widget and Live Activity all render in the same theme.
    private func publishPaletteToWidgets() {
        let c = engine.configuration(for: currentTheme)
        SharedTheme.write(
            SharedThemePalette(
                themeID: c.theme.rawValue,
                displayName: c.theme.displayName,
                primaryHex: c.primary.hexString,
                secondaryHex: c.secondary.hexString,
                backgroundTopHex: c.backgroundTop.hexString,
                backgroundBottomHex: c.backgroundBottom.hexString,
                textPrimaryHex: c.textPrimary.hexString,
                textSecondaryHex: c.textSecondary.hexString,
                surfaceHex: c.surface.hexString,
                cornerRadius: Double(c.cornerRadius)
            )
        )
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The active configuration — every view reads its styling from here.
    var configuration: ThemeConfiguration {
        engine.configuration(for: currentTheme)
    }

    func configuration(for theme: AppTheme) -> ThemeConfiguration {
        engine.configuration(for: theme)
    }

    /// Animates using the *incoming* theme's own transition style, so
    /// Cyberpunk glitches, Neon 80s snaps and Flame crossfades.
    func switchTheme(to theme: AppTheme) {
        withAnimation(engine.configuration(for: theme).transition.animation) {
            currentTheme = theme
        }
    }

    func resetToDefault() {
        switchTheme(to: .flame)
    }

    // MARK: - Convenience passthroughs
    // Let existing views keep reading simple values without knowing about
    // ThemeConfiguration's internals.

    var accentColor: Color { configuration.primary }
    var secondaryAccentColor: Color { configuration.secondary }
    var backgroundColor: Color { configuration.backgroundBottom }
    var secondaryBackgroundColor: Color { configuration.surface }
    var textPrimary: Color { configuration.textPrimary }
    var textSecondary: Color { configuration.textSecondary }
    var chartColors: [Color] { configuration.chartColors }
    var cornerRadius: CGFloat { configuration.cornerRadius }
    var fontDesign: Font.Design { configuration.fontDesign }

    /// Every theme is a dark, high-contrast palette.
    var isDarkMode: Bool { true }
    var colorScheme: ColorScheme { .dark }

    /// Full animated background (gradient + native Canvas particles).
    var backgroundView: some View {
        ThemedBackground(configuration: configuration)
    }
}

/// The project's views refer to the manager by this name.
typealias AppThemeManager = ThemeManager
