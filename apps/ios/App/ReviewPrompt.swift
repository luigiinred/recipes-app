import RecipeKit
import StoreKit
import SwiftUI

enum ReviewPrompt {
    static let recipeThreshold = 5

    static func isDue(recipes: [Recipe], onboarded: Bool, dismissed: Bool) -> Bool {
        onboarded && !dismissed && recipes.filter { !$0.isIdea }.count >= recipeThreshold
    }
}

struct ReviewPromptBanner: View {
    @Environment(\.requestReview) private var requestReview
    @AppStorage(AppSettings.Key.reviewPromptDismissed) private var dismissed = false

    var body: some View {
        HStack(spacing: 8) {
            Button {
                dismissed = true
                requestReview()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "star.bubble.fill").foregroundStyle(Theme.accent)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Rate us").font(.subheadline.weight(.semibold))
                        Text("Help other cooks find Recipes").font(.caption).foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { dismissed = true } label: {
                Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(.secondary).padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 16)
    }
}

#if os(iOS)
private struct ReviewPromptAccessory: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.onboardingCompleted) private var onboarded = false
    @AppStorage(AppSettings.Key.reviewPromptDismissed) private var dismissed = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.1, *), sizeClass != .regular {
            content.tabViewBottomAccessory(isEnabled: ReviewPrompt.isDue(recipes: library.recipes, onboarded: onboarded, dismissed: dismissed)) {
                ReviewPromptBanner()
            }
        } else {
            content
        }
    }
}

/// iPad shows the banner at the bottom of the recipe list, so it never changes the tab view's own safe area.
private struct ReviewPromptInset: ViewModifier {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.onboardingCompleted) private var onboarded = false
    @AppStorage(AppSettings.Key.reviewPromptDismissed) private var dismissed = false

    func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom) {
            if ReviewPrompt.isDue(recipes: library.recipes, onboarded: onboarded, dismissed: dismissed) {
                ReviewPromptBanner().padding(.vertical, 8)
            }
        }
    }
}

extension View {
    func reviewPrompt() -> some View { modifier(ReviewPromptAccessory()) }
    func reviewPromptInset() -> some View { modifier(ReviewPromptInset()) }
}
#endif
