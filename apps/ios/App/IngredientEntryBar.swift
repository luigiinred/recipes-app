import RecipeKit
import SwiftUI

/// Sits above the keyboard while an ingredient's quantity or unit is being typed: fractions to tap, units to search, and Next.
struct IngredientEntryBar: View {
    @Binding var line: EditableIngredient
    let field: EditorField
    let onNext: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if case .quantity = field { fractionChips } else { unitChips }
                }
                .padding(.horizontal, 12)
            }
            .scrollClipDisabled()
            Button(action: onNext) {
                Label(isQuantity ? "Unit" : "Item", systemImage: "arrow.right")
                    .labelStyle(.titleAndIcon)
                    .appFont(.subheadline, weight: .semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
            .accessibilityLabel(isQuantity ? "Next: unit" : "Next: ingredient")
            #if os(iOS)
            Button(action: onDone) { Image(systemName: "keyboard.chevron.compact.down") }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Hide keyboard")
            #endif
        }
        .padding(.vertical, 8)
        .padding(.trailing, 12)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    private var isQuantity: Bool {
        if case .quantity = field { return true }
        return false
    }

    private static let fractions = ["1/2", "1/4", "3/4", "1/3", "2/3", "1/8"]
    private static let glyphs = ["1/2": "½", "1/4": "¼", "3/4": "¾", "1/3": "⅓", "2/3": "⅔", "1/8": "⅛"]

    @ViewBuilder
    private var fractionChips: some View {
        ForEach(Self.fractions, id: \.self) { fraction in
            chip(Self.glyphs[fraction] ?? fraction) { line.quantity = Self.adding(fraction, to: line.quantity) }
                .accessibilityLabel(fraction)
        }
        chip("to") { line.quantity = line.quantity.trimmingCharacters(in: .whitespaces) + "-" }
            .accessibilityLabel("Range")
    }

    @ViewBuilder
    private var unitChips: some View {
        let typed = line.unitText.trimmingCharacters(in: .whitespaces)
        let known = IngredientUnit.matching(typed)
        let custom = CustomUnits.matching(typed)
        if !typed.isEmpty, line.unit == nil, !custom.contains(where: { $0.caseInsensitiveCompare(typed) == .orderedSame }) {
            chip("Use “\(typed)”", selected: true) { onNext() }
        }
        if !typed.isEmpty || line.unit != nil {
            chip("No unit") { line.unitText = ""; onNext() }
        }
        ForEach(custom, id: \.self) { name in
            chip(name, selected: name.caseInsensitiveCompare(typed) == .orderedSame) { line.unitText = name; onNext() }
        }
        ForEach(known) { unit in
            chip(unit.abbreviation, selected: unit == line.unit) { line.unitText = unit.abbreviation; onNext() }
                .accessibilityLabel(unit.title)
        }
    }

    private func chip(_ title: String, selected: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(.callout, weight: .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .background(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary.opacity(0.15)), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// "1" and "1/2" make "1 1/2"; tapping another fraction swaps the last one instead of stacking them.
    static func adding(_ fraction: String, to quantity: String) -> String {
        var text = quantity.trimmingCharacters(in: .whitespaces)
        if text.isEmpty || text.hasSuffix("-") { return text + fraction }
        let lastStart = text.lastIndex { $0 == " " || $0 == "-" }.map { text.index(after: $0) } ?? text.startIndex
        if text[lastStart...].contains("/") || text[lastStart...].contains(".") {
            text.removeSubrange(lastStart...)
            if text.isEmpty || text.hasSuffix("-") { return text + fraction }
            return text.trimmingCharacters(in: .whitespaces) + " " + fraction
        }
        return text + " " + fraction
    }
}

/// Units the user has typed that the app doesn't know, kept so they're offered again and read back out of saved ingredients.
enum CustomUnits {
    private static let key = "customIngredientUnits"
    private static let limit = 40

    static var all: [String] { UserDefaults.standard.stringArray(forKey: key) ?? [] }

    static func matching(_ query: String) -> [String] {
        let query = query.lowercased().trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? all : all.filter { $0.lowercased().contains(query) }
    }

    static func remember(_ units: [String]) {
        guard !units.isEmpty else { return }
        var list = all
        for unit in units.reversed() {
            list.removeAll { $0.caseInsensitiveCompare(unit) == .orderedSame }
            list.insert(unit, at: 0)
        }
        UserDefaults.standard.set(Array(list.prefix(limit)), forKey: key)
    }
}
