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
    case system, light, dark, black, sepia, butter, linen, olive, rose, crema, mint, blueberry, chai, cocoa, custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .black: "Pitch Black"
        case .sepia: "Sepia"
        case .butter: "Butter"
        case .linen: "Washed Linen"
        case .olive: "Olive Grove"
        case .rose: "Vintage Rose"
        case .crema: "Crema"
        case .mint: "Mint"
        case .blueberry: "Blueberry"
        case .chai: "Red Chai"
        case .cocoa: "Cowhide Cocoa"
        case .custom: "Custom"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        case .black: "moon.fill"
        case .sepia: "book"
        case .butter: "sun.haze"
        case .linen: "square.grid.3x3"
        case .olive: "leaf"
        case .rose: "camera.macro"
        case .crema: "cup.and.heat.waves"
        case .mint: "leaf.circle"
        case .blueberry: "circle.grid.cross"
        case .chai: "cup.and.saucer"
        case .cocoa: "mug"
        case .custom: "paintbrush"
        }
    }

    /// The cookbook palettes have a light and a dark version and follow the device between them.
    var colorScheme: ColorScheme? {
        switch self {
        case .light, .sepia: .light
        case .dark, .black: .dark
        default: nil
        }
    }

    /// The page and card colors for the themes that bring their own; the others use the system's.
    func swatch(for scheme: ColorScheme) -> Swatch? {
        let dark = scheme == .dark
        return switch self {
        case .dark: Swatch(canvas: Color(white: 0.15), surface: Color(white: 0.21))
        case .black: Swatch(canvas: .black, surface: Color(white: 0.09))
        case .sepia: Swatch(canvas: Color(red: 0.957, green: 0.925, blue: 0.847), surface: Color(red: 0.984, green: 0.965, blue: 0.918))
        case .butter: dark ? Swatch("2A2414", "3A321D", accent: "D9772F") : Swatch("FBF0C8", "FFF9E6", accent: AccentPreset.rust)
        case .linen: dark ? Swatch("22201C", "302D28", accent: "E0533A") : Swatch("EEE8DC", "F8F5EE", accent: AccentPreset.cherry)
        case .olive: dark ? Swatch("23241D", "31322A", accent: "999C66") : Swatch("EDEBE0", "F7F6F0", accent: AccentPreset.olive)
        case .rose: dark ? Swatch("2A1A1D", "3A2528", accent: "D46A7A") : Swatch("F6E2DE", "FCF1EF", accent: AccentPreset.burgundy)
        case .crema: dark ? Swatch("29231A", "383024", accent: "E07250") : Swatch("F2E7CB", "FAF5E8", accent: AccentPreset.paprika)
        case .mint: dark ? Swatch("1C241E", "28322A", accent: "7FA877") : Swatch("E4EBDD", "F4F7F0", accent: AccentPreset.mint)
        case .blueberry: dark ? Swatch("1B1D2E", "272A40", accent: "6E8FEA") : Swatch("E6E8F3", "F4F5FB", accent: AccentPreset.blueberry)
        case .chai: dark ? Swatch("2E1412", "441E1A", accent: AccentPreset.cinnamon) : Swatch("F4E6E1", "FBF3F0", accent: "9B3025")
        case .cocoa: dark ? Swatch("2A1C15", "3B2820", accent: AccentPreset.caramel) : Swatch("F1E6DA", "FAF4EE", accent: "84592B")
        case .system, .light, .custom: nil
        }
    }

    /// The palette themes come with an accent; choosing one sets it, and it can still be changed after.
    var accentHex: String? {
        switch self {
        case .butter: AccentPreset.rust
        case .linen: AccentPreset.cherry
        case .olive: AccentPreset.olive
        case .rose: AccentPreset.burgundy
        case .crema: AccentPreset.paprika
        case .mint: AccentPreset.mint
        case .blueberry: AccentPreset.blueberry
        case .chai: AccentPreset.cinnamon
        case .cocoa: AccentPreset.caramel
        default: nil
        }
    }

    /// While the theme's own accent is chosen, it shifts with the page so it stays readable in light and dark.
    func accentHex(chosen: String, for scheme: ColorScheme) -> String {
        guard let own = accentHex, chosen.caseInsensitiveCompare(own) == .orderedSame else { return chosen }
        return swatch(for: scheme)?.accentHex ?? chosen
    }

    func palette(for scheme: ColorScheme) -> ThemePalette {
        let swatch = swatch(for: scheme)
        return ThemePalette(colorScheme: colorScheme, canvas: swatch?.canvas, surface: swatch?.surface)
    }
}

struct Swatch {
    var canvas: Color
    /// Cards, rows and fields sitting on the canvas.
    var surface: Color
    var accentHex: String?
}

