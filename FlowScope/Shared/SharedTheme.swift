//
//  SharedTheme.swift
//  FlowScope
//
//  Publishes the active theme's palette into the App Group so the widget
//  and Live Activity render in the same theme as the app. Only plain hex
//  strings cross the process boundary — no SwiftUI types, no shared engine.
//

import SwiftUI

struct SharedThemePalette: Codable, Equatable {
    var themeID: String
    var displayName: String
    var primaryHex: String
    var secondaryHex: String
    var backgroundTopHex: String
    var backgroundBottomHex: String
    var textPrimaryHex: String
    var textSecondaryHex: String
    var surfaceHex: String
    /// Corner radius so widget cards match the app's shape language.
    var cornerRadius: Double

    static let fallback = SharedThemePalette(
        themeID: "flame",
        displayName: "Flame",
        primaryHex: "#FF6B1A",
        secondaryHex: "#FFC300",
        backgroundTopHex: "#3B0A02",
        backgroundBottomHex: "#1A0B04",
        textPrimaryHex: "#FFFFFF",
        textSecondaryHex: "#FFB088",
        surfaceHex: "#2A0D05",
        cornerRadius: 14
    )

    // Convenience accessors for widget rendering.
    var primary: Color { Color(themeHex: primaryHex) }
    var secondary: Color { Color(themeHex: secondaryHex) }
    var backgroundTop: Color { Color(themeHex: backgroundTopHex) }
    var backgroundBottom: Color { Color(themeHex: backgroundBottomHex) }
    var textPrimary: Color { Color(themeHex: textPrimaryHex) }
    var textSecondary: Color { Color(themeHex: textSecondaryHex) }
    var surface: Color { Color(themeHex: surfaceHex) }

    var backgroundGradient: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var accentGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }
}

enum SharedTheme {
    private static let key = "sharedThemePalette"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: SharedStats.appGroupID)
    }

    static func write(_ palette: SharedThemePalette) {
        guard let defaults, let data = try? JSONEncoder().encode(palette) else { return }
        defaults.set(data, forKey: key)
    }

    static func read() -> SharedThemePalette {
        guard let defaults,
              let data = defaults.data(forKey: key),
              let palette = try? JSONDecoder().decode(SharedThemePalette.self, from: data) else {
            return .fallback
        }
        return palette
    }
}

// MARK: - Hex helper

/// Namespaced so it never collides with the app target's `Color(hex:)`.
extension Color {
    init(themeHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let r, g, b, a: Double
        if cleaned.count == 8 {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}
