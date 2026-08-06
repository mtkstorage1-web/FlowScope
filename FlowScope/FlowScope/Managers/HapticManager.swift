import SwiftUI

class HapticManager {
    static let shared = HapticManager()
    
    func lightImpact() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    func mediumImpact() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    func heavyImpact() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()
    }
    
    func successFeedback() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
    
    func selectionFeedback() {
        guard AppSettings.shared.hapticsEnabled else { return }
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
