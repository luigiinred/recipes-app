import RecipeKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CookModeView: View {
    @Environment(\.appAccent) private var accent
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var session: CookSession
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.dismiss) private var dismiss

    @State private var showingIngredients = false

    private var recipe: Recipe? { library.recipe(id: session.current) }

    private static let margin: CGFloat = 20
    /// Room at the bottom of a step so its last line can scroll clear of the floating buttons.
    private static let floatingControlsClearance: CGFloat = 96
    private static let timerScheme = "recipes-timer"

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let wide = geometry.size.width >= 860
                let phone = geometry.size.width < 500
                let short = geometry.size.height < 500
                Group {
                    if let recipe {
                        if wide {
                            HStack(spacing: 0) {
                                IngredientChecklist(recipe: recipe)
                                    .frame(width: min(340, geometry.size.width * 0.32))
                                Divider()
                                stepContent(recipe, fontSize: short ? 28 : 36)
                            }
                        } else {
                            stepContent(recipe, fontSize: phone ? 28 : 36)
                        }
                    } else {
                        MascotEmptyState(scene: .emptyWok, title: "Nothing to cook", message: "Start cooking from a recipe's page.")
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    if let recipe, let videoID = recipe.youTubeVideoID {
                        CookVideo(recipe: recipe, videoID: videoID, step: stepIndex(recipe), width: phone ? 168 : 260)
                            .id(recipe.id)
                    }
                }
                .overlay(alignment: .bottom) {
                    if let recipe { controls(recipe, wide: wide) }
                }
                .toolbar { toolbarContent }
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .background(.background)
        .themedCanvas()
        .keepsScreenAwake()
        .sheet(isPresented: $showingIngredients) {
            if let recipe { IngredientsSheet(recipe: recipe) }
        }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 600)
        #endif
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(role: .close) { session.isPresented = false }
                .accessibilityLabel("Close Cook Mode")
        }
        ToolbarItem(placement: .principal) { titleView }
    }

    private var titleView: some View {
        VStack(spacing: 2) {
            Text(recipe?.title ?? "Cook Mode").font(.headline).lineLimit(1)
            if let recipe, recipe.steps.count > 1 {
                StepDots(count: recipe.steps.count, index: stepIndex(recipe)) { move(recipe, to: $0, count: recipe.steps.count) }
            }
        }
    }

    private func stepIndex(_ recipe: Recipe) -> Int {
        min(session.stepIndex[recipe.id] ?? 0, max(recipe.steps.count - 1, 0))
    }

    private func stepContent(_ recipe: Recipe, fontSize: CGFloat) -> some View {
        let steps = recipe.steps
        return Group {
            if steps.isEmpty {
                ContentUnavailableView("No steps", systemImage: "list.number")
            } else {
                #if os(iOS)
                TabView(selection: Binding(get: { stepIndex(recipe) }, set: { move(recipe, to: $0, count: steps.count) })) {
                    ForEach(steps.indices, id: \.self) { index in
                        stepPage(recipe, index: index, fontSize: fontSize).tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                #else
                stepPage(recipe, index: stepIndex(recipe), fontSize: fontSize)
                    .background {
                        Button("Previous Step") { move(recipe, to: stepIndex(recipe) - 1, count: steps.count) }
                            .keyboardShortcut(.leftArrow, modifiers: []).opacity(0)
                        Button("Next Step") { move(recipe, to: stepIndex(recipe) + 1, count: steps.count) }
                            .keyboardShortcut(.rightArrow, modifiers: []).opacity(0)
                    }
                #endif
            }
        }
    }

    private func stepPage(_ recipe: Recipe, index: Int, fontSize: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Step \(index + 1) of \(recipe.steps.count)")
                    .font(.subheadline).foregroundStyle(.secondary)
                timerHighlighted(recipe.steps[index], ingredients: recipe.ingredients)
                    .font(.system(size: fontSize))
                    .lineSpacing(fontSize * 0.25)
                    .fixedSize(horizontal: false, vertical: true)
                    .textRenderer(TimerPillRenderer())
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == Self.timerScheme,
                              let seconds = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                                .queryItems?.first(where: { $0.name == "seconds" })?.value.flatMap(Int.init)
                        else { return .systemAction }
                        timers.start(label: "\(recipe.title) · step \(index + 1)", seconds: seconds)
                        return .handled
                    })
                CookStepIngredients(recipe: recipe, step: index)
                if let imageID = recipe.stepImage(forStep: index) { StepImageView(id: imageID) }
            }
            .padding(.horizontal, Self.margin)
            .padding(.top, 12)
            .padding(.bottom, Self.floatingControlsClearance)
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }

    private func timerHighlighted(_ text: String, ingredients: [String]) -> Text {
        var timerSpans: [(range: Range<String.Index>, seconds: Int, label: String)] = []
        var cursor = text.startIndex
        for duration in DurationDetector.find(in: text) {
            guard let range = text.range(of: duration.text, range: cursor..<text.endIndex) else { continue }
            timerSpans.append((range, duration.seconds, duration.text))
            cursor = range.upperBound
        }
        let mentions = IngredientMatcher.mentions(in: text, ingredients: ingredients)
            .filter { mention in !timerSpans.contains { $0.range.overlaps(mention) } }

        enum Piece { case timer(seconds: Int, label: String), ingredient }
        let pieces = (timerSpans.map { ($0.range, Piece.timer(seconds: $0.seconds, label: $0.label)) } + mentions.map { ($0, Piece.ingredient) })
            .sorted { $0.0.lowerBound < $1.0.lowerBound }

        var parts: [Text] = []
        cursor = text.startIndex
        for (range, piece) in pieces {
            parts.append(Text(String(text[cursor..<range.lowerBound])))
            switch piece {
            case .timer(let seconds, let label):
                var pill = AttributedString("\u{00A0}\u{23F2}\u{FE0E}\u{00A0}\(label.replacingOccurrences(of: " ", with: "\u{00A0}"))\u{00A0}")
                pill.link = URL(string: "\(Self.timerScheme)://start?seconds=\(seconds)")
                pill.foregroundColor = accent
                parts.append(Text(pill).customAttribute(TimerPill()))
            case .ingredient:
                parts.append(Text(String(text[range])).fontWeight(.semibold).foregroundStyle(Theme.accent))
            }
            cursor = range.upperBound
        }
        parts.append(Text(String(text[cursor...])))
        return parts.dropFirst().reduce(parts[0]) { Text("\($0)\($1)") }
    }

    @ViewBuilder
    private func controls(_ recipe: Recipe, wide: Bool) -> some View {
        let showsTimers = !timers.timers.isEmpty
        if showsTimers || !wide {
            ZStack(alignment: .bottomTrailing) {
                if showsTimers {
                    TimerStrip().padding(.trailing, wide ? 0 : 72)
                }
                if !wide {
                    Button { showingIngredients = true } label: {
                        Image(systemName: "checklist.checked").font(.title3.weight(.semibold)).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .controlSize(.extraLarge)
                    .disabled(recipe.ingredients.isEmpty)
                    .accessibilityLabel("Ingredients")
                }
            }
            .padding(.horizontal, Self.margin)
            .padding(.bottom, 8)
        }
    }

    private func move(_ recipe: Recipe, to index: Int, count: Int) {
        session.stepIndex[recipe.id] = min(max(index, 0), count - 1)
    }
}

