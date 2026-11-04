import ImagePlayground
import RecipeKit
import SwiftUI
import UserNotifications

enum SettingsPage: Hashable {
    case recipes, planner, cooking, groceries, reminders, theme, discover, mealie, intelligence, data
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    var inSheet = true
    /// iPad: the pages sit in a sidebar next to the page you pick, instead of being pushed.
    var splitsPages = false
    /// Fixed Apple Intelligence state for previews and snapshots, so they don't depend on the machine.
    var intelligenceOverride: (status: AppleIntelligence.Status, imagePlayground: Bool)?
    var listing = AppStoreLink.listing
    var writeReview = AppStoreLink.writeReview

    @AppStorage(AppSettings.Key.discoverTab) private var showsDiscover = false
    @State private var showingTour = false
    @State private var page: SettingsPage? = .recipes

    var body: some View {
        Group {
            if splitsPages { split } else { stack }
        }
        .appTheme()
        #if os(iOS)
        .fullScreenCover(isPresented: $showingTour) { OnboardingView { showingTour = false } }
        #else
        .sheet(isPresented: $showingTour) { OnboardingView { showingTour = false } }
        #endif
        #if os(macOS)
        .frame(minWidth: 460, minHeight: 520)
        #endif
    }

    private var stack: some View {
        NavigationStack {
            Form { rows }
                .formStyle(.grouped)
                .settingsSpacing()
                .themedCanvas()
                .navigationTitle("Settings")
                #if os(iOS)
                .navigationBarTitleDisplayMode(inSheet ? .inline : .large)
                #endif
                .toolbar {
                    if inSheet { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
                }
                .navigationDestination(for: SettingsPage.self) { destination($0) }
        }
    }

    private var split: some View {
        NavigationSplitView {
            List(selection: $page) { rows }
                .settingsSpacing()
                .themedCanvas()
                .navigationTitle("Settings")
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 460)
                #if os(iOS)
                .toolbar(removing: .sidebarToggle)
                #endif
        } detail: {
            NavigationStack {
                if let page { destination(page) } else { ContentUnavailableView("Settings", systemImage: "gearshape") }
            }
        }
    }

