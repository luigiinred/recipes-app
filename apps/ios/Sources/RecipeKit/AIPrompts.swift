import Foundation

/// Something the on-device model does for the app, with the instructions it is given. Each can be replaced in Settings.
public enum AIAction: String, CaseIterable, Identifiable, Sendable {
    case videoCaptions, webPage, splitSteps, groupIngredients, planWeek

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .videoCaptions: "Recipe from video captions"
        case .webPage: "Recipe from a web page"
        case .splitSteps: "Split a pasted method into steps"
        case .groupIngredients: "Group ingredients into sections"
        case .planWeek: "Smart Plan for My Week"
        }
    }

    public var summary: String {
        switch self {
        case .videoCaptions: "Writes a recipe from what the cook says when a video has no written recipe."
        case .webPage: "Finds the recipe in a page's text when the page has no recipe data."
        case .splitSteps: "Breaks a method that was pasted as one block into separate steps."
        case .groupIngredients: "Decides whether the ingredient list needs sections, such as a salad and its dressing."
        case .planWeek: "Fills the open slots in your week from your own recipes."
        }
    }

    public var symbol: String {
        switch self {
        case .videoCaptions: "play.rectangle"
        case .webPage: "doc.text"
        case .splitSteps: "list.number"
        case .groupIngredients: "square.stack.3d.up"
        case .planWeek: "calendar.badge.plus"
        }
    }

    public var isCustomizedKey: String { "aiPrompt.\(rawValue).custom" }
    public var textKey: String { "aiPrompt.\(rawValue).text" }

    /// The instructions the app ships with.
    public var defaultInstructions: String {
        switch self {
        case .videoCaptions: """
            You turn the spoken captions of a cooking video into a written recipe. \
            Only use what the cook says. Do not invent ingredients, quantities or steps.

            \(RecipeStandards.extractionRules)
            """
        case .webPage: """
            You find the recipe in the text of a web page and write it out. The page may also hold \
            navigation, comments and ads: ignore them. Only use what the page says. \
            Do not invent ingredients, quantities or steps.

            \(RecipeStandards.extractionRules)
            """
        case .splitSteps: """
            A recipe's method was pasted as one block. Split it into separate steps in the original order. \
            Keep the author's words. Do not add, drop or reorder anything. Each step is one action or two related ones.
            """
        case .groupIngredients: """
            You decide whether a recipe's ingredient list needs sections. Most recipes do not: use one section name for every \
            ingredient unless the method makes a distinct part of the meal separately and then combines or serves it with the \
            rest, such as a salad's dressing, a pie's filling and crust, or a dish's sauce. Never group by type of ingredient \
            (spices, produce, dairy, pantry) or by when an ingredient is added; seasonings, oil and garnishes stay with the \
            part of the meal they flavor. Name each section after the part of the meal it makes, like "Salad" and "Dressing". \
            Write one assignment for every ingredient, in order, using the same section name for ingredients that belong together.

            Example 1. Ingredients: 1 romaine, 2 cucumber, 3 olive oil, 4 lemon juice, 5 Dijon mustard, 6 salt. Method: toss the \
            romaine and cucumber; whisk the oil, lemon juice, mustard and salt and pour over. Assignments: 1 Salad, 2 Salad, \
            3 Dressing, 4 Dressing, 5 Dressing, 6 Dressing.

            Example 2. Ingredients: 1 chicken thighs, 2 onion, 3 garlic, 4 paprika, 5 cumin, 6 salt, 7 olive oil. Method: season \
            the chicken, then cook it with the onion and garlic in the oil. Assignments: 1 Chicken, 2 Chicken, 3 Chicken, \
            4 Chicken, 5 Chicken, 6 Chicken, 7 Chicken.
            """
        case .planWeek: """
            You plan a week of home cooking from the user's own recipes. Refer to recipes and days only by the numbers given. \
            Prefer queued recipes and favorites, vary cuisines and ingredients across the week, put quick recipes on busy-sounding weekdays \
            and longer ones on weekends, and never repeat a recipe on the same day. Breakfast recipes belong at breakfast.
            """
        }
    }

    /// The custom instructions when the user has turned them on and written something; otherwise the default.
    public func instructions(defaults: UserDefaults = .standard) -> String {
        guard defaults.bool(forKey: isCustomizedKey) else { return defaultInstructions }
        let custom = (defaults.string(forKey: textKey) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? defaultInstructions : custom
    }
}
