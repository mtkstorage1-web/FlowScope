//
//  ThemeSelectionView.swift
//  FlowScope
//
//  Grid of the theme swatches. Tapping one triggers the 0.8s crossfade.
//

import SwiftUI

struct ThemeSelectionView: View {
    @EnvironmentObject var themeManager: ThemeManager

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 16)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 18) {
            ForEach(AppTheme.allCases) { theme in
                ThemeSwatch(
                    config: themeManager.configuration(for: theme),
                    isSelected: themeManager.currentTheme == theme
                ) {
                    themeManager.switchTheme(to: theme)
                }
            }
        }
    }
}

// MARK: - Swatch

private struct ThemeSwatch: View {
    let config: ThemeConfiguration
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [config.primary, config.secondary, config.backgroundBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 58, height: 58)
                        .shadow(color: config.primary.opacity(0.6), radius: isSelected ? 12 : 4)

                    // Character themes are identified by their emblem, not a
                    // stand-in glyph — that's the whole reason to pick one.
                    if let emblem = config.emblem {
                        ThemeEmblemView(emblem: emblem, config: config, size: 38, strength: 1)
                    } else {
                        Image(systemName: config.theme.icon)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                    Circle()
                        .stroke(config.primary, lineWidth: 3)
                        .frame(width: 68, height: 68)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(height: 70)

                Text(config.theme.displayName)
                    .font(.system(.caption2, design: config.fontDesign))
                    .foregroundStyle(isSelected ? config.primary : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.8), value: isSelected)
    }
}

#Preview {
    ZStack {
        ThemedBackground(configuration: ThemeProvider().configuration(for: .cyberpunk))
        ScrollView {
            ThemeSelectionView()
                .environmentObject(ThemeManager.shared)
                .padding()
        }
    }
}
