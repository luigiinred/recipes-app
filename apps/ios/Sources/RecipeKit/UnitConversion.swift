import Foundation

/// Equivalent amounts of an ingredient in other units: "1 cup" is also "237 ml" and "16 tbsp".
extension Ingredient {
    /// Other ways to measure this amount, or empty for counts ("2 cloves"), ranges and items without a quantity.
    public var conversions: [String] {
        guard let unit, !quantity.contains(where: { $0 == "-" || $0 == "–" }),
              let value = Self.value(of: quantity), value > 0 else { return [] }
        if let milliliters = unit.milliliters {
            return Self.equivalents(
                of: value * milliliters, from: unit,
                us: [.teaspoon, .tablespoon, .fluidOunce, .cup, .quart, .gallon], base: { $0.milliliters },
                metric: (small: .milliliter, large: .liter, factor: 1000)
            )
        }
        if let grams = unit.grams {
            return Self.equivalents(
                of: value * grams, from: unit,
                us: [.ounce, .pound], base: { $0.grams },
                metric: (small: .gram, large: .kilogram, factor: 1000)
            )
        }
        return []
    }

    private static func equivalents(
        of total: Double, from source: IngredientUnit, us: [IngredientUnit], base: (IngredientUnit) -> Double?,
        metric: (small: IngredientUnit, large: IngredientUnit, factor: Double)
    ) -> [String] {
        var results: [String] = []
        for target in us where target != source {
            guard let size = base(target) else { continue }
            let amount = total / size
            let smallest = target == .quart || target == .gallon ? 1.0 : 0.25
            guard amount >= smallest, amount <= 32, let text = mixedNumber(amount) else { continue }
            results.append(text + " " + target.label(forQuantity: text))
        }
        let metricUnit = total >= metric.factor * (base(metric.small) ?? 1) ? metric.large : metric.small
        if metricUnit != source, let size = base(metricUnit) {
            let amount = total / size
            if amount >= 0.1 { results.append(metricText(amount, isLarge: metricUnit == metric.large) + " " + metricUnit.abbreviation) }
        }
        return results
    }

    /// Metric amounts read best with a few significant figures: "4.9 ml", "237 ml", "1.18 l".
    private static func metricText(_ amount: Double, isLarge: Bool) -> String {
        let rounded: Double
        if isLarge {
            rounded = (amount * 100).rounded() / 100
        } else {
            rounded = amount < 10 ? (amount * 2).rounded() / 2 : amount.rounded()
        }
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }

    private static let fractions: [(value: Double, text: String)] = [
        (0, ""), (1.0 / 8, "1/8"), (0.25, "1/4"), (1.0 / 3, "1/3"), (0.375, "3/8"), (0.5, "1/2"),
        (0.625, "5/8"), (2.0 / 3, "2/3"), (0.75, "3/4"), (0.875, "7/8"), (1, ""),
    ]

    /// "1 1/2" for 1.5, or nil when no common fraction is within 6% of the amount. Past 10 only halves are used.
    private static func mixedNumber(_ amount: Double) -> String? {
        var whole = amount.rounded(.down)
        let allowed = amount >= 10 ? fractions.filter { [0, 0.5, 1].contains($0.value) } : fractions
        guard let nearest = allowed.min(by: { abs($0.value - (amount - whole)) < abs($1.value - (amount - whole)) }) else { return nil }
        if nearest.value == 1 { whole += 1 }
        let approximate = nearest.value == 1 ? whole : whole + nearest.value
        guard approximate > 0, abs(approximate - amount) / amount <= 0.06 else { return nil }
        let fraction = nearest.value == 1 ? "" : nearest.text
        if whole == 0 { return fraction }
        return fraction.isEmpty ? String(Int(whole)) : "\(Int(whole)) \(fraction)"
    }
}

extension IngredientUnit {
    fileprivate var milliliters: Double? {
        switch self {
        case .teaspoon: 4.92892
        case .tablespoon: 14.7868
        case .fluidOunce: 29.5735
        case .cup: 236.588
        case .pint: 473.176
        case .quart: 946.353
        case .gallon: 3785.41
        case .milliliter: 1
        case .centiliter: 10
        case .deciliter: 100
        case .liter: 1000
        default: nil
        }
    }

    fileprivate var grams: Double? {
        switch self {
        case .milligram: 0.001
        case .gram: 1
        case .kilogram: 1000
        case .ounce: 28.3495
        case .pound: 453.592
        default: nil
        }
    }
}
