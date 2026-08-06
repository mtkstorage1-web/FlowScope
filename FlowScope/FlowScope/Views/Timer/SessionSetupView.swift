//
//  SessionSetupView.swift
//  FlowScope
//
//  Created by knightzzy on 04/08/2026.
//

import SwiftUI

struct SessionSetupView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var themeManager: ThemeManager

    @State private var sessionName: String = ""
    @State private var category: String = ""
    @FocusState private var nameFocused: Bool

    private var config: ThemeConfiguration { themeManager.configuration }

    let suggestedCategories = [
        "Work", "Study", "Exercise", "Creative", "Chores",
        "Reading", "Coding", "Meeting", "Gaming", "General"
    ]

    private var trimmedName: String {
        sessionName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeManager.backgroundView

                ScrollView {
                    VStack(spacing: 24) {
                        Image(systemName: "timer.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(config.accentGradient)
                            .padding(.top, 12)
                            .accessibilityHidden(true)

                        Text("What are you working on?")
                            .font(.system(.title3, design: config.fontDesign).weight(.semibold))
                            .foregroundStyle(config.textPrimary)

                        // Session name
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("Session Name")
                            TextField("", text: $sessionName, prompt: namePrompt)
                                .themedField(config)
                                .focused($nameFocused)
                                .submitLabel(.next)
                                .accessibilityLabel("Session name")
                        }

                        // Category — free text, chips are just shortcuts
                        VStack(alignment: .leading, spacing: 8) {
                            fieldLabel("Category")
                            TextField("", text: $category, prompt: categoryPrompt)
                                .themedField(config)
                                .submitLabel(.done)
                                .accessibilityLabel("Category")

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(suggestedCategories, id: \.self) { suggestion in
                                        CategoryChip(
                                            title: suggestion,
                                            isSelected: category == suggestion,
                                            config: config
                                        ) {
                                            category = suggestion
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                                // Trailing inset so the last chip isn't clipped.
                                .padding(.trailing, 16)
                            }
                        }

                        Spacer(minLength: 20)

                        startButton
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("New Session")
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
        .onAppear { nameFocused = true }
    }

    // MARK: - Pieces

    private var namePrompt: Text {
        Text("e.g., Writing blog post").foregroundColor(config.textSecondary.opacity(0.7))
    }

    private var categoryPrompt: Text {
        Text("e.g., Work, Study, or your own…").foregroundColor(config.textSecondary.opacity(0.7))
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(.subheadline, design: config.fontDesign).weight(.semibold))
            .foregroundStyle(config.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var startButton: some View {
        Button(action: start) {
            HStack {
                Image(systemName: "play.circle.fill")
                Text("Start Session")
            }
            .font(.system(.headline, design: config.fontDesign))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: config.cornerRadius, style: .continuous)
                    .fill(config.accentGradient)
            )
            .shadow(color: config.primary.opacity(trimmedName.isEmpty ? 0 : 0.45), radius: 18)
        }
        .buttonStyle(.plain)
        .disabled(trimmedName.isEmpty)
        .opacity(trimmedName.isEmpty ? 0.45 : 1)
        .accessibilityHint(trimmedName.isEmpty ? "Enter a session name first" : "Starts the focus timer")
    }

    private func start() {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        sessionManager.startSession(
            name: trimmedName,
            category: trimmedCategory.isEmpty ? "General" : trimmedCategory
        )
        dismiss()
    }
}

// MARK: - Themed Field

private extension View {
    func themedField(_ config: ThemeConfiguration) -> some View {
        self
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
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let config: ThemeConfiguration
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.subheadline, design: config.fontDesign))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected ? AnyShapeStyle(config.accentGradient) : AnyShapeStyle(config.surface))
                )
                .foregroundStyle(isSelected ? Color.black : config.textPrimary)
                .overlay(
                    Capsule().stroke(config.primary.opacity(isSelected ? 0 : 0.25), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

#Preview {
    SessionSetupView()
        .environmentObject(SessionManager())
        .environmentObject(ThemeManager.shared)
}
