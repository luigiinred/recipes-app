import Foundation

extension Ingredient {
    /// The ingredient for a bigger or smaller batch: "1 1/2 cups flour" doubled is "3 cups flour".
    /// Ranges scale at both ends, and items without a readable quantity stay as written.
    public func scaled(by factor: Double) -> Ingredient {
        guard factor > 0, factor != 1, let ends = Self.rangeEnds(of: quantity) else { return self }
        var scaled = self
        let isRange = quantity.contains { $0 == "-" || $0 == "–" }
        let lower = Self.scaledText(ends.lower * factor)
        scaled.quantity = isRange ? lower + "-" + Self.scaledText(ends.upper * factor) : lower
        return scaled
    }

    private static func scaledText(_ value: Double) -> String {
        if let text = mixedNumber(value) { return text }
        let rounded = value < 10 ? (value * 10).rounded() / 10 : value.rounded()
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}

extension Recipe {
    /// The recipe made at `factor` times its written size: ingredient amounts and servings scale, steps don't.
    public func scaled(by factor: Double) -> Recipe {
        guard factor > 0, factor != 1 else { return self }
        var scaled = self
        scaled.ingredients = ingredients.map { Ingredient(parsing: $0).scaled(by: factor).text }
        scaled.servings = servings.map { max(1, Int((Double($0) * factor).rounded())) }
        return scaled
    }
}
