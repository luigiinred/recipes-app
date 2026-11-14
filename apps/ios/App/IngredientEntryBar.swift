import RecipeKit
import SwiftUI

/// Sits above the keyboard while an ingredient's quantity is being typed: fractions to tap, and Next to the ingredient.
struct IngredientEntryBar: View {
    @Binding var line: EditableIngredient
    let field: EditorField
    let onNext: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { fractionChips }.padding(.horizontal, 12)
            }
            .scrollClipDisabled()
            Button(action: onNext) {
                Label("Next", systemImage: "arrow.right").labelStyle(.titleAndIcon).appFont(.subheadline, weight: .semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accent)
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

    private func chip(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .appFont(.callout, weight: .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Color.secondary.opacity(0.15), in: Capsule())
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

/// The unit as a dropdown: a small popover with a search field, units matching it, units used before, and any typed unit.
struct UnitPicker: View {
    @Binding var unitText: String
    let onPick: () -> Void
    @State private var isOpen = false

    private var unit: IngredientUnit? { IngredientUnit(alias: unitText.trimmingCharacters(in: .whitespaces)) }

    var body: some View {
        Button { isOpen = true } label: {
            Text(unit?.abbreviation ?? (unitText.isEmpty ? "unit" : unitText))
                .foregroundStyle(unitText.isEmpty ? AnyShapeStyle(Color.secondary.opacity(0.6)) : AnyShapeStyle(Theme.accent))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Unit")
        .accessibilityValue(unitText.isEmpty ? "None" : unitText)
        .popover(isPresented: $isOpen) {
            UnitSearchList(current: unitText) { picked in
                unitText = picked
                isOpen = false
                onPick()
            }
            .frame(minWidth: 260, idealWidth: 280, minHeight: 320, idealHeight: 380)
            .presentationCompactAdaptation(.popover)
        }
    }
}

private struct UnitSearchList: View {
    let current: String
    let pick: (String) -> Void
    @State private var query = ""
    @FocusState private var searching: Bool

    var body: some View {
        let typed = query.trimmingCharacters(in: .whitespaces)
        let known = IngredientUnit.matching(typed)
        let custom = CustomUnits.matching(typed)
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search or type a unit", text: $query)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($searching)
                    .onSubmit {
                        guard !typed.isEmpty else { return }
                        pick(IngredientUnit(alias: typed)?.abbreviation ?? custom.first ?? known.first?.abbreviation ?? typed)
                    }
            }
            .padding(12)
            Divider()
            List {
                if typed.isEmpty { row("No unit", detail: nil, value: "") }
                ForEach(custom, id: \.self) { row($0, detail: "Used before", value: $0) }
                ForEach(known) { unit in row(unit.abbreviation, detail: unit.title, value: unit.abbreviation) }
                if !typed.isEmpty, IngredientUnit(alias: typed) == nil, !custom.contains(where: { $0.caseInsensitiveCompare(typed) == .orderedSame }) {
                    row("Use “\(typed)”", detail: "Any unit you type", value: typed)
                }
            }
            .listStyle(.plain)
        }
        .onAppear { searching = true }
    }

    private func row(_ title: String, detail: String?, value: String) -> some View {
        Button { pick(value) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).foregroundStyle(.primary)
                    if let detail, detail.lowercased() != title.lowercased() {
                        Text(detail).appFont(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if value.caseInsensitiveCompare(current) == .orderedSame { Image(systemName: "checkmark").foregroundStyle(Theme.accent) }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
