import RecipeKit
import SwiftUI

// MARK: Pieces

struct OnboardingHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .appFont(.largeTitle, weight: .bold)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .appFont(.body)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct OnboardingFeature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .appFont(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).appFont(.headline)
                Text(detail).appFont(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Look

struct OnboardingLookPage: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.colorTheme) private var themeRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.darkColorTheme) private var darkThemeRaw = ""
    @AppStorage(AppSettings.Key.accentColor) private var accentHex = Theme.defaultAccentHex
    @Environment(\.colorScheme) private var scheme

    private var theme: ColorTheme { ColorTheme(rawValue: themeRaw) ?? .classic }

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeader(title: "Pick a look", subtitle: "Light or dark, a color for the pages, and an accent for buttons and ratings.")
            ThemePreview()
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            section("Appearance") {
                ThemeTileRow {
                    ForEach(Appearance.allCases) { mode in
                        ThemeTile(title: mode.title, isSelected: appearance == mode.rawValue) {
                            appearance = mode.rawValue
                        } thumbnail: {
                            appearanceThumbnail(mode)
                        }
                    }
                }
            }
            section("Color") {
                ThemeTileRow {
                    ForEach(ColorTheme.colors) { option in
                        ThemeTile(title: option.title, isSelected: theme == option) {
                            themeRaw = option.rawValue; darkThemeRaw = ""
                        } thumbnail: {
                            ThemeThumbnail(swatch: option.previewSwatch(for: scheme, classicAccent: accentHex), scheme: scheme)
                        }
                    }
                }
            }
            if theme == .classic {
                section("Accent") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        ForEach(AccentPreset.all) { preset in
                            let isSelected = accentHex.caseInsensitiveCompare(preset.hex) == .orderedSame
                            Button { accentHex = preset.hex } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if isSelected { Image(systemName: "checkmark").appFont(.footnote, weight: .bold).foregroundStyle(.white) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(preset.name)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func appearanceThumbnail(_ mode: Appearance) -> some View {
        let light = ThemeThumbnail(swatch: theme.previewSwatch(for: .light, classicAccent: accentHex), scheme: .light)
        let dark = ThemeThumbnail(swatch: theme.previewSwatch(for: .dark, classicAccent: accentHex), scheme: .dark)
        switch mode {
        case .light: light
        case .dark: dark
        case .system: light.overlay { dark.mask(DiagonalHalf()) }
        }
    }
}
