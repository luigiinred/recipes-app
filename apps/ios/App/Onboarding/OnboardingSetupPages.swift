import RecipeKit
import SwiftUI
import UserNotifications

// MARK: Pieces

struct OnboardingHeader: View {
    var character: MascotCharacter?
    var scene = MascotScene.idle
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 12) {
            if let character { MascotView(character: character, scene: scene, height: 130) }
            Text(title)
                .appFont(.largeTitle, weight: .bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(subtitle)
                .appFont(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

struct OnboardingFeature: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: symbol)
                .appFont(.title2)
                .foregroundStyle(Theme.accent)
                .frame(width: 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).appFont(.headline)
                Text(detail).appFont(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A rounded group of rows, like a settings section.
private struct OnboardingPanel<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct OnboardingToggle: View {
    let symbol: String
    let title: String
    let detail: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).appFont(.body)
                    Text(detail).appFont(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: symbol).foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 10)
    }
}

// MARK: Home

#if os(iOS)
struct OnboardingHomePage: View {
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.homeSections) private var orderRaw = ""
    @AppStorage(AppSettings.Key.hiddenHomeSections) private var hiddenRaw = ""

    var body: some View {
        let hidden = HomeSection.hidden(hiddenRaw, order: orderRaw)
        VStack(spacing: 24) {
            OnboardingHeader(character: .tomato, scene: .wave, title: "Build your Home",
                             subtitle: "Choose what Home shows. You can drag them into a different order in Settings.")
            OnboardingPanel {
                ForEach(HomeSection.order(orderRaw)) { section in
                    OnboardingToggle(
                        symbol: section.symbol, title: section.title, detail: detail(section),
                        isOn: Binding(
                            get: { !hidden.contains(section) },
                            set: { (orderRaw, hiddenRaw) = HomeSection.showing(section, $0, order: orderRaw, hidden: hiddenRaw) }
                        )
                    )
                    if section != HomeSection.order(orderRaw).last { Divider() }
                }
            }
        }
    }

    private func detail(_ section: HomeSection) -> String {
        section == .discover && discover.sources.isEmpty ? "Mealie servers shared with you. You can add one in a moment." : section.detail
    }
}
#endif

// MARK: Tabs

struct OnboardingTabsPage: View {
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenRaw = ""

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeader(character: .chili, scene: .hop, title: "Pick your tabs",
                             subtitle: "Home and Settings always show. Hiding a tab keeps everything in it.")
            OnboardingPanel {
                ForEach(MainTab.allCases, id: \.self) { tab in
                    OnboardingToggle(
                        symbol: tab.symbol, title: tab.title, detail: Self.detail(tab),
                        isOn: Binding(
                            get: { !AppSettings.hiddenTabs(hiddenRaw).contains(tab) },
                            set: { hiddenRaw = AppSettings.showing(tab, $0, hidden: hiddenRaw) }
                        )
                    )
                    if tab != MainTab.allCases.last { Divider() }
                }
            }
        }
    }

    private static func detail(_ tab: MainTab) -> String {
        switch tab {
        case .feeds: "New posts from the recipe sites you follow."
        case .upNext: "The recipes you've queued to cook soon."
        case .plan: "Your week of meals."
        case .groceries: "A shopping list that can sync with Reminders."
        }
    }
}

// MARK: Feeds

