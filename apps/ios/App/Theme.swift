import SwiftUI

enum Theme {
    /// The accent chosen in Settings, resolved from the environment wherever it is drawn, so sheets, covers and the Mac follow it too.
    static let accent = AccentStyle()
    static let defaultAccentHex = "DB4738"
    static var defaultAccent: Color { Color(hex: defaultAccentHex) ?? .red }
}

private struct AppAccentKey: EnvironmentKey {
    static let defaultValue = Color(hex: Theme.defaultAccentHex) ?? .red
}

extension EnvironmentValues {
    /// The accent color as a `Color`, for the few places a style won't do (gradients, glass, swipe actions).
    var appAccent: Color {
        get { self[AppAccentKey.self] }
        set { self[AppAccentKey.self] = newValue }
    }
}

struct AccentStyle: ShapeStyle {
    func resolve(in environment: EnvironmentValues) -> Color { environment.appAccent }
}

enum Appearance: String, CaseIterable, Identifiable {
    case light, dark, system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        case .system: "Auto"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .light: .light
        case .dark: .dark
        case .system: nil
        }
    }
}

/// The page, card and accent colors, chosen apart from light or dark: every theme comes in both.
enum ColorTheme: String, CaseIterable, Identifiable {
    case classic, paper, tomato, pear, blueberry, plum, custom

    var id: String { rawValue }

    static let colors: [ColorTheme] = [.classic, .paper, .tomato, .pear, .blueberry, .plum]

    var title: String {
        switch self {
        case .classic: "Classic"
        case .paper: "Paper"
        case .tomato: "Tomato"
        case .pear: "Pear"
        case .blueberry: "Blueberry"
        case .plum: "Plum"
        case .custom: "Custom"
        }
    }

    /// Classic is plain white or black and takes the accent chosen in Settings; the others bring their own.
    func swatch(for scheme: ColorScheme, custom: CustomThemeColors = .init()) -> Swatch? {
        let dark = scheme == .dark
        return switch self {
        case .classic: nil
        case .paper: dark ? Swatch("27221B", "362F26", "E07A3F") : Swatch("F4ECD8", "FBF6EA", AccentPreset.rust)
        case .tomato: dark ? Swatch("2B1716", "3D2220", "EC6A58") : Swatch("F8E6E2", "FDF4F2", Theme.defaultAccentHex)
        case .pear: dark ? Swatch("1F2417", "2C3321", "A6C35A") : Swatch("EDF0D8", "F8F9EE", AccentPreset.pear)
        case .blueberry: dark ? Swatch("1B1D2E", "272A40", "6E8FEA") : Swatch("E6E8F3", "F4F5FB", AccentPreset.blueberry)
        case .plum: dark ? Swatch("241B2A", "33263B", "B488E0") : Swatch("F0E6F1", "F9F3F9", AccentPreset.plum)
        case .custom: custom.swatch(for: scheme)
        }
    }

    func accentHex(for scheme: ColorScheme, classicAccent: String, custom: CustomThemeColors = .init()) -> String {
        swatch(for: scheme, custom: custom)?.accentHex ?? classicAccent
    }

    /// The colors a picture of the theme is drawn in, with Classic's system white and black spelled out.
    func previewSwatch(for scheme: ColorScheme, classicAccent: String, custom: CustomThemeColors = .init()) -> Swatch {
        swatch(for: scheme, custom: custom) ?? (scheme == .dark ? Swatch("000000", "1C1C1E", classicAccent) : Swatch("F2F2F7", "FFFFFF", classicAccent))
    }