extension Swatch {
    init(_ canvasHex: String, _ surfaceHex: String, accent: String) {
        self.init(canvas: Color(hex: canvasHex) ?? .clear, surface: Color(hex: surfaceHex) ?? .clear, accentHex: accent)
    }
}

/// The colors a screen paints with, so the Custom theme reads exactly like the built-in ones.
struct ThemePalette {
    var colorScheme: ColorScheme?
    var canvas: Color?
    var surface: Color?

    static let system = ThemePalette()
}

enum CustomTheme {
    static let defaultCanvasHex = "F4ECD8"
    static let defaultSurfaceHex = "FBF6EA"
}

enum FontStyle: String, CaseIterable, Identifiable {
    case serif, sans, rounded, monospaced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .serif: "Serif"
        case .sans: "Sans Serif"
        case .rounded: "Rounded"
        case .monospaced: "Monospaced"
        }
    }

    var design: Font.Design {
        switch self {
        case .serif: .serif
        case .sans: .default
        case .rounded: .rounded
        case .monospaced: .monospaced
        }
    }
}

struct AccentPreset: Identifiable {
    let name: String
    let hex: String

    var id: String { hex }
    var color: Color { Color(hex: hex) ?? .red }

    static let blueberry = "3B6FD6"
    static let rust = "BA3801"
    static let cherry = "C8250C"
    static let olive = "7D7F52"
    static let burgundy = "80202E"
    static let paprika = "C54F2D"
    static let mint = "5F8A57"
    static let cinnamon = "D0845A"
    static let caramel = "CF954A"

    static let all = [
        AccentPreset(name: "Tomato", hex: Theme.defaultAccentHex),
        AccentPreset(name: "Orange", hex: "E8802A"),
        AccentPreset(name: "Saffron", hex: "D9A011"),
        AccentPreset(name: "Basil", hex: "3E8E5A"),
        AccentPreset(name: "Teal", hex: "1F9D9A"),
        AccentPreset(name: "Blueberry", hex: blueberry),
        AccentPreset(name: "Plum", hex: "8E4FC1"),
        AccentPreset(name: "Rose", hex: "D6457F"),
        AccentPreset(name: "Graphite", hex: "5C6670"),
        AccentPreset(name: "Rust", hex: rust),
        AccentPreset(name: "Cherry", hex: cherry),
        AccentPreset(name: "Olive", hex: olive),
        AccentPreset(name: "Burgundy", hex: burgundy),
        AccentPreset(name: "Paprika", hex: paprika),
        AccentPreset(name: "Mint", hex: mint),
        AccentPreset(name: "Cinnamon", hex: cinnamon),
        AccentPreset(name: "Caramel", hex: caramel),
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

/// Applies the appearance, font and accent color chosen in Settings.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppSettings.Key.appearance) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.fontStyle) private var fontRaw = FontStyle.serif.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var accentHex = Theme.defaultAccentHex
    @AppStorage(AppSettings.Key.customThemeDark) private var customDark = false
    @AppStorage(AppSettings.Key.customThemeCanvas) private var customCanvasHex = CustomTheme.defaultCanvasHex
    @AppStorage(AppSettings.Key.customThemeSurface) private var customSurfaceHex = CustomTheme.defaultSurfaceHex
    @Environment(\.colorScheme) private var systemScheme

    private var appearance: Appearance { Appearance(rawValue: appearanceRaw) ?? .system }
    private var scheme: ColorScheme { appearance.colorScheme ?? systemScheme }

    private var palette: ThemePalette {
        guard appearance == .custom else { return appearance.palette(for: scheme) }
        return ThemePalette(colorScheme: customDark ? .dark : .light, canvas: Color(hex: customCanvasHex), surface: Color(hex: customSurfaceHex))
    }

    func body(content: Content) -> some View {
        let palette = palette
        let resolvedHex = appearance.accentHex(chosen: accentHex, for: scheme)
        let accent = Color(hex: resolvedHex) ?? Theme.defaultAccent
        content
            .environment(\.appearance, palette)
            .environment(\.appAccent, accent)
            .tint(accent)
            .fontDesign((FontStyle(rawValue: fontRaw) ?? .serif).design)
            .preferredColorScheme(palette.colorScheme)
            #if os(iOS) && !SHARE_EXTENSION
            .onChange(of: fontRaw, initial: true) { _, raw in ThemeFonts.apply(FontStyle(rawValue: raw) ?? .serif) }
            .onChange(of: resolvedHex, initial: true) { _, hex in ThemeTint.apply(Color(hex: hex) ?? Theme.defaultAccent) }
            #endif
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
    func themedCanvas() -> some View { modifier(ThemedCanvas()) }
}