private struct TimerPill: TextAttribute {}

private struct TimerPillRenderer: TextRenderer {
    func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            let pill = line.filter { $0[TimerPill.self] != nil }.map(\.typographicBounds.rect)
            if let first = pill.first {
                let rect = pill.dropFirst().reduce(first) { $0.union($1) }.insetBy(dx: 0, dy: -2)
                context.fill(Path(roundedRect: rect, cornerRadius: rect.height / 2), with: .color(context.environment.appAccent.opacity(0.14)))
            }
            for run in line { context.draw(run) }
        }
    }
}

private struct StepDots: View {
    let count: Int
    let index: Int
    let select: (Int) -> Void

    private var visible: Range<Int> {
        let window = 9
        guard count > window else { return 0..<count }
        let start = min(max(index - window / 2, 0), count - window)
        return start..<(start + window)
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(visible, id: \.self) { step in
                Button { select(step) } label: {
                    Circle()
                        .fill(step == index ? Color.primary : Color.secondary.opacity(0.35))
                        .frame(width: 6, height: 6)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Step \(step + 1)")
            }
        }
    }
}

/// The recipe's video as a small player in the corner. Once it is open it jumps to each step's moment as you move through them.
struct CookVideo: View {
    let recipe: Recipe
    let videoID: String
    let step: Int
    let width: CGFloat
    @StateObject private var player = YouTubePlayerController()

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            YouTubeEmbed(recipe: recipe, videoID: videoID, controller: player, startAt: recipe.timestamp(forStep: step) ?? 0, isCompact: true)
                .frame(width: width)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .onChange(of: step) { _, new in
            if player.isShown, let seconds = recipe.timestamp(forStep: new) { player.play(from: seconds) }
        }
    }
}

