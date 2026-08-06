//
//  FloatingSessionControl.swift
//  FlowScope
//
//  Created by knightzzy on 04/08/2026.
//

import SwiftUI

/// A minimalist, draggable floating control that stays on screen across every tab
/// while a session is running — a volume-style vertical slider for satisfaction
/// plus a one-tap log button, so logging never interrupts whatever you're doing.
struct FloatingSessionControl: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var theme: AppThemeManager

    private var config: ThemeConfiguration { theme.configuration }

    @State private var level: Double = 50
    @State private var isDragging = false
    @State private var justLogged = false

    // Collapsed/hidden state, persisted across launches.
    @AppStorage("floatingControl.isHidden") private var isHidden = false

    // Persisted floating position (offset from the default corner).
    @AppStorage("floatingControl.offsetX") private var storedOffsetX: Double = 0
    @AppStorage("floatingControl.offsetY") private var storedOffsetY: Double = 0
    @GestureState private var dragTranslation: CGSize = .zero

    private let width: CGFloat = 56
    private let trackHeight: CGFloat = 150

    /// Red at 0, yellow around the middle, green at 100 — matches the app's mood color language.
    private var levelColor: Color {
        switch level {
        case ..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        default: return .green
        }
    }

    var body: some View {
        Group {
            if isHidden {
                collapsedHandle
            } else {
                expandedControl
            }
        }
        .offset(x: storedOffsetX + dragTranslation.width, y: storedOffsetY + dragTranslation.height)
        .gesture(
            DragGesture()
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    storedOffsetX += value.translation.width
                    storedOffsetY += value.translation.height
                }
        )
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3), value: isHidden)
    }

    // MARK: - Expanded

    private var expandedControl: some View {
        VStack(spacing: 10) {
            // Hide handle
            Button {
                isHidden = true
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(config.primary.opacity(0.8))
                    .frame(width: 28, height: 16)
            }

            // Satisfaction track (volume-style, red → green)
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .frame(width: width, height: trackHeight)

                // Fixed full-height gradient (red at bottom, green at top) — only the
                // filled portion (up to `level`) is revealed, so the color you see
                // reflects the actual position on the 0–100 scale, not a re-stretched
                // red-to-green blend. At 20% you only ever see red/orange; green only
                // appears once the level is high enough to reach it.
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.red, .orange, .yellow, .green],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(width: width - 12, height: trackHeight - 12)
                    .mask(
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Rectangle()
                                .frame(height: max(6, (trackHeight - 12) * (level / 100)))
                        }
                    )
                    .padding(.bottom, 6)
                    .animation(isDragging ? nil : .spring(response: 0.3), value: level)

                Text("\(Int(level))")
                    .font(.system(.caption, design: config.fontDesign, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.top, 8)
            }
            .frame(width: width, height: trackHeight)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { value in
                        isDragging = true
                        let clamped = min(max(0, trackHeight - value.location.y), trackHeight)
                        let newLevel = Double(clamped / trackHeight) * 100
                        if Int(newLevel) != Int(level) {
                            HapticManager.shared.selectionFeedback()
                        }
                        level = newLevel
                    }
                    .onEnded { _ in
                        isDragging = false
                        HapticManager.shared.lightImpact()
                    }
            )

            // Log button
            Button(action: logNow) {
                Image(systemName: justLogged ? "checkmark" : "plus")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: width, height: width)
                    .background(Circle().fill(levelColor))
            }
        }
        .padding(10)
        .background(config.surface.opacity(0.92), in: RoundedRectangle(cornerRadius: config.cornerRadius + 10))
        .overlay(
            RoundedRectangle(cornerRadius: config.cornerRadius + 10)
                .stroke(config.primary.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: config.primary.opacity(0.35), radius: 12, y: 4)
    }

    // MARK: - Collapsed

    private var collapsedHandle: some View {
        Button {
            isHidden = false
        } label: {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(config.primary, lineWidth: 2)
                    .frame(width: 44, height: 44)
                Text("\(Int(level))")
                    .font(.system(.caption2, design: config.fontDesign, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
        }
    }

    private func logNow() {
        sessionManager.logMood(satisfaction: Int(level))
        HapticManager.shared.successFeedback()
        justLogged = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            justLogged = false
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FloatingSessionControl()
            .environmentObject(SessionManager())
            .environmentObject(AppThemeManager.shared)
    }
}
