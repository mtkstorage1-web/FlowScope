//
//  PlatformCompat.swift
//  FlowScope
//
//  One place for every "iOS has it, macOS doesn't" difference, so the ~8k lines
//  of shared SwiftUI below it stay platform-agnostic. Anything that needs UIKit
//  on iPhone and AppKit on Mac gets a single neutral spelling here.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias PlatformColor = NSColor
#endif

// MARK: - Color components

extension Color {
    /// sRGB components. The theme engine mixes and re-tints colors constantly,
    /// and `NSColor` traps if you ask a catalog color for components without
    /// converting it first — so both paths go through sRGB explicitly.
    func rgbaComponents() -> (red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        PlatformColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b, a)
        #else
        guard let c = PlatformColor(self).usingColorSpace(.sRGB) else {
            return (0, 0, 0, 1)
        }
        return (c.redComponent, c.greenComponent, c.blueComponent, c.alphaComponent)
        #endif
    }

    /// HSB components, or nil when the color can't be expressed in a hue-based
    /// space. Callers fall back to leaving the color untouched.
    func hsbaComponents() -> (hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat)? {
        #if canImport(UIKit)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard PlatformColor(self).getHue(&h, saturation: &s, brightness: &b, alpha: &a) else {
            return nil
        }
        return (h, s, b, a)
        #else
        guard let c = PlatformColor(self).usingColorSpace(.sRGB) else { return nil }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s, b, a)
        #endif
    }
}

// MARK: - Navigation chrome

enum PlatformTitleMode {
    case inline
    case large
}

extension View {
    /// `navigationBarTitleDisplayMode` is iOS-only; on Mac the title lives in
    /// the window's toolbar and there is nothing to size.
    @ViewBuilder
    func platformNavigationTitleMode(_ mode: PlatformTitleMode) -> some View {
        #if os(iOS)
        switch mode {
        case .inline: self.navigationBarTitleDisplayMode(.inline)
        case .large:  self.navigationBarTitleDisplayMode(.large)
        }
        #else
        self
        #endif
    }

    /// Tints the bar the sheet hangs under: a navigation bar on iOS, the
    /// window's own toolbar on Mac.
    @ViewBuilder
    func platformToolbarBackground<S: ShapeStyle>(_ style: S) -> some View {
        #if os(iOS)
        self.toolbarBackground(style, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        #else
        self.toolbarBackground(style, for: .windowToolbar)
            .toolbarBackground(.visible, for: .windowToolbar)
        #endif
    }

    /// No status bar to hide on a Mac.
    @ViewBuilder
    func platformStatusBarHidden(_ hidden: Bool) -> some View {
        #if os(iOS)
        self.statusBar(hidden: hidden)
        #else
        self
        #endif
    }

    /// Sheets are half-height cards on iPhone and real panels on Mac, so the
    /// Mac side gets an explicit size instead of detents.
    @ViewBuilder
    func platformSheetSizing(minWidth: CGFloat = 460, minHeight: CGFloat = 560) -> some View {
        #if os(iOS)
        self.presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #else
        self.frame(minWidth: minWidth, minHeight: minHeight)
        #endif
    }
}

// MARK: - Keeping the screen awake

/// iOS disables the idle timer; macOS files a power-management activity.
/// Both are "don't sleep while a focus session is running".
enum ScreenAwake {
    #if os(macOS)
    private static var activityToken: NSObjectProtocol?
    #endif

    static func setEnabled(_ enabled: Bool) {
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = enabled
        #elseif os(macOS)
        if enabled {
            guard activityToken == nil else { return }
            activityToken = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: "FlowScope focus session running"
            )
        } else if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
        #endif
    }
}

// MARK: - System settings

enum PlatformSettings {
    /// Opens the place where the user can re-enable what we're warning about.
    static func openAppSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #elseif os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }
}
