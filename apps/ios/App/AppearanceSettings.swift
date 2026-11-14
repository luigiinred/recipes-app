import RecipeKit
import SwiftUI

/// Light, dark or automatic, then a theme for each: tap a card to use it for both, or one of its two orbs for just that mode.
struct AppearanceSettingsPage: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.colorTheme) private var lightRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.darkColorTheme) private var darkRaw = ""
    @AppStorage(AppSettings.Key.fontStyle) private var fontStyle = FontStyle.serif.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var accentHex = Theme.defaultAccentHex
    @Environment(\.self) private var environment
    @Environment(\.appAccent) private var accent
    private var custom = StoredCustomTheme()

    private var lightTheme: ColorTheme { ColorTheme.selected(for: .light, light: lightRaw, dark: darkRaw) }
    private var darkTheme: ColorTheme { ColorTheme.selected(for: .dark, light: lightRaw, dark: darkRaw) }
    private var usesCoconut: Bool { lightTheme == .classic || darkTheme == .classic }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                group("Color scheme") {
                    HStack(spacing: 10) {
                        ForEach(Appearance.allCases) { mode in modeCard(mode) }
                    }
                }
                group("Themes") {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(ColorTheme.colors + [.custom]) { themeCard($0) }
                    }
                    NavigationLink { CustomThemePage() } label: {
                        Label("Theme Creator", systemImage: "slider.horizontal.3").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
                    Text("Tap a theme to use it in light and dark, or tap its sun or moon side to use it for just that mode.")
                        .appFont(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
                if usesCoconut { group("Coconut accent") { accentPicker } }
                group("Text") {
                    ThemePreview()
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    NavigationLink { FontSettingsPage() } label: {
                        HStack {
                            Label("Font", systemImage: "textformat")
                            Spacer()
                            Text((FontStyle(rawValue: fontStyle) ?? .serif).title).foregroundStyle(.secondary)
                            Image(systemName: "chevron.right").appFont(.footnote, weight: .semibold).foregroundStyle(.tertiary)
                        }
                        .padding(16)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Text("Text size follows your device's settings.").appFont(.footnote).foregroundStyle(.secondary).padding(.horizontal, 4)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .settingsPage("Appearance")
    }

    private func group(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary).padding(.horizontal, 4)
            content()
        }
    }

    private func swatch(_ theme: ColorTheme, _ scheme: ColorScheme) -> Swatch {
        theme.previewSwatch(for: scheme, classicAccent: accentHex, custom: custom.colors)
    }

    // MARK: Color scheme

    private func modeCard(_ mode: Appearance) -> some View {
        let selected = appearance == mode.rawValue
        return Button { appearance = mode.rawValue } label: {
            VStack(spacing: 8) {
                PhonePreview(light: swatch(lightTheme, .light), dark: swatch(darkTheme, .dark), mode: mode)
                Text(mode == .system ? "System" : mode.title)
                    .appFont(.subheadline, weight: selected ? .bold : .regular)
                    .foregroundStyle(selected ? .primary : .secondary)
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? accent : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(mode == .system ? "System" : mode.title) appearance")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: Themes

    private func themeCard(_ theme: ColorTheme) -> some View {
        let both = lightTheme == theme && darkTheme == theme
        return VStack(spacing: 10) {
            HStack(spacing: 6) {
                orb(theme, .light)
                orb(theme, .dark)
            }
            Text(theme.title).appFont(.headline).lineLimit(1)
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(both ? accent.opacity(0.6) : Color.secondary.opacity(0.2), lineWidth: both ? 1.5 : 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture {
            lightRaw = theme.rawValue
            darkRaw = ""
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(theme.title) theme")
    }

    private func orb(_ theme: ColorTheme, _ scheme: ColorScheme) -> some View {
        let selected = (scheme == .light ? lightTheme : darkTheme) == theme
        return Button { choose(theme, for: scheme) } label: {
            ThemeOrb(swatch: swatch(theme, scheme), scheme: scheme)
                .frame(width: 56, height: 56)
                .padding(4)
                .overlay { Circle().strokeBorder(selected ? accent : .clear, lineWidth: 3) }
                .overlay(alignment: .bottomTrailing) {
                    if selected {
                        Image(systemName: scheme == .light ? "sun.max.fill" : "moon.fill")
                            .appFont(.caption2, weight: .bold)
                            .foregroundStyle(accent)
                            .frame(width: 22, height: 22)
                            .background(.background, in: Circle())
                            .overlay { Circle().strokeBorder(Color.secondary.opacity(0.25), lineWidth: 1) }
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(theme.title) \(scheme == .light ? "light" : "dark")")
        .accessibilityHint("Uses this theme for \(scheme == .light ? "light" : "dark") mode only")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    /// Light keeps the main theme; dark is stored only when it differs, so dark follows light until it's chosen apart.
    private func choose(_ theme: ColorTheme, for scheme: ColorScheme) {
        if scheme == .light {
            let currentDark = darkTheme
            lightRaw = theme.rawValue
            darkRaw = currentDark == theme ? "" : currentDark.rawValue
        } else {
            darkRaw = theme == lightTheme ? "" : theme.rawValue
        }
    }

    // MARK: Accent

    private var customAccent: Binding<Color> {
        Binding(get: { Color(hex: accentHex) ?? Theme.defaultAccent }, set: { accentHex = $0.hex(in: environment) })
    }

    private var accentPicker: some View {
        VStack(alignment: .leading, spacing: 14) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                ForEach(AccentPreset.all) { preset in
                    Button { accentHex = preset.hex } label: {
                        Circle()
                            .fill(preset.color)
                            .frame(width: 36, height: 36)
                            .overlay {
                                if accentHex.caseInsensitiveCompare(preset.hex) == .orderedSame {
                                    Image(systemName: "checkmark").appFont(.footnote, weight: .bold).foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(preset.name)
                    .accessibilityAddTraits(accentHex.caseInsensitiveCompare(preset.hex) == .orderedSame ? .isSelected : [])
                }
            }
            ColorPicker("Custom color", selection: customAccent, supportsOpacity: false)
        }
        .padding(16)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// A theme as a glowing orb: its page color, with its accent and card colors blooming from opposite corners.
private struct ThemeOrb: View {
    let swatch: Swatch
    let scheme: ColorScheme

    var body: some View {
        Circle()
            .fill(swatch.canvas)
            .overlay {
                Circle().fill(RadialGradient(colors: [swatch.surface, swatch.surface.opacity(0)], center: UnitPoint(x: 0.75, y: 0.8),
                                             startRadius: 0, endRadius: 34))
            }
            .overlay {
                Circle().fill(RadialGradient(colors: [swatch.accent, swatch.accent.opacity(0.5), swatch.accent.opacity(0)],
                                             center: UnitPoint(x: 0.3, y: 0.28), startRadius: 0, endRadius: 30))
            }
            .overlay { Circle().strokeBorder(scheme == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.1), lineWidth: 1) }
            .accessibilityHidden(true)
    }
}

/// A tiny phone showing the page and cards in the light theme, the dark one, or both side by side for System.
private struct PhonePreview: View {
    let light: Swatch
    let dark: Swatch
    let mode: Appearance

    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.secondary.opacity(0.12))
            .frame(width: 58, height: 96)
            .overlay {
                HStack(spacing: 0) {
                    if mode != .dark { pane(light) }
                    if mode != .light { pane(dark) }
                }
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .padding(3)
            }
            .accessibilityHidden(true)
    }

    private func pane(_ swatch: Swatch) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                Circle().fill(swatch.accent).frame(width: 5, height: 5)
                Capsule().fill(swatch.accent.opacity(0.35)).frame(height: 3)
            }
            .padding(.top, 8)
            RoundedRectangle(cornerRadius: 4).fill(swatch.surface).frame(height: 22)
            RoundedRectangle(cornerRadius: 4).fill(swatch.surface).frame(height: 22)
            Spacer(minLength: 0)
            Capsule().fill(swatch.accent).frame(height: 7).padding(.bottom, 6)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(swatch.canvas)
    }
}