    /// Themes from before light and dark were chosen apart, mapped to the closest theme and mode.
    static func migrateLegacyAppearance(in defaults: UserDefaults = .standard) {
        guard let raw = defaults.string(forKey: AppSettings.Key.appearance), Appearance(rawValue: raw) == nil else { return }
        var mode = Appearance.system
        let theme: ColorTheme
        switch raw {
        case "black": theme = .classic; mode = .dark
        case "sepia": theme = .paper; mode = .light
        case "blueberry": theme = .blueberry
        case "rose", "chai": theme = .tomato
        case "olive", "mint": theme = .pear
        case "custom":
            theme = .custom
            let wasDark = defaults.bool(forKey: "customThemeDark")
            let accent = defaults.string(forKey: AppSettings.Key.accentColor) ?? Theme.defaultAccentHex
            if wasDark {
                mode = .dark
                for (from, to) in [(AppSettings.Key.customThemeCanvas, AppSettings.Key.customThemeDarkCanvas), (AppSettings.Key.customThemeSurface, AppSettings.Key.customThemeDarkSurface)] {
                    defaults.set(defaults.string(forKey: from), forKey: to)
                    defaults.removeObject(forKey: from)
                }
                defaults.set(accent, forKey: AppSettings.Key.customThemeDarkAccent)
            } else {
                defaults.set(accent, forKey: AppSettings.Key.customThemeAccent)
            }
        default: theme = .paper
        }
        defaults.set(mode.rawValue, forKey: AppSettings.Key.appearance)
        defaults.set(theme.rawValue, forKey: AppSettings.Key.colorTheme)
    }
}

struct Swatch: Equatable {
    var canvasHex: String
    /// Cards, rows and fields sitting on the canvas.
    var surfaceHex: String
    var accentHex: String

    init(_ canvasHex: String, _ surfaceHex: String, _ accentHex: String) {
        self.canvasHex = canvasHex
        self.surfaceHex = surfaceHex
        self.accentHex = accentHex
    }

    var canvas: Color { Color(hex: canvasHex) ?? .clear }
    var surface: Color { Color(hex: surfaceHex) ?? .clear }
    var accent: Color { Color(hex: accentHex) ?? Theme.defaultAccent }
}

/// The colors a screen paints with, so the Custom theme reads exactly like the built-in ones.
struct ThemePalette {
    var colorScheme: ColorScheme?
    var canvas: Color?
    var surface: Color?

    static let system = ThemePalette()
}

struct CustomThemeColors: Equatable {
    var light = Swatch("F4ECD8", "FBF6EA", Theme.defaultAccentHex)
    var dark = Swatch("27221B", "362F26", "E07A3F")

    func swatch(for scheme: ColorScheme) -> Swatch { scheme == .dark ? dark : light }
}

extension CustomThemeColors {
    init(defaults: UserDefaults) {
        self.init()
        func read(_ key: String, _ fallback: String) -> String { defaults.string(forKey: key) ?? fallback }
        light = Swatch(read(AppSettings.Key.customThemeCanvas, light.canvasHex), read(AppSettings.Key.customThemeSurface, light.surfaceHex), read(AppSettings.Key.customThemeAccent, light.accentHex))
        dark = Swatch(read(AppSettings.Key.customThemeDarkCanvas, dark.canvasHex), read(AppSettings.Key.customThemeDarkSurface, dark.surfaceHex), read(AppSettings.Key.customThemeDarkAccent, dark.accentHex))
    }
}

extension ColorTheme {
    /// The accent the app shows in light mode, for places drawn outside it such as widgets.
    static func currentAccentHex(in defaults: UserDefaults = .standard) -> String {
        let theme = ColorTheme(rawValue: defaults.string(forKey: AppSettings.Key.colorTheme) ?? "") ?? .classic
        let classic = defaults.string(forKey: AppSettings.Key.accentColor) ?? Theme.defaultAccentHex
        return theme.accentHex(for: .light, classicAccent: classic, custom: CustomThemeColors(defaults: defaults))
    }
}

/// The Custom theme's colors as stored in Settings, for views to read and edit.
struct StoredCustomTheme: DynamicProperty {
    private static let defaults = CustomThemeColors()

    @AppStorage(AppSettings.Key.customThemeCanvas) var lightCanvas = defaults.light.canvasHex
    @AppStorage(AppSettings.Key.customThemeSurface) var lightSurface = defaults.light.surfaceHex
    @AppStorage(AppSettings.Key.customThemeAccent) var lightAccent = defaults.light.accentHex
    @AppStorage(AppSettings.Key.customThemeDarkCanvas) var darkCanvas = defaults.dark.canvasHex
    @AppStorage(AppSettings.Key.customThemeDarkSurface) var darkSurface = defaults.dark.surfaceHex
    @AppStorage(AppSettings.Key.customThemeDarkAccent) var darkAccent = defaults.dark.accentHex

