import RecipeKit
import SwiftUI
#if os(iOS)
import UIKit
#endif

struct CookModeView: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var session: CookSession
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.dismiss) private var dismiss

    @State private var showingIngredients = false
    @State private var addingRecipe = false
    @State private var addingTimer = false

    private var recipe: Recipe? { library.recipe(id: session.current) }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= 860
            VStack(spacing: 0) {
                topBar(showsIngredientsButton: !wide)
                Divider()
                if let recipe {
                    if wide {
                        HStack(spacing: 0) {
                            IngredientChecklist(recipe: recipe)
                                .frame(width: min(340, geometry.size.width * 0.32))
                            Divider()
                            stepContent(recipe)
                        }
                    } else {
                        stepContent(recipe)
                    }
                } else {
                    ContentUnavailableView("Nothing to cook", systemImage: "flame",
                                           description: Text("Add a recipe to start cooking."))
                }
                Divider()
                TimerStrip(onAdd: { addingTimer = true })
            }
        }
        .background(.background)
        .keepsScreenAwake()
        .sheet(isPresented: $showingIngredients) {
            if let recipe { IngredientsSheet(recipe: recipe) }
        }
        .sheet(isPresented: $addingTimer) { AddTimerSheet(defaultLabel: recipe?.title ?? "Timer") }
        .sheet(isPresented: $addingRecipe) { CookRecipePicker() }
        #if os(macOS)
        .frame(minWidth: 760, minHeight: 600)
        #endif
    }

    private func topBar(showsIngredientsButton: Bool) -> some View {
        HStack(spacing: 12) {
            Button { session.isPresented = false } label: {
                Image(systemName: "xmark.circle.fill").font(.title2).foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Cook Mode")
            Menu {
                ForEach(session.queue, id: \.self) { id in
                    if let queued = library.recipe(id: id) {
                        Button { session.current = id } label: {
                            Label(queued.title, systemImage: id == session.current ? "checkmark" : "")
                        }
                    }
                }
                Divider()
                Button("Add Recipe…", systemImage: "plus") { addingRecipe = true }
                if let id = session.current {
                    Button("Remove from Cook Mode", systemImage: "minus.circle", role: .destructive) { session.remove(id) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(recipe?.title ?? "Cook Mode").font(.system(.headline, design: .serif)).lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Spacer()
            if showsIngredientsButton {
                Button { showingIngredients = true } label: { Label("Ingredients", systemImage: "list.bullet") }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.accent)
                    .disabled(recipe?.ingredients.isEmpty ?? true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func stepContent(_ recipe: Recipe) -> some View {
        let steps = recipe.steps
        let index = min(session.stepIndex[recipe.id] ?? 0, max(steps.count - 1, 0))
        return VStack(spacing: 0) {
            if steps.isEmpty {
                ContentUnavailableView("No steps", systemImage: "list.number")
            } else {
                if let videoID = recipe.youTubeVideoID {
                    CookVideo(recipe: recipe, videoID: videoID, step: index).id(recipe.id)
                    Divider()
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        Text("STEP \(index + 1) OF \(steps.count)")
                            .font(.subheadline.weight(.semibold)).tracking(1.5).foregroundStyle(Theme.accent)
                        Text(steps[index])
                            .font(.system(size: 34, weight: .regular, design: .serif))
                            .lineSpacing(8)
                            .fixedSize(horizontal: false, vertical: true)
                        CookStepIngredients(recipe: recipe, step: index)
                        if let imageID = recipe.stepImage(forStep: index) { StepImageView(id: imageID) }
                        durationButtons(for: steps[index], recipe: recipe, step: index)
                    }
                    .padding(28)
                    .frame(maxWidth: 820, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .gesture(DragGesture(minimumDistance: 40).onEnded { value in
                    if value.translation.width < -40 { move(recipe, to: index + 1, count: steps.count) }
                    if value.translation.width > 40 { move(recipe, to: index - 1, count: steps.count) }
                })
                HStack(spacing: 16) {
                    Button { move(recipe, to: index - 1, count: steps.count) } label: {
                        Label("Previous", systemImage: "chevron.left").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(index == 0)
                    Button {
                        if index == steps.count - 1 { session.isPresented = false } else { move(recipe, to: index + 1, count: steps.count) }
                    } label: {
                        Label(index == steps.count - 1 ? "Done" : "Next", systemImage: index == steps.count - 1 ? "checkmark" : "chevron.right")
                            .labelStyle(.titleAndIcon).frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.rightArrow, modifiers: [])
                }
                .controlSize(.large)
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func durationButtons(for text: String, recipe: Recipe, step: Int) -> some View {
        let found = DurationDetector.find(in: text)
        if !found.isEmpty {
            HStack {
                ForEach(found, id: \.self) { duration in
                    Button {
                        timers.start(label: "\(recipe.title) · step \(step + 1)", seconds: duration.seconds)
                    } label: {
                        Label("Start \(duration.text) timer", systemImage: "timer")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(Theme.accent)
                }
            }
        }
    }

    private func move(_ recipe: Recipe, to index: Int, count: Int) {
        session.stepIndex[recipe.id] = min(max(index, 0), count - 1)
    }
}

/// The recipe's video, pinned above the steps. Once it is open it jumps to each step's moment as you move through them.
struct CookVideo: View {
    let recipe: Recipe
    let videoID: String
    let step: Int
    @StateObject private var player = YouTubePlayerController()

    var body: some View {
        YouTubeEmbed(recipe: recipe, videoID: videoID, controller: player, startAt: recipe.timestamp(forStep: step) ?? 0)
            .frame(maxWidth: 560)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .onChange(of: step) { _, new in
                if player.isShown, let seconds = recipe.timestamp(forStep: new) { player.play(from: seconds) }
            }
    }
}

struct TimerStrip: View {
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.referenceDate) private var referenceDate
    let onAdd: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Button(action: onAdd) {
                    Label("Timer", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                ForEach(timers.timers) { timer in
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        TimerChip(timer: timer, remaining: timer.remaining(at: referenceDate ?? context.date)) {
                            timers.cancel(timer)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

private struct TimerChip: View {
    let timer: CookTimer
    let remaining: Int
    let dismiss: () -> Void

    var body: some View {
        let done = remaining == 0
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(timer.label).font(.caption).foregroundStyle(done ? .white.opacity(0.85) : .secondary).lineLimit(1)
                Text(done ? "Done" : formatTimer(remaining))
                    .font(.system(.title3, design: .rounded, weight: .semibold)).monospacedDigit()
            }
            Button(action: dismiss) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .opacity(0.7)
                .accessibilityLabel(done ? "Dismiss timer" : "Cancel timer")
        }
        .foregroundStyle(done ? .white : .primary)
        .padding(.horizontal, 14).padding(.vertical, 8)
        .frame(maxWidth: 240)
        .background(done ? Theme.accent : Color.secondary.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
    }
}

struct AddTimerSheet: View {
    @EnvironmentObject private var timers: TimerCenter
    @Environment(\.dismiss) private var dismiss
    let defaultLabel: String

    @State private var label = ""
    @State private var minutes = 10
    @State private var seconds = 0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Label", text: $label, prompt: Text(defaultLabel))
                Stepper("Minutes: \(minutes)", value: $minutes, in: 0...600)
                Stepper("Seconds: \(seconds)", value: $seconds, in: 0...59, step: 5)
                Section {
                    HStack {
                        ForEach([1, 5, 10, 15, 30], id: \.self) { preset in
                            Button("\(preset)m") { minutes = preset; seconds = 0 }.buttonStyle(.bordered)
                        }
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("New Timer")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { CancelButton() }
                ToolbarItem(placement: .confirmationAction) {
                    ConfirmButton(title: "Start", isDisabled: minutes == 0 && seconds == 0) {
                        timers.start(label: label.isEmpty ? defaultLabel : label, seconds: minutes * 60 + seconds)
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 320)
        #endif
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
                                    .foregroundStyle(checked.contains(index) ? Theme.accent : .secondary)
                                IngredientLine(text: text).font(.system(.title3, design: .serif)).strikethrough(checked.contains(index))
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
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
                    IngredientLine(text: recipe.ingredients[index]).font(.system(.title3, design: .serif))
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

struct CookRecipePicker: View {
    @EnvironmentObject private var library: RecipeLibrary
    @EnvironmentObject private var session: CookSession
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    var body: some View {
        NavigationStack {
            List(library.recipes.filter { $0.matches(search) && !$0.steps.isEmpty }) { recipe in
                Button {
                    session.start(recipe)
                    dismiss()
                } label: {
                    Text(recipe.title).font(.system(.body, design: .serif))
                }
                .buttonStyle(.plain)
            }
            .persistentSearch(text: $search, prompt: "Search recipes")
            .navigationTitle("Add to Cook Mode")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { ToolbarItem(placement: .cancellationAction) { CancelButton() } }
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
