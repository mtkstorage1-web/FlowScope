import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Taptic feedback on iPhone. On Mac the same calls drive the Force Touch
/// trackpad where one is present, and are silently ignored where it isn't —
/// so callers never need to know which machine they're on.
class HapticManager {
    static let shared = HapticManager()

    func lightImpact() {
        guard AppSettings.shared.hapticsEnabled else { return }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #elseif os(macOS)
        performMacFeedback(.alignment)
        #endif
    }

    func mediumImpact() {
        guard AppSettings.shared.hapticsEnabled else { return }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #elseif os(macOS)
        performMacFeedback(.generic)
        #endif
    }

    func heavyImpact() {
        guard AppSettings.shared.hapticsEnabled else { return }
        #if os(iOS)
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        #elseif os(macOS)
        performMacFeedback(.levelChange)
        #endif
    }

    func successFeedback() {
        guard AppSettings.shared.hapticsEnabled else { return }
        #if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #elseif os(macOS)
        performMacFeedback(.levelChange)
        #endif
    }

    func selectionFeedback() {
        guard AppSettings.shared.hapticsEnabled else { return }
        #if os(iOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #elseif os(macOS)
        performMacFeedback(.alignment)
        #endif
    }

    #if os(macOS)
    private func performMacFeedback(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .default)
    }
    #endif
}