struct TimerStrip: View {
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.referenceDate) private var referenceDate

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(timers.timers) { timer in
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        TimerChip(timer: timer, remaining: timer.remaining(at: referenceDate ?? context.date)) {
                            timers.cancel(timer)
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct TimerChip: View {
    @Environment(\.appAccent) private var accent
    let timer: CookTimer
    let remaining: Int
    let dismiss: () -> Void

    var body: some View {
        let done = remaining == 0
        HStack(spacing: 8) {
            Text(done ? "Done" : formatTimer(remaining))
                .font(.system(.headline, weight: .semibold)).monospacedDigit()
            Text(timer.label)
                .font(.caption).lineLimit(1)
                .foregroundStyle(done ? .white.opacity(0.85) : .secondary)
                .frame(maxWidth: 120, alignment: .leading)
            Button(action: dismiss) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .opacity(0.7)
                .accessibilityLabel(done ? "Dismiss timer" : "Cancel timer")
        }
        .foregroundStyle(done ? .white : .primary)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .glassEffect(done ? .regular.tint(accent) : .regular, in: Capsule())
    }
}

struct IngredientChecklist: View {
    let recipe: Recipe
    @State private var checked: Set<Int> = []

    var body: some View {
        List {
            ForEach(Array(recipe.ingredientGroups.enumerated()), id: \.offset) { _, group in
                TitledSection(title: group.title) {
                    ForEach(group.items, id: \.index) { index, text in
                        Button {
                            if !checked.insert(index).inserted { checked.remove(index) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: checked.contains(index) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(checked.contains(index) ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(.secondary))
                                IngredientLine(text: text).font(.system(.title3)).strikethrough(checked.contains(index))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .conversionMenu(for: text)
                    }
                }
            }
        }
        .listStyle(.plain)
    }
}

/// What this step needs, in cook mode's big type, so you can read it without going back to the list.
struct CookStepIngredients: View {
    let recipe: Recipe
    let step: Int

    var body: some View {
        let used = IngredientMatcher.indices(in: recipe.steps[step], ingredients: recipe.ingredients)
        if !used.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("FOR THIS STEP").font(.caption.weight(.semibold)).tracking(1.5).foregroundStyle(.secondary)
                ForEach(used, id: \.self) { index in
                    IngredientLine(text: recipe.ingredients[index]).font(.system(.title3))
                        .conversionMenu(for: recipe.ingredients[index])
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

struct IngredientsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let recipe: Recipe

    var body: some View {
        NavigationStack {
            IngredientChecklist(recipe: recipe)
                .navigationTitle("Ingredients")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar { ToolbarItem(placement: .confirmationAction) { ConfirmButton { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 480)
        #endif
    }
}

private struct KeepAwake: ViewModifier {
    #if os(macOS)
    @State private var activity: NSObjectProtocol?
    #endif

    func body(content: Content) -> some View {
        content
            .onAppear {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = AppSettings.keepsScreenAwake
                #else
                guard AppSettings.keepsScreenAwake else { return }
                activity = ProcessInfo.processInfo.beginActivity(options: [.idleDisplaySleepDisabled, .userInitiated], reason: "Cooking")
                #endif
            }
            .onDisappear {
                #if os(iOS)
                UIApplication.shared.isIdleTimerDisabled = false
                #else
                if let activity { ProcessInfo.processInfo.endActivity(activity) }
                activity = nil
                #endif
            }
    }
}

extension View {
    func keepsScreenAwake() -> some View { modifier(KeepAwake()) }

    func cookModeCover(_ session: CookSession) -> some View {
        modifier(CookModeCover(session: session))
    }
}

private struct CookModeCover: ViewModifier {
    @ObservedObject var session: CookSession
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var router: AppRouter

    func body(content: Content) -> some View {
        coverBody(content)
            .onChange(of: router.cookRecipeID, initial: true) { _, id in
                guard let id, let recipe = library.recipe(id: id) else { return }
                session.start(recipe)
                router.cookRecipeID = nil
            }
    }

    @ViewBuilder
    private func coverBody(_ content: Content) -> some View {
        #if os(iOS)
        content.fullScreenCover(isPresented: $session.isPresented) { CookModeView() }
        #else
        content.sheet(isPresented: $session.isPresented) { CookModeView() }
        #endif
    }
}