    var colors: CustomThemeColors {
        CustomThemeColors(light: Swatch(lightCanvas, lightSurface, lightAccent), dark: Swatch(darkCanvas, darkSurface, darkAccent))
    }

    func set(_ swatch: Swatch, for scheme: ColorScheme) {
        if scheme == .dark {
            darkCanvas = swatch.canvasHex; darkSurface = swatch.surfaceHex; darkAccent = swatch.accentHex
        } else {
            lightCanvas = swatch.canvasHex; lightSurface = swatch.surfaceHex; lightAccent = swatch.accentHex
        }
    }
}

enum FontStyle: String, CaseIterable, Identifiable {
    case serif, sans, rounded, monospaced
    case georgia, charter, iowan, palatino, baskerville
    case avenir, gillSans, futura, optima
    case typewriter

    var id: String { rawValue }

    static let system: [FontStyle] = [.serif, .sans, .rounded, .monospaced]
    static let serifs: [FontStyle] = [.georgia, .charter, .iowan, .palatino, .baskerville]
    static let sansSerifs: [FontStyle] = [.avenir, .gillSans, .futura, .optima]
    static let typewriters: [FontStyle] = [.typewriter]

    var title: String {
        switch self {
        case .serif: "New York"
        case .sans: "San Francisco"
        case .rounded: "Rounded"
        case .monospaced: "Monospaced"
        default: family ?? rawValue
        }
    }

    /// A font family on every Apple device; the system designs have none and use `design` instead.
    var family: String? {
        switch self {
        case .serif, .sans, .rounded, .monospaced: nil
        case .georgia: "Georgia"
        case .charter: "Charter"
        case .iowan: "Iowan Old Style"
        case .palatino: "Palatino"
        case .baskerville: "Baskerville"
        case .avenir: "Avenir Next"
        case .gillSans: "Gill Sans"
        case .futura: "Futura"
        case .optima: "Optima"
        case .typewriter: "American Typewriter"
        }
    }

    var design: Font.Design {
        switch self {
        case .serif: .serif
        case .rounded: .rounded
        case .monospaced: .monospaced
        default: .default
        }
    }
}

extension Font.TextStyle {
    /// The point size at the default Dynamic Type setting, which custom fonts scale from.
    var defaultSize: CGFloat {
        switch self {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline, .body: 17
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}

extension Font {
    static func app(_ style: TextStyle, weight: Weight? = nil, family: String?) -> Font {
        let weight = weight ?? (style == .headline ? .semibold : nil)
        let font: Font = if let family { .custom(family, size: style.defaultSize, relativeTo: style) } else { .system(style) }
        return weight.map { font.weight($0) } ?? font
    }
}

private struct AppFontFamilyKey: EnvironmentKey {
    static let defaultValue: String? = nil
}

extension EnvironmentValues {
    var appFontFamily: String? {
        get { self[AppFontFamilyKey.self] }
        set { self[AppFontFamilyKey.self] = newValue }
    }
}

/// A text style in the font family chosen in Settings, which a plain `.font(.body)` would ignore.
private struct AppFont: ViewModifier {
    @Environment(\.appFontFamily) private var family
    let style: Font.TextStyle
    let weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(.app(style, weight: weight, family: family))
    }
}

struct AccentPreset: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
    var color: Color { Color(hex: hex) ?? .red }

    static let blueberry = "3B6FD6"
    static let rust = "BA3801"
    static let pear = "7A9A2E"
    static let plum = "8E4FC1"

    static let all = [
        AccentPreset(name: "Tomato", hex: Theme.defaultAccentHex),
        AccentPreset(name: "Rust", hex: rust),
        AccentPreset(name: "Orange", hex: "E8802A"),
        AccentPreset(name: "Saffron", hex: "D9A011"),
        AccentPreset(name: "Pear", hex: pear),
        AccentPreset(name: "Basil", hex: "3E8E5A"),
        AccentPreset(name: "Teal", hex: "1F9D9A"),
        AccentPreset(name: "Blueberry", hex: blueberry),
        AccentPreset(name: "Plum", hex: plum),
        AccentPreset(name: "Rose", hex: "D6457F"),
        AccentPreset(name: "Graphite", hex: "5C6670"),
    ]
}