struct OnboardingFeedsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var adding = false

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeader(character: .lemon, scene: .idle, title: "Follow some cooks",
                             subtitle: "Their newest recipes show up in Feeds. Tap a few to follow them.")
            VStack(alignment: .leading, spacing: 18) {
                ForEach(PopularFeed.Kind.allCases, id: \.self) { kind in
                    let feeds = OnboardingFeeds.picks.filter { $0.kind == kind }
                    if !feeds.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(kind.rawValue).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
                            FlowLayout(spacing: 8) {
                                ForEach(feeds) { chip($0) }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Button { adding = true } label: { Label("Add a Site or Feed…", systemImage: "plus") }
                .buttonStyle(.bordered)
            Text("More feeds are in Settings, under Feeds.")
                .appFont(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .sheet(isPresented: $adding) { AddFeedSheet() }
    }

    private func chip(_ popular: PopularFeed) -> some View {
        let followed = library.feeds.first { $0.url == popular.url }
        return Button {
            Task {
                if let followed { await library.remove(followed) } else { await library.add(Feed(url: popular.url, title: popular.name)) }
            }
        } label: {
            Label(popular.name, systemImage: followed == nil ? "plus" : "checkmark")
                .appFont(.subheadline, weight: .medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .foregroundStyle(followed == nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.white))
                .background(followed == nil ? AnyShapeStyle(Color.primary.opacity(0.06)) : AnyShapeStyle(Theme.accent), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(popular.name)
        .accessibilityAddTraits(followed == nil ? .isButton : [.isButton, .isSelected])
        .sensoryFeedback(.selection, trigger: followed == nil)
    }
}

// MARK: Discover

struct OnboardingDiscoverPage: View {
    @EnvironmentObject private var discover: DiscoverController
    #if os(iOS)
    @AppStorage(AppSettings.Key.homeSections) private var homeOrderRaw = ""
    @AppStorage(AppSettings.Key.hiddenHomeSections) private var hiddenHomeRaw = ""
    #endif
    @State private var adding = false

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeader(character: .potato, scene: .idle, title: "Browse a shared server",
                             subtitle: "If a friend shares their Mealie server, look through its recipes on Home and save the ones you like.")
            VStack(alignment: .leading, spacing: 12) {
                Label("Discover", systemImage: "binoculars").appFont(.headline).foregroundStyle(Theme.accent)
                Text("Recipes only reads from these servers. If nobody has shared one with you, just continue.")
                    .appFont(.subheadline).foregroundStyle(.secondary)
                ForEach(discover.sources) { source in
                    Label(source.name, systemImage: "checkmark.circle.fill")
                        .appFont(.subheadline, weight: .semibold)
                        .foregroundStyle(Theme.accent)
                }
                Button { adding = true } label: { Label("Add Discover Server", systemImage: "plus") }
                    .buttonStyle(.bordered)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .sheet(isPresented: $adding) { AddDiscoverSheet() }
        .onChange(of: discover.sources.count) { old, new in
            #if os(iOS)
            if new > old { (homeOrderRaw, hiddenHomeRaw) = HomeSection.showing(.discover, true, order: homeOrderRaw, hidden: hiddenHomeRaw) }
            #endif
        }
    }
}

// MARK: Look

struct OnboardingLookPage: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.colorTheme) private var themeRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var accentHex = Theme.defaultAccentHex
    @Environment(\.colorScheme) private var scheme

    private var theme: ColorTheme { ColorTheme(rawValue: themeRaw) ?? .classic }

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeader(title: "Pick a look", subtitle: "Light or dark, a color for the pages, and an accent for buttons and ratings.")
            ThemePreview()
                .padding(16)
                .background(.background, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
            section("Appearance") {
                ThemeTileRow {
                    ForEach(Appearance.allCases) { mode in
                        ThemeTile(title: mode.title, isSelected: appearance == mode.rawValue) {
                            appearance = mode.rawValue
                        } thumbnail: {
                            appearanceThumbnail(mode)
                        }
                    }
                }
            }
            section("Color") {
                ThemeTileRow {
                    ForEach(ColorTheme.colors) { option in
                        ThemeTile(title: option.title, isSelected: theme == option) {
                            themeRaw = option.rawValue
                        } thumbnail: {
                            ThemeThumbnail(swatch: option.previewSwatch(for: scheme, classicAccent: accentHex), scheme: scheme)
                        }
                    }
                }
            }
            if theme == .classic {
                section("Accent") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        ForEach(AccentPreset.all) { preset in
                            let isSelected = accentHex.caseInsensitiveCompare(preset.hex) == .orderedSame
                            Button { accentHex = preset.hex } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if isSelected { Image(systemName: "checkmark").appFont(.footnote, weight: .bold).foregroundStyle(.white) }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(preset.name)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
            }
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).appFont(.subheadline, weight: .semibold).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func appearanceThumbnail(_ mode: Appearance) -> some View {
        let light = ThemeThumbnail(swatch: theme.previewSwatch(for: .light, classicAccent: accentHex), scheme: .light)
        let dark = ThemeThumbnail(swatch: theme.previewSwatch(for: .dark, classicAccent: accentHex), scheme: .dark)
        switch mode {
        case .light: light
        case .dark: dark
        case .system: light.overlay { dark.mask(DiagonalHalf()) }
        }
    }
}

// MARK: Reminders

struct OnboardingRemindersPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.reminderOn(.logDinner)) private var logOn = false
    @AppStorage(AppSettings.Key.reminderOn(.planWeek)) private var planOn = false
    @AppStorage(AppSettings.Key.reminderOn(.addRecipe)) private var addOn = false
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(spacing: 24) {
            OnboardingHeader(character: .lemon, scene: .hop, title: "Want a nudge?",
                             subtitle: "Reminders stay off unless you turn them on. Change the times in Settings.")
            OnboardingPanel {
                OnboardingToggle(symbol: "fork.knife", title: "Log dinner", detail: "Every day at \(Self.time(.logDinner)).", isOn: $logOn)
                Divider()
                OnboardingToggle(symbol: "calendar", title: "Plan next week", detail: "\(Self.day(.planWeek)) at \(Self.time(.planWeek)).", isOn: $planOn)
                Divider()
                OnboardingToggle(symbol: "plus.circle", title: "Add a recipe", detail: "\(Self.day(.addRecipe)) at \(Self.time(.addRecipe)).", isOn: $addOn)
            }
            if authorization == .denied {
                Text("Notifications are off for Recipes in system settings, so these won't appear.")
                    .appFont(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .task { authorization = await ReminderCenter.shared.authorization }
        .onChange(of: [logOn, planOn, addOn]) { _, new in
            Task {
                if new.contains(true), await ReminderCenter.shared.authorization == .notDetermined {
                    _ = await ReminderCenter.shared.requestAuthorization()
                }
                authorization = await ReminderCenter.shared.authorization
                await ReminderCenter.shared.reschedule(plan: library.mealPlan, recipes: library.recipes)
            }
        }
    }

    private static func time(_ kind: ReminderKind) -> String {
        let minutes = AppSettings.reminderPreferences()[kind].minutes
        let date = Calendar.current.date(byAdding: .minute, value: minutes, to: Calendar.current.startOfDay(for: Date())) ?? Date()
        return date.formatted(date: .omitted, time: .shortened)
    }

    private static func day(_ kind: ReminderKind) -> String {
        let weekday = AppSettings.reminderPreferences()[kind].weekday
        return Calendar.current.weekdaySymbols[(weekday - 1) % 7] + "s"
    }
}

// MARK: Done

struct OnboardingSummaryPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var discover: DiscoverController
    @AppStorage(AppSettings.Key.hiddenTabs) private var hiddenTabsRaw = ""
    #if os(iOS)
    @AppStorage(AppSettings.Key.homeSections) private var homeOrderRaw = ""
    @AppStorage(AppSettings.Key.hiddenHomeSections) private var hiddenHomeRaw = ""
    #endif
    @AppStorage(AppSettings.Key.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.colorTheme) private var themeRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.reminderOn(.logDinner)) private var logOn = false
    @AppStorage(AppSettings.Key.reminderOn(.planWeek)) private var planOn = false
    @AppStorage(AppSettings.Key.reminderOn(.addRecipe)) private var addOn = false

    var body: some View {
        VStack(spacing: 28) {
            VStack(spacing: 12) {
                MascotCluster(height: 150)
                Text("You're all set!")
                    .appFont(.largeTitle, weight: .bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                Text("Here's how Recipes is set up. Change any of it in Settings.")
                    .appFont(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 18) {
                OnboardingFeature(symbol: "book.closed", title: "Recipes", detail: recipes)
                #if os(iOS)
                OnboardingFeature(symbol: "house", title: "Home", detail: home)
                #endif
                OnboardingFeature(symbol: "square.grid.2x2", title: "Tabs", detail: tabs)
                OnboardingFeature(symbol: "dot.radiowaves.up.forward", title: "Feeds", detail: feeds)
                OnboardingFeature(symbol: "binoculars", title: "Discover", detail: discoverSummary)
                OnboardingFeature(symbol: "paintpalette", title: "Look", detail: look)
                OnboardingFeature(symbol: "bell", title: "Reminders", detail: reminders)
            }
            OnboardingFeature(symbol: "frying.pan", title: "When you're ready to cook",
                              detail: "Tap Cook on a recipe for big step-by-step text. Timers in the steps are found for you, and the screen stays awake.")
        }
    }

    private var recipes: String {
        switch library.recipes.count {
        case 0: "None yet. Paste a link or share one from Safari."
        case 1: "1 recipe saved."
        case let count: "\(count) recipes saved."
        }
    }

    #if os(iOS)
    private var home: String {
        let hidden = HomeSection.hidden(hiddenHomeRaw, order: homeOrderRaw)
        let shown = HomeSection.order(homeOrderRaw).filter { !hidden.contains($0) }.map(\.title)
        return shown.isEmpty ? "Nothing yet." : shown.formatted(.list(type: .and)) + "."
    }
    #endif

    private var tabs: String {
        let shown = MainTab.allCases.filter { !AppSettings.hiddenTabs(hiddenTabsRaw).contains($0) }.map(\.title)
        return (["Home"] + shown + ["Settings"]).formatted(.list(type: .and)) + "."
    }

    private var feeds: String {
        switch library.feeds.count {
        case 0: "Not following any yet."
        case 1: "Following \(library.feeds[0].title)."
        case let count: "Following \(count) feeds."
        }
    }

    private var discoverSummary: String {
        switch discover.sources.count {
        case 0: "No shared servers yet."
        case 1: "Browsing \(discover.sources[0].name)."
        case let count: "Browsing \(count) shared servers."
        }
    }

    private var look: String {
        let theme = ColorTheme(rawValue: themeRaw) ?? .classic
        let mode = Appearance(rawValue: appearance) ?? .system
        return "\(theme.title), \(mode == .system ? "following light and dark" : mode.title.lowercased())."
    }

    private var reminders: String {
        let on = [(logOn, "Log dinner"), (planOn, "Plan next week"), (addOn, "Add a recipe")].filter(\.0).map(\.1)
        return on.isEmpty ? "Off." : on.formatted(.list(type: .and)) + "."
    }
}
