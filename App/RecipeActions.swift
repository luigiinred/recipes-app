import RecipeKit
import SwiftUI

extension AppSettings {
    static var ratingStyle: RatingStyle {
        RatingStyle(rawValue: UserDefaults.standard.string(forKey: Key.ratingStyle) ?? "") ?? .favorites
    }
}

struct StarRatingView: View {
    let rating: Int?
    var size: CGFloat = 22
    var onChange: ((Int?) -> Void)?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...5, id: \.self) { star in
                let filled = star <= (rating ?? 0)
                Image(systemName: filled ? "star.fill" : "star")
                    .font(.system(size: size))
                    .foregroundStyle(filled ? Theme.accent : Color.secondary.opacity(0.5))
                    .contentShape(Rectangle())
                    .onTapGesture { onChange?(rating == star ? nil : star) }
                    .symbolEffect(.bounce, value: rating == star)
            }
        }
        .animation(.snappy, value: rating)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating")
        .accessibilityValue(rating.map { "\($0) of 5 stars" } ?? "Not rated")
        .accessibilityAdjustableAction { direction in
            guard let onChange else { return }
            let current = rating ?? 0
            switch direction {
            case .increment: onChange(min(current + 1, 5))
            case .decrement: onChange(current <= 1 ? nil : current - 1)
            @unknown default: break
            }
        }
    }
}

/// The liked-recipe and queue actions shared by context menus.
struct RecipeQuickActions: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.ratingStyle) private var styleRaw = RatingStyle.favorites.rawValue
    let recipe: Recipe

    var body: some View {
        if (RatingStyle(rawValue: styleRaw) ?? .favorites) == .favorites {
            Button(recipe.isFavorite ? "Remove Favorite" : "Favorite", systemImage: recipe.isFavorite ? "heart.slash" : "heart") {
                Task { await library.setFavorite(recipe, !recipe.isFavorite) }
            }
        } else {
            RatingMenu(recipe: recipe)
        }
        Button(recipe.wantToCook ? "Remove from Up Next" : "Add to Up Next", systemImage: recipe.wantToCook ? "minus.circle" : "text.line.first.and.arrowtriangle.forward") {
            Task { await library.setQueued(recipe, !recipe.wantToCook) }
        }
    }
}

struct RatingMenu: View {
    @EnvironmentObject private var library: RecipeLibrary
    let recipe: Recipe

    var body: some View {
        Menu("Rate", systemImage: recipe.rating == nil ? "star" : "star.fill") {
            ForEach((1...5).reversed(), id: \.self) { stars in
                Button {
                    Task { await library.setRating(recipe, stars) }
                } label: {
                    if recipe.rating == stars { Label("\(stars) Stars", systemImage: "checkmark") } else { Text("\(stars) \(stars == 1 ? "Star" : "Stars")") }
                }
            }
            if recipe.rating != nil {
                Divider()
                Button("Clear Rating", systemImage: "star.slash") { Task { await library.setRating(recipe, nil) } }
            }
        }
    }
}
