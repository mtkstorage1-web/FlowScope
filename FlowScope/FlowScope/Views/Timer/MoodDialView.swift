import SwiftUI

struct MoodDialView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss

    @State private var satisfaction: Double = 50
    @State private var note: String = ""
    @State private var isDragging = false

    private var config: ThemeConfiguration { themeManager.configuration }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundView

                ScrollView {
                  VStack(spacing: 20) {
                    Text("How do you feel?")
                        .font(.system(.title3, design: config.fontDesign).weight(.semibold))
                        .foregroundStyle(config.textPrimary)
                        .padding(.top, 4)

                    dial

                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What are you working on?")
                            .font(.system(.subheadline, design: config.fontDesign))
                            .foregroundStyle(config.textSecondary)

                        TextField("", text: $note, prompt:
                            Text("Task description…").foregroundColor(config.textSecondary.opacity(0.7))
                        )
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(config.surface)
                        .foregroundStyle(config.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                                .stroke(config.primary.opacity(0.35), lineWidth: 1)
                        )
                        .submitLabel(.done)
                        .accessibilityLabel("Note")
                    }
                    .padding(.horizontal)

                    saveButton
                  }
                  .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(config.primary)
                }
            }
            .toolbarBackground(config.backgroundTop, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .tint(config.primary)
        .preferredColorScheme(.dark)
    }

    // MARK: - Dial

    private var dial: some View {
        ZStack {
            Circle()
                .stroke(config.ring.trackColor, lineWidth: 18)
                .frame(width: 176, height: 176)

            // The fill stays a red→green mood ramp — that's data, not decoration.
            Circle()
                .trim(from: 0, to: satisfaction / 100)
                .stroke(
                    AngularGradient(
                        colors: [.red, .orange, .yellow, .green],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: 18, lineCap: .round)
                )
                .frame(width: 176, height: 176)
                .rotationEffect(.degrees(-90))
                .shadow(color: satisfactionColor.opacity(0.6), radius: 12)
                .animation(isDragging ? nil : .spring(response: 0.3), value: satisfaction)

            VStack(spacing: 2) {
                Text("\(Int(satisfaction))%")
                    .font(.system(size: 38, weight: .bold, design: config.fontDesign))
                    .foregroundStyle(config.textPrimary)
                    .monospacedDigit()
                Text(satisfactionLevel)
                    .font(.system(.subheadline, design: config.fontDesign))
                    .foregroundStyle(config.textSecondary)
            }
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    isDragging = true
                    // Vertical drag is far more predictable than angular hit-testing.
                    let delta = -value.translation.height / 2
                    let next = min(max(0, satisfaction + delta / 8), 100)
                    if Int(next) != Int(satisfaction) {
                        HapticManager.shared.selectionFeedback()
                    }
                    satisfaction = next
                }
                .onEnded { _ in
                    isDragging = false
                    HapticManager.shared.lightImpact()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Satisfaction")
        .accessibilityValue("\(Int(satisfaction)) percent, \(satisfactionLevel)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: satisfaction = min(100, satisfaction + 5)
            case .decrement: satisfaction = max(0, satisfaction - 5)
            default: break
            }
        }
    }

    private var saveButton: some View {
        Button {
            sessionManager.logMood(
                satisfaction: Int(satisfaction),
                note: note.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            dismiss()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Log Mood")
            }
            .font(.system(.headline, design: config.fontDesign))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .fill(config.accentGradient)
            )
            .shadow(color: config.primary.opacity(0.45), radius: 16)
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private var satisfactionColor: Color {
        switch satisfaction {
        case ..<30: return .red
        case 30..<50: return .orange
        case 50..<70: return .yellow
        default: return .green
        }
    }

    private var satisfactionLevel: String {
        switch satisfaction {
        case ..<20: return "Terrible"
        case 20..<40: return "Bad"
        case 40..<60: return "Okay"
        case 60..<80: return "Good"
        default: return "Excellent"
        }
    }
}

#Preview {
    MoodDialView()
        .environmentObject(SessionManager())
        .environmentObject(ThemeManager.shared)
}
