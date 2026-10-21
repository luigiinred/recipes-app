import SwiftUI

enum Theme {
    /// The tint applied at the root, so changing the accent color in Settings recolors everything that uses it.
    static let accent = Color.accentColor
    static let defaultAccentHex = "DB4738"
    static var defaultAccent: Color { Color(hex: defaultAccentHex) ?? .red }
}

enum Appearance: String, CaseIterable, Identifiable {
    case system, light, dark, black, sepia

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        case .black: "Pitch Black"
        case .sepia: "Sepia"
        }
    }

    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        case .black: "moon.fill"
        case .sepia: "book"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light, .sepia: .light
        case .dark, .black: .dark
        }
    }

    /// The page color for the themes that bring their own; the others use the system's.
    var canvas: Color? {
        switch self {
        case .black: .black
        case .sepia: Color(red: 0.957, green: 0.925, blue: 0.847)
        default: nil
        }
    }

    /// Cards, rows and fields sitting on the canvas.
    var surface: Color? {
        switch self {
        case .black: Color(white: 0.09)
        case .sepia: Color(red: 0.984, green: 0.965, blue: 0.918)
        default: nil
        }
    }
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

    static let all = [
        AccentPreset(name: "Tomato", hex: Theme.defaultAccentHex),
        AccentPreset(name: "Orange", hex: "E8802A"),
        AccentPreset(name: "Saffron", hex: "D9A011"),
        AccentPreset(name: "Basil", hex: "3E8E5A"),
        AccentPreset(name: "Teal", hex: "1F9D9A"),
        AccentPreset(name: "Blueberry", hex: "3B6FD6"),
        AccentPreset(name: "Plum", hex: "8E4FC1"),
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

/// Applies the appearance, font and accent color chosen in Settings.
private struct AppThemeModifier: ViewModifier {
    @AppStorage(AppSettings.Key.appearance) private var appearanceRaw = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.fontStyle) private var fontRaw = FontStyle.serif.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var accentHex = Theme.defaultAccentHex

    func body(content: Content) -> some View {
        let appearance = Appearance(rawValue: appearanceRaw) ?? .system
        content
            .environment(\.appearance, appearance)
            .tint(Color(hex: accentHex) ?? Theme.defaultAccent)
            .fontDesign((FontStyle(rawValue: fontRaw) ?? .serif).design)
            .preferredColorScheme(appearance.colorScheme)
            #if os(iOS) && !SHARE_EXTENSION
            .onChange(of: fontRaw, initial: true) { _, raw in ThemeFonts.apply(FontStyle(rawValue: raw) ?? .serif) }
            #endif
    }
}

private struct AppearanceKey: EnvironmentKey {
    static let defaultValue = Appearance.system
}

extension EnvironmentValues {
    var appearance: Appearance {
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