    @ViewBuilder
    private var rows: some View {
        Section {
            NavigationLink(value: SettingsPage.recipes) { Label("Recipes", systemImage: "book.closed") }
            NavigationLink(value: SettingsPage.planner) { Label("Planner", systemImage: "calendar") }
            NavigationLink(value: SettingsPage.cooking) { Label("Cooking", systemImage: "frying.pan") }
            NavigationLink(value: SettingsPage.groceries) { Label("Groceries", systemImage: "checklist") }
            NavigationLink(value: SettingsPage.reminders) { Label("Reminders", systemImage: "bell") }
        }
        Section {
            NavigationLink(value: SettingsPage.theme) { Label("Theme", systemImage: "paintpalette") }
        }
        if showsDiscover {
            Section {
                NavigationLink(value: SettingsPage.discover) { Label("Discover Feeds", systemImage: "dot.radiowaves.up.forward") }
            }
        }
        Section {
            NavigationLink(value: SettingsPage.mealie) { Label("Mealie", systemImage: "server.rack") }
        } header: {
            Text("Sync")
        }
        Section {
            NavigationLink(value: SettingsPage.intelligence) { Label("Apple Intelligence", systemImage: "sparkles") }
        }
        Section {
            NavigationLink(value: SettingsPage.data) { Label("Data & Developer", systemImage: "externaldrive") }
        }
        if let listing, let writeReview {
            Section {
                Link(destination: writeReview) { Label("Leave a Review", systemImage: "star.bubble") }
                ShareLink(
                    item: listing,
                    message: Text("I keep all my recipes in Recipes. It's free, open source, and has no ads or account.")
                ) { Label("Tell a Friend Who Cooks", systemImage: "heart") }
            } header: {
                Text("Help Support Us")
            } footer: {
                Text("Recipes is free, open source, and will never show you an ad, so word of mouth is our whole marketing budget. A kind review is how the next home cook finds a recipe box that doesn't nag them.")
            }
        }
        Section {
            Link(destination: FeedbackLink.url(for: .bug)) { Label("Report a Bug", systemImage: "ladybug") }
            Link(destination: FeedbackLink.url(for: .feature)) { Label("Suggest a Change", systemImage: "lightbulb") }
        } header: {
            Text("Feedback")
        } footer: {
            Text("Opens a ready-to-fill GitHub issue with your app version and system already added. Nothing from your recipes is included. You'll need a free GitHub account to send it.")
        }
        Section {
            Button { showingTour = true } label: { Label("Show Welcome Tour", systemImage: "sparkles") }
            Link(destination: URL(string: "https://github.com/luigiinred/recipes-app")!) {
                Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    @ViewBuilder
    private func destination(_ page: SettingsPage) -> some View {
        switch page {
        case .recipes: RecipesSettingsPage()
        case .planner: PlannerSettingsPage()
        case .cooking: CookingSettingsPage()
        case .groceries: GroceriesSettingsPage()
        case .reminders: RemindersSettingsPage()
        case .theme: ThemeSettingsPage()
        case .discover: DiscoverFeedsPage()
        case .mealie: MealieSettingsPage()
        case .intelligence: IntelligenceSettingsPage(override: intelligenceOverride)
        case .data: DataSettingsPage()
        }
    }
}

private struct RecipesSettingsPage: View {
    @AppStorage(AppSettings.Key.listStyle) private var listStyle = RecipeListStyle.list
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyle = RatingStyle.favorites.rawValue
    @AppStorage(AppSettings.Key.reviewImports) private var reviewImports = true
    @AppStorage(AppSettings.Key.showDeleteSwipe) private var showDeleteSwipe = false
    @AppStorage(AppSettings.Key.recipeDetails) private var recipeDetailsRaw = RecipeDetail.raw(RecipeDetail.defaults)
    #if os(iOS)
    @AppStorage(AppSettings.Key.remembersSort) private var remembersSort = true
    @AppStorage(AppSettings.Key.defaultSort) private var defaultSort = RecipeSort.recent
    #endif

    var body: some View {
        Form {
            Section {
                Picker("Recipe list", selection: $listStyle) {
                    ForEach(RecipeListStyle.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                }
                Picker("Mark recipes with", selection: $ratingStyle) {
                    ForEach(RatingStyle.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } header: {
                Text("Browsing")
            } footer: {
                Text("Favorites are a heart on the recipes you love. Star ratings give each recipe one to five stars, and Top Rated lists the 4 and 5 star ones. Both are always in a recipe’s ⋯ menu, and switching never deletes either.")
            }
            Section {
                ForEach(RecipeDetail.allCases, id: \.self) { detail in
                    Toggle(isOn: Binding(
                        get: { RecipeDetail.parse(recipeDetailsRaw).contains(detail) },
                        set: { on in
                            var details = RecipeDetail.parse(recipeDetailsRaw)
                            if on { details.insert(detail) } else { details.remove(detail) }
                            recipeDetailsRaw = RecipeDetail.raw(details)
                        }
                    )) {
                        Label(detail.title, systemImage: detail.symbol)
                    }
                }
            } header: {
                Text("Recipe details")
            } footer: {
                Text("What shows under each recipe's title in cards and lists.")
            }
            #if os(iOS)
            Section {
                NavigationLink { QuickFiltersSettingsPage() } label: {
                    Label("Quick Filters", systemImage: "line.3.horizontal.decrease.circle")
                }
            } header: {
                Text("Search")
            } footer: {
                Text("The buttons above the search bar. Choose which filters and tags they show and in what order.")
            }
            Section {
                Toggle("Remember last sort", isOn: $remembersSort)
                if !remembersSort {
                    Picker("Default sort", selection: $defaultSort) {
                        ForEach(RecipeSort.allCases, id: \.self) { Label($0.title, systemImage: $0.symbol).tag($0) }
                    }
                }
            } header: {
                Text("Sorting")
            } footer: {
                Text(remembersSort
                     ? "The Recipes home keeps the last sort you chose."
                     : "The Recipes home opens sorted this way each time, and a sort you choose lasts until you leave the app.")
            }
            #endif
            Section {
                Toggle("Show Delete", isOn: $showDeleteSwipe)
            } header: {
                Text("Swipe actions")
            } footer: {
                Text("Swipe a recipe left for Up Next and Favorite. Turn this on to add Delete, which always asks before removing anything.")
            }
            Section {
                Toggle("Review before saving", isOn: $reviewImports)
            } header: {
                Text("Importing")
            } footer: {
                Text("Open the title and categories for a check after every import, including from the Share sheet.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Recipes")
    }
}

#if os(iOS)
/// Which quick filter chips the Search tab shows, in order: the built-in filters and any tags.
private struct QuickFiltersSettingsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @AppStorage(AppSettings.Key.quickChips) private var raw = QuickChip.raw(QuickChip.defaults)
    @AppStorage(AppSettings.Key.ratingStyle) private var ratingStyleRaw = RatingStyle.favorites.rawValue

    private var style: RatingStyle { RatingStyle(rawValue: ratingStyleRaw) ?? .favorites }
    private var chips: [QuickChip] { QuickChip.parse(raw) }

    var body: some View {
        List {
            Section {
                ForEach(chips, id: \.self) { chip in
                    Label(chip.title(style), systemImage: chip.symbol(style))
                }
                .onMove { from, to in
                    var chips = chips
                    chips.move(fromOffsets: from, toOffset: to)
                    raw = QuickChip.raw(chips)
                }
                .onDelete { offsets in
                    var chips = chips
                    chips.remove(atOffsets: offsets)
                    raw = QuickChip.raw(chips)
                }
            } header: {
                Text("Shown")
            } footer: {
                Text(chips.isEmpty ? "No quick filters show above the search bar." : "Drag to reorder. Filters that are on move to the front as icons.")
            }
            let filters = QuickFilter.allCases.map(QuickChip.filter).filter { !chips.contains($0) }
            if !filters.isEmpty {
                Section("Filters") {
                    ForEach(filters, id: \.self) { add($0) }
                }
            }
            let tags = flattened(library.categoryTree).map { QuickChip.tag($0.path) }.filter { !chips.contains($0) }
            if !tags.isEmpty {
                Section("Tags") {
                    ForEach(tags, id: \.self) { chip in
                        if case .tag(let path) = chip { add(chip, title: CategoryTree.displayName(path)) }
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
        .settingsPage("Quick Filters")
    }

    private func add(_ chip: QuickChip, title: String? = nil) -> some View {
        Button {
            withAnimation { raw = QuickChip.raw(chips + [chip]) }
        } label: {
            Label {
                Text(title ?? chip.title(style)).foregroundStyle(.primary)
            } icon: {
                Image(systemName: "plus.circle.fill").foregroundStyle(.green)
            }
        }
    }

    private func flattened(_ nodes: [CategoryNode]) -> [CategoryNode] {
        nodes.flatMap { [$0] + flattened($0.children) }
    }
}
#endif

private struct PlannerSettingsPage: View {
    @AppStorage(AppSettings.Key.defaultMeal) private var defaultMeal = MealChoice.automatic.rawValue
    @AppStorage(AppSettings.Key.hiddenMeals) private var hiddenMeals = ""
    @AppStorage(AppSettings.Key.weekStart) private var weekStart = AppSettings.WeekStart.system.rawValue

    var body: some View {
        Form {
            Section {
                Picker("Add recipes as", selection: $defaultMeal) {
                    ForEach(MealChoice.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            } footer: {
                Text("Automatic files a recipe under breakfast, lunch, a snack, or dinner based on the time of day. You can still change the meal whenever you add one. Recipes in Up Next leave the queue when you plan them.")
            }
            Section("My Week") {
                Picker("Week starts on", selection: $weekStart) {
                    ForEach(AppSettings.WeekStart.allCases, id: \.rawValue) { Text($0.title).tag($0.rawValue) }
                }
            }
            Section("Meals to plan") {
                ForEach(Meal.allCases, id: \.self) { meal in
                    Toggle(isOn: shown(meal)) { Label(meal.title, systemImage: meal.symbol) }
                }
            }
        }
        .formStyle(.grouped)
        .settingsPage("Planner")
    }

    private func shown(_ meal: Meal) -> Binding<Bool> {
        Binding(
            get: { !AppSettings.hiddenMeals(hiddenMeals).contains(meal) },
            set: { visible in
                var hidden = AppSettings.hiddenMeals(hiddenMeals)
                if visible { hidden.remove(meal) } else { hidden.insert(meal) }
                hiddenMeals = AppSettings.encode(hidden)
            }
        )
    }
}

private struct CookingSettingsPage: View {
    @AppStorage(AppSettings.Key.keepAwake) private var keepAwake = true

    var body: some View {
        Form {
            Section {
                Toggle("Keep the screen awake", isOn: $keepAwake)
            } header: {
                Text("Cook mode")
            } footer: {
                Text("Stops the screen from locking while you're following a recipe.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Cooking")
    }
}

private struct GroceriesSettingsPage: View {
    @EnvironmentObject private var library: RecipeLibrary

    var body: some View {
        Form {
            Section {
                Toggle("Sync with Reminders", isOn: Binding(
                    get: { library.remindersEnabled },
                    set: { value in Task { await library.setRemindersEnabled(value) } }
                ))
            } footer: {
                Text("Keeps your grocery list in a “Groceries” list in the Reminders app, in both directions.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Groceries")
    }
}

struct RemindersSettingsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @Environment(\.openURL) private var openURL
    @AppStorage(AppSettings.Key.reminderOn(.logDinner)) private var logOn = false
    @AppStorage(AppSettings.Key.reminderMinutes(.logDinner)) private var logMinutes = ReminderPreferences.defaultSetting(for: .logDinner).minutes
    @AppStorage(AppSettings.Key.reminderOn(.planWeek)) private var planOn = false
    @AppStorage(AppSettings.Key.reminderMinutes(.planWeek)) private var planMinutes = ReminderPreferences.defaultSetting(for: .planWeek).minutes
    @AppStorage(AppSettings.Key.reminderWeekday(.planWeek)) private var planWeekday = ReminderPreferences.defaultSetting(for: .planWeek).weekday
    @AppStorage(AppSettings.Key.reminderOn(.addRecipe)) private var addOn = false
    @AppStorage(AppSettings.Key.reminderMinutes(.addRecipe)) private var addMinutes = ReminderPreferences.defaultSetting(for: .addRecipe).minutes
    @AppStorage(AppSettings.Key.reminderWeekday(.addRecipe)) private var addWeekday = ReminderPreferences.defaultSetting(for: .addRecipe).weekday
    @State private var authorization: UNAuthorizationStatus = .notDetermined

    private var blocked: Bool { authorization == .denied }

    var body: some View {
        Form {
            Section {
                reminder("Log dinner", isOn: $logOn, minutes: $logMinutes, weekday: nil)
            } header: {
                Text("Every day")
            } footer: {
                Text("A nudge to log what you cooked. It names the dinner you planned, and stays quiet on days you've already logged something.")
            }
            Section {
                reminder("Plan next week", isOn: $planOn, minutes: $planMinutes, weekday: $planWeekday)
            } header: {
                Text("Planning")
            } footer: {
                Text("Skipped for any week that already has a few meals planned.")
            }
            Section {
                reminder("Add a recipe", isOn: $addOn, minutes: $addMinutes, weekday: $addWeekday)
            } header: {
                Text("Saving")
            } footer: {
                Text("A weekly reminder to save a recipe from a link, a photo, or a video.")
            }
            Section {
                Button("Turn All Off", role: .destructive) { logOn = false; planOn = false; addOn = false }
                    .disabled(!(logOn || planOn || addOn))
            } footer: {
                if blocked {
                    Text("Notifications are off for Recipes in system settings, so none of these will appear.")
                } else {
                    Text("Reminders are off until you turn one on. They stay on this device, and fade out on their own if you stop opening Recipes.")
                }
            }
            if blocked, let url = Self.systemSettingsURL {
                Section { Button("Open System Settings") { openURL(url) } }
            }
        }
        .formStyle(.grouped)
        .settingsPage("Reminders")
        .task { authorization = await ReminderCenter.shared.authorization }
        .onChange(of: [logOn, planOn, addOn]) { _, new in
            guard new.contains(true) else { return reschedule() }
            Task {
                if await ReminderCenter.shared.authorization == .notDetermined { _ = await ReminderCenter.shared.requestAuthorization() }
                authorization = await ReminderCenter.shared.authorization
                reschedule()
            }
        }
        .onChange(of: [logMinutes, planMinutes, planWeekday, addMinutes, addWeekday]) { reschedule() }
    }

    private func reschedule() {
        Task { await ReminderCenter.shared.reschedule(plan: library.mealPlan, recipes: library.recipes) }
    }

    @ViewBuilder
    private func reminder(_ title: String, isOn: Binding<Bool>, minutes: Binding<Int>, weekday: Binding<Int>?) -> some View {
        Toggle(title, isOn: isOn)
        if isOn.wrappedValue {
            if let weekday {
                Picker("Day", selection: weekday) {
                    ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) { Text($0.element).tag($0.offset + 1) }
                }
            }
            DatePicker("Time", selection: time(minutes), displayedComponents: .hourAndMinute)
        }
    }

    private func time(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Calendar.current.date(byAdding: .minute, value: minutes.wrappedValue, to: Calendar.current.startOfDay(for: Date())) ?? Date() },
            set: {
                let parts = Calendar.current.dateComponents([.hour, .minute], from: $0)
                minutes.wrappedValue = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            }
        )
    }

    private static var systemSettingsURL: URL? {
        #if os(iOS)
        URL(string: UIApplication.openNotificationSettingsURLString)
        #else
        URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
        #endif
    }
}

struct ThemeSettingsPage: View {
    @AppStorage(AppSettings.Key.appearance) private var appearance = Appearance.system.rawValue
    @AppStorage(AppSettings.Key.colorTheme) private var themeRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.fontStyle) private var fontStyle = FontStyle.serif.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var accentHex = Theme.defaultAccentHex
    @Environment(\.self) private var environment
    @Environment(\.colorScheme) private var scheme
    private var custom = StoredCustomTheme()

    private var theme: ColorTheme { ColorTheme(rawValue: themeRaw) ?? .classic }
    private var font: FontStyle { FontStyle(rawValue: fontStyle) ?? .serif }

    private var customAccent: Binding<Color> {
        Binding(
            get: { Color(hex: accentHex) ?? Theme.defaultAccent },
            set: { accentHex = $0.hex(in: environment) }
        )
    }

    var body: some View {
        Form {
            Section {
                ThemePreview().themedRow(raised: true)
            }
            Section {
                ThemeTileRow {
                    ForEach(Appearance.allCases) { mode in
                        ThemeTile(title: mode.title, isSelected: appearance == mode.rawValue) {
                            appearance = mode.rawValue
                        } thumbnail: {
                            appearanceThumbnail(mode)
                        }
                    }
                }
                .themedRow(raised: true)
            } header: {
                Text("Appearance")
            } footer: {
                Text("Auto follows your device between light and dark.")
            }
            Section {
                ThemeTileRow {
                    ForEach(ColorTheme.colors + [.custom]) { option in
                        ThemeTile(title: option.title, isSelected: theme == option) {
                            themeRaw = option.rawValue
                        } thumbnail: {
                            ThemeThumbnail(swatch: preview(option, scheme), scheme: scheme)
                        }
                    }
                }
                .themedRow(raised: true)
                NavigationLink { CustomThemePage() } label: { Label("Theme Creator", systemImage: "slider.horizontal.3") }
                    .themedRow(raised: true)
            } header: {
                Text("Color")
            } footer: {
                Text("Classic is plain white or black with an accent you pick. The other colors tint the page and cards and bring their own accent. Theme Creator makes a Custom one.")
            }
            if theme == .classic {
                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 12)], spacing: 12) {
                        ForEach(AccentPreset.all) { preset in
                            Button { accentHex = preset.hex } label: {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if accentHex.caseInsensitiveCompare(preset.hex) == .orderedSame {
                                            Image(systemName: "checkmark").appFont(.footnote, weight: .bold).foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(preset.name)
                            .accessibilityAddTraits(accentHex.caseInsensitiveCompare(preset.hex) == .orderedSame ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                    ColorPicker("Custom color", selection: customAccent, supportsOpacity: false)
                    Button("Reset to Tomato") { accentHex = Theme.defaultAccentHex }
                        .disabled(accentHex.caseInsensitiveCompare(Theme.defaultAccentHex) == .orderedSame)
                } header: {
                    Text("Accent color")
                } footer: {
                    Text("Buttons, links, highlights and ratings.")
                }
            }
            Section {
                NavigationLink { FontSettingsPage() } label: {
                    LabeledContent {
                        Text(font.title)
                    } label: {
                        Label("Font", systemImage: "textformat")
                    }
                }
                .themedRow(raised: true)
            } footer: {
                Text("Used for recipes, lists and settings throughout the app.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Theme")
    }

    private func preview(_ theme: ColorTheme, _ scheme: ColorScheme) -> Swatch {
        theme.previewSwatch(for: scheme, classicAccent: accentHex, custom: custom.colors)
    }

    @ViewBuilder
    private func appearanceThumbnail(_ mode: Appearance) -> some View {
        switch mode {
        case .light: ThemeThumbnail(swatch: preview(theme, .light), scheme: .light)
        case .dark: ThemeThumbnail(swatch: preview(theme, .dark), scheme: .dark)
        case .system:
            ThemeThumbnail(swatch: preview(theme, .light), scheme: .light)
                .overlay { ThemeThumbnail(swatch: preview(theme, .dark), scheme: .dark).mask(DiagonalHalf()) }
        }
    }
}

struct FontSettingsPage: View {
    @AppStorage(AppSettings.Key.fontStyle) private var fontStyle = FontStyle.serif.rawValue

    var body: some View {
        Form {
            Section {
                ThemePreview().themedRow(raised: true)
            }
            fonts("System", FontStyle.system)
            fonts("Serif", FontStyle.serifs)
            fonts("Sans Serif", FontStyle.sansSerifs)
            Section {
                rows(FontStyle.typewriters)
            } header: {
                Text("Typewriter")
            } footer: {
                Text("Text size still follows your device's settings.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Font")
    }

    private func fonts(_ title: String, _ styles: [FontStyle]) -> some View {
        Section(title) { rows(styles) }
    }

    private func rows(_ styles: [FontStyle]) -> some View {
        ForEach(styles) { style in
            Button { fontStyle = style.rawValue } label: {
                HStack {
                    VStack {
                        Text(style.title)
                            .font(style.family.map { .custom($0, size: 17, relativeTo: .body) } ?? .system(.body, design: style.design))
                            .foregroundStyle(.primary)
                    }
                    .fontDesign(nil)
                    Spacer()
                    if fontStyle == style.rawValue {
                        Image(systemName: "checkmark").fontWeight(.semibold).foregroundStyle(Theme.accent)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(fontStyle == style.rawValue ? .isSelected : [])
            .themedRow(raised: true)
        }
    }
}

/// Picture tiles three to a row, like the system's own appearance picker.
private struct ThemeTileRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12, alignment: .top), count: 3), spacing: 14) {
            content
        }
        .padding(.vertical, 6)
    }
}

/// A tiny recipe screen: a title, two cards of text and an accent button.
struct ThemeThumbnail: View {
    let swatch: Swatch
    let scheme: ColorScheme

    private var ink: Color { scheme == .dark ? .white : .black }

    var body: some View {
        ZStack(alignment: .topLeading) {
            swatch.canvas
            VStack(alignment: .leading, spacing: 6) {
                Capsule().fill(ink.opacity(0.85)).frame(width: 38, height: 6)
                card(lines: [0.8, 0.55])
                card(lines: [0.65])
                Capsule().fill(swatch.accent).frame(width: 30, height: 10)
            }
            .padding(9)
        }
        .aspectRatio(0.75, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.separator))
        .accessibilityHidden(true)
    }

    private func card(lines: [CGFloat]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(lines.indices, id: \.self) { index in
                GeometryReader { proxy in
                    Capsule().fill(ink.opacity(index == 0 ? 0.6 : 0.3)).frame(width: proxy.size.width * lines[index])
                }
                .frame(height: 4)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(swatch.surface, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}

private struct ThemeTile<Thumbnail: View>: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let thumbnail: Thumbnail
    @Environment(\.appAccent) private var accent

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                thumbnail
                    .frame(maxWidth: 110)
                    .padding(3)
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(accent, lineWidth: 3)
                        }
                    }
                Text(title)
                    .appFont(.footnote, weight: isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct DiagonalHalf: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.maxX * 0.6, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX * 0.4, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

private struct ThemePreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sunday Sauce").appFont(.title2, weight: .bold)
            IngredientLine(text: "2 tbsp olive oil, plus more for serving")
            Text("Simmer for 20 minutes, stirring now and then.").foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Label("Cook", systemImage: "frying.pan")
                    .appFont(.subheadline, weight: .semibold)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.accent, in: Capsule())
                    .foregroundStyle(.white)
                Label("4.5", systemImage: "star.fill")
                    .appFont(.subheadline, weight: .semibold)
                    .foregroundStyle(Theme.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Builds the Custom theme: a page, card and accent color for light and for dark.
struct CustomThemePage: View {
    @AppStorage(AppSettings.Key.colorTheme) private var themeRaw = ColorTheme.classic.rawValue
    @AppStorage(AppSettings.Key.accentColor) private var classicAccent = Theme.defaultAccentHex
    @Environment(\.self) private var environment
    @Environment(\.colorScheme) private var scheme
    private var custom = StoredCustomTheme()
    @State private var editing: ColorScheme?

    private var isOn: Bool { themeRaw == ColorTheme.custom.rawValue }
    private var edited: ColorScheme { editing ?? scheme }

    /// Any edit switches to the Custom theme, so the change shows straight away.
    private func color(_ part: WritableKeyPath<Swatch, String>) -> Binding<Color> {
        Binding(
            get: { Color(hex: custom.colors.swatch(for: edited)[keyPath: part]) ?? .white },
            set: {
                var swatch = custom.colors.swatch(for: edited)
                swatch[keyPath: part] = $0.hex(in: environment)
                custom.set(swatch, for: edited)
                themeRaw = ColorTheme.custom.rawValue
            }
        )
    }

    var body: some View {
        Form {
            Section {
                ThemePreview().themedRow(raised: true)
            }
            Section {
                ThemeTileRow {
                    ForEach([ColorScheme.light, .dark], id: \.self) { variant in
                        ThemeTile(title: variant == .dark ? "Dark" : "Light", isSelected: edited == variant) {
                            editing = variant
                        } thumbnail: {
                            ThemeThumbnail(swatch: custom.colors.swatch(for: variant), scheme: variant)
                        }
                    }
                }
                .themedRow(raised: true)
            } header: {
                Text("Editing")
            } footer: {
                Text("Custom has its own colors for light and for dark, and follows the Appearance you pick in Theme.")
            }
            Section {
                ColorPicker("Page", selection: color(\.canvasHex), supportsOpacity: false)
                    .themedRow(raised: true)
                ColorPicker("Cards", selection: color(\.surfaceHex), supportsOpacity: false)
                    .themedRow(raised: true)
                ColorPicker("Accent", selection: color(\.accentHex), supportsOpacity: false)
                    .themedRow(raised: true)
            } header: {
                Text(edited == .dark ? "Dark colors" : "Light colors")
            } footer: {
                Text("The page sits behind every screen, cards and rows sit on it, and the accent colors buttons, links and ratings.")
            }
            Section {
                Menu {
                    ForEach(ColorTheme.colors) { starter in
                        Button(starter.title) { start(from: starter) }
                    }
                } label: {
                    Label("Start From a Theme", systemImage: "square.on.square")
                }
                .themedRow(raised: true)
            } footer: {
                Text("Copies a theme's light and dark colors here to tweak.")
            }
            if !isOn {
                Section {
                    Button("Use Custom Theme") { themeRaw = ColorTheme.custom.rawValue }
                        .themedRow(raised: true)
                }
            }
        }
        .formStyle(.grouped)
        .settingsPage("Theme Creator")
    }

    private func start(from starter: ColorTheme) {
        for variant in [ColorScheme.light, .dark] {
            custom.set(starter.previewSwatch(for: variant, classicAccent: classicAccent), for: variant)
        }
        themeRaw = ColorTheme.custom.rawValue
    }
}

private struct IntelligenceSettingsPage: View {
    @Environment(\.supportsImagePlayground) private var supportsImagePlayground
    let override: (status: AppleIntelligence.Status, imagePlayground: Bool)?

    var body: some View {
        let status = override?.status ?? AppleIntelligence.status
        Form {
            Section {
                statusRow("Smart Plan for My Week", ready: status.isAvailable)
                statusRow("Recipes from video captions", ready: status.isAvailable)
                statusRow("Ideas from meal photos", ready: status.isAvailable)
                statusRow("Photos with Image Playground", ready: override?.imagePlayground ?? supportsImagePlayground)
            } footer: {
                if status.isAvailable {
                    Text("Everything runs on this device. Smart Plan fills your week from your recipes, and videos without a written recipe are turned into one from their captions.")
                } else {
                    Text(status.explanation + " Smart Plan falls back to a simple rotation, and a video without a written recipe opens as a draft with its captions beside it.")
                }
            }
            Section {
                ForEach(AIAction.allCases) { action in
                    NavigationLink { PromptSettingsPage(action: action) } label: {
                        PromptRow(action: action)
                    }
                }
            } header: {
                Text("Prompts")
            } footer: {
                Text("The instructions the on-device model follows for each job. Open one to read it, or turn on Customize to write your own.")
            }
        }
        .formStyle(.grouped)
        .settingsPage("Apple Intelligence")
    }

    private func statusRow(_ title: String, ready: Bool) -> some View {
        LabeledContent {
            Label(ready ? "Ready" : "Not available", systemImage: ready ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(ready ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary))
        } label: {
            Text(title)
        }
    }
}

private struct PromptRow: View {
    let action: AIAction
    @AppStorage private var customized: Bool

    init(action: AIAction) {
        self.action = action
        _customized = AppStorage(wrappedValue: false, action.isCustomizedKey)
    }

    var body: some View {
        LabeledContent {
            Text(customized ? "Custom" : "Default")
                .foregroundStyle(customized ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Color.secondary))
        } label: {
            Label(action.title, systemImage: action.symbol)
        }
    }
}

private struct PromptSettingsPage: View {
    let action: AIAction
    @AppStorage private var customized: Bool
    @AppStorage private var text: String

    init(action: AIAction) {
        self.action = action
        _customized = AppStorage(wrappedValue: false, action.isCustomizedKey)
        _text = AppStorage(wrappedValue: "", action.textKey)
    }

    var body: some View {
        Form {
            Section {
                Toggle("Customize this prompt", isOn: customizing)
            } footer: {
                Text(action.summary)
            }
            Section {
                if customized {
                    TextEditor(text: $text)
                        .appFont(.callout)
                        .frame(minHeight: 280)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        #endif
                } else {
                    Text(action.defaultInstructions)
                        .appFont(.callout)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } header: {
                Text(customized ? "Your prompt" : "Default prompt")
            } footer: {
                if customized {
                    Text("Only the instructions change. The app still decides what the model hands back, so a prompt can't break an import. Leave it empty to use the default.")
                } else {
                    Text("This is what the model is told today. Turn on Customize to start from it and make it your own.")
                }
            }
            if customized {
                Section {
                    Button("Reset to Default Prompt", role: .destructive) { text = action.defaultInstructions }
                        .disabled(text == action.defaultInstructions)
                }
            }
        }
        .formStyle(.grouped)
        .settingsPage(action.title)
    }

    private var customizing: Binding<Bool> {
        Binding(
            get: { customized },
            set: { on in
                if on, text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { text = action.defaultInstructions }
                customized = on
            }
        )
    }
}

private struct DataSettingsPage: View {
    @EnvironmentObject private var library: RecipeLibrary
    @State private var exportDocument: LibraryExportDocument?
    @State private var isExportPresented = false
    @State private var isExporting = false
    @State private var exportError: String?
    @State private var tidyMessage: String?

    var body: some View {
        Form {
            Section {
                Button {
                    Task {
                        let count = await library.tidyRecipes()
                        tidyMessage = count == 0 ? "Every recipe is already tidy." : "Cleaned up \(count) \(count == 1 ? "recipe" : "recipes")."
                    }
                } label: {
                    Label("Tidy imported recipes", systemImage: "wand.and.sparkles")
                }
            } header: {
                Text("Clean up")
            } footer: {
                Text("Removes stray symbols from ingredients, turns labels like “Dressing:” into sections, and splits steps that were pasted as one block.")
            }
            Section {
                Button { Task { await prepareExport() } } label: {
                    Label("Export all data as JSON", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)
            } header: {
                Text("Your data")
            } footer: {
                Text("Saves every recipe, photo, planned meal, and grocery item to one JSON file that you own. Photos are included as base64.")
            }
            Section("Developer") {
                NavigationLink { DeveloperToolsView() } label: { Label("Developer Tools", systemImage: "wrench.and.screwdriver") }
            }
        }
        .formStyle(.grouped)
        .fileExporter(
            isPresented: $isExportPresented,
            document: exportDocument,
            contentType: .json,
            defaultFilename: LibraryExportDocument.defaultFilename()
        ) { result in
            if case .failure(let error) = result { exportError = error.localizedDescription }
        }
        .alert("Tidy imported recipes", isPresented: Binding(get: { tidyMessage != nil }, set: { if !$0 { tidyMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(tidyMessage ?? "")
        }
        .alert("Couldn't export", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        .settingsPage("Data & Developer")
    }

    private func prepareExport() async {
        isExporting = true
        defer { isExporting = false }
        do {
            exportDocument = LibraryExportDocument(data: try await library.exportJSON())
            isExportPresented = true
        } catch {
            exportError = error.localizedDescription
        }
    }
}

extension View {
    /// Room between a Settings page's title and its first section.
    func settingsSpacing() -> some View {
        safeAreaPadding(.top, 16)
    }
}

private extension View {
    func settingsPage(_ title: String) -> some View {
        settingsSpacing()
            .themedCanvas()
            .navigationTitle(title)
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}