extension Color {
    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6, let value = UInt32(text, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    func hex(in environment: EnvironmentValues) -> String {
        let resolved = resolve(in: environment)
        func byte(_ value: Float) -> Int { Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "%02X%02X%02X", byte(resolved.red), byte(resolved.green), byte(resolved.blue))
    }
}

/// Applies the appearance, theme, font and accent color chosen in Settings.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppSettings.Key.appearance) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.colorTheme) private var themeRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.fontStyle) private var fontRaw = FontStyle.serif.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var classicAccent = Theme.defaultAccentHex
    private var custom = StoredCustomTheme()
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let theme = ColorTheme(rawValue: themeRaw) ?? .classic
        let mode = (Appearance(rawValue: appearanceRaw) ?? .system).colorScheme
        let scheme = mode ?? systemScheme
        let swatch = theme.swatch(for: scheme, custom: custom.colors)
        let palette = ThemePalette(colorScheme: mode, canvas: swatch?.canvas, surface: swatch?.surface)
        let resolvedHex = swatch?.accentHex ?? classicAccent
        let accent = Color(hex: resolvedHex) ?? Theme.defaultAccent
        content
            .environment(\.appearance, palette)
            .environment(\.appAccent, accent)
            .tint(accent)
            .modifier(AppFontStyle(style: FontStyle(rawValue: fontRaw) ?? .serif))
            .preferredColorScheme(palette.colorScheme)
            #if os(iOS) && !SHARE_EXTENSION
            .onChange(of: fontRaw, initial: true) { _, raw in ThemeFonts.apply(FontStyle(rawValue: raw) ?? .serif) }
            .onChange(of: resolvedHex, initial: true) { _, hex in ThemeTint.apply(Color(hex: hex) ?? Theme.defaultAccent) }
            #endif
    }
}

/// A font design overrides even custom fonts beneath it, so a chosen family sets none.
private struct AppFontStyle: ViewModifier {
    let style: FontStyle

    func body(content: Content) -> some View {
        if let family = style.family {
            content
                .environment(\.appFontFamily, family)
                .font(.app(.body, family: family))
        } else {
            content.fontDesign(style.design)
        }
    }
}

private struct AppearanceKey: EnvironmentKey {
    static let defaultValue = ThemePalette.system
}

extension EnvironmentValues {
    var appearance: ThemePalette {
        get { self[AppearanceKey.self] }
        set { self[AppearanceKey.self] = newValue }
    }
}

/// Paints a screen with the chosen theme's page color and hides the system's list background so it shows.
private struct ThemedCanvas: ViewModifier {
    @Environment(\.appearance) private var appearance

    func body(content: Content) -> some View {
        if let canvas = appearance.canvas {
            content
                .scrollContentBackground(.hidden)
                .background(canvas.ignoresSafeArea())
                #if os(iOS)
                .containerBackground(canvas, for: .navigation)
                #endif
        } else {
            content
        }
    }
}

/// List rows draw their own background, so the themes that bring a page color have to color them too.
private struct ThemedRow: ViewModifier {
    @Environment(\.appearance) private var appearance
    let raised: Bool

    func body(content: Content) -> some View {
        content.listRowBackground(raised ? appearance.surface : appearance.canvas)
    }
}

extension View {
    /// `raised` rows are cards on the page, as in inset grouped lists; the rest sit flush on it.
    func themedRow(raised: Bool = false) -> some View { modifier(ThemedRow(raised: raised)) }
    func appTheme() -> some View { modifier(AppThemeModifier()) }
    func appFont(_ style: Font.TextStyle, weight: Font.Weight? = nil) -> some View { modifier(AppFont(style: style, weight: weight)) }
    func themedCanvas() -> some View { modifier(ThemedCanvas()) }
}
