import Foundation

/// A recipe's timeline: each time it was cooked here is an "info" event on the recipe's timeline in Mealie, and the other way round.
extension MealieSync {
    private static let subject = "Made it"
    /// Mealie writes its own "recipe created" and "updated" events with another type; those stay in Mealie.
    private static let userEventTypes: Set<String> = ["info", "comment"]

    func syncTimeline(_ state: inout State, user: MealieUser, report: inout Report) async throws {
        let events: [MealieObject]
        do {
            events = try await api.timelineEvents()
        } catch MealieError.server(404, _) {
            return
        }
        var remoteByRecipe: [String: [MealieObject]] = [:]
        for event in events {
            guard let recipeID = event.string("recipeId"), Self.userEventTypes.contains(event.string("eventType") ?? "") else { continue }
            remoteByRecipe[recipeID, default: []].append(event)
        }

        var links = state.timelineLinks ?? [:]
        let scan = try readLocalRecipes()
        for (key, link) in state.recipes.sorted(by: { $0.key < $1.key }) {
            guard let id = UUID(uuidString: key), let mine = scan.recipes[id] else { continue }
            do {
                try await syncTimeline(of: mine, link: link, remote: remoteByRecipe[link.remoteID] ?? [], user: user, links: &links, state: &state, report: &report)
            } catch MealieError.server(_, let message) {
                report.problems.append("Timeline for \(mine.recipe.title): \(message)")
            }
        }
        state.timelineLinks = links
    }

    private func syncTimeline(
        of mine: LocalRecipe, link: RecipeLink, remote: [MealieObject], user: MealieUser,
        links: inout [String: String], state: inout State, report: inout Report
    ) async throws {
        var timeline = mine.recipe.timeline
        var changedHere = false
        let remoteByID = Dictionary(remote.compactMap { event in event.string("id").map { ($0, event) } }, uniquingKeysWith: { $1 })
        let localByRemote = Dictionary(links.map { ($0.value, $0.key) }, uniquingKeysWith: { $1 })

        for event in timeline {
            guard let remoteID = links[event.id.uuidString], remoteByID[remoteID] == nil else { continue }
            timeline.removeAll { $0.id == event.id }
            links[event.id.uuidString] = nil
            report.timeline.deletedHere += 1
            changedHere = true
        }

        for (remoteID, localKey) in localByRemote where remoteByID[remoteID] != nil {
            guard !timeline.contains(where: { $0.id.uuidString == localKey }) else { continue }
            try await api.deleteTimelineEvent(id: remoteID)
            links[localKey] = nil
            report.timeline.deletedInMealie += 1
        }

        var unmatched = remote.filter { event in event.string("id").map { localByRemote[$0] == nil } ?? false }
        var newest = remote.compactMap { event in event.string("timestamp").flatMap(MealieDate.parse) }.max() ?? .distantPast
        var created = false
        for event in timeline where links[event.id.uuidString] == nil {
            if let index = unmatched.firstIndex(where: { Self.matches($0, event) }), let remoteID = unmatched[index].string("id") {
                links[event.id.uuidString] = remoteID
                unmatched.remove(at: index)
                continue
            }
            var body: MealieObject = [
                "recipeId": link.remoteID, "userId": user.id, "subject": Self.subject, "eventType": "info",
                "timestamp": MealieDate.format(event.date),
            ]
            if !event.note.isEmpty { body["eventMessage"] = event.note }
            let made = try await api.createTimelineEvent(body)
            if let remoteID = made.string("id") { links[event.id.uuidString] = remoteID }
            report.timeline.sent += 1
            if event.date > newest { newest = event.date; created = true }
        }

        for event in unmatched {
            guard let remoteID = event.string("id") else { continue }
            let date = event.string("timestamp").flatMap(MealieDate.parse) ?? Date()
            let local = TimelineEvent(id: UUID(uuidString: remoteID) ?? UUID(), date: date, note: event.string("eventMessage") ?? "")
            timeline.append(local)
            links[local.id.uuidString] = remoteID
            report.timeline.received += 1
            changedHere = true
        }

        if created { try await markLastMade(newest, link: link, recipeID: mine.recipe.id, state: &state) }
        if changedHere { try writeTimeline(timeline, to: mine, state: &state, report: &report) }
    }

    /// The same moment and the same words, so a recipe that was already in both places doesn't gain duplicates.
    private static func matches(_ remote: MealieObject, _ local: TimelineEvent) -> Bool {
        guard let stamp = remote.string("timestamp").flatMap(MealieDate.parse), abs(stamp.timeIntervalSince(local.date)) < 1 else { return false }
        return (remote.string("eventMessage") ?? "") == local.note
    }

    private func markLastMade(_ date: Date, link: RecipeLink, recipeID: UUID, state: inout State) async throws {
        let before = try await api.recipe(slug: link.slug)
        let unchanged = Self.stamp(of: before) == link.remoteStamp
        try await api.setLastMade(slug: link.slug, date: date)
        guard unchanged else { return }
        let after = try await api.recipe(slug: link.slug)
        state.recipes[recipeID.uuidString]?.remoteStamp = Self.stamp(of: after)
    }

    private func writeTimeline(_ timeline: [TimelineEvent], to mine: LocalRecipe, state: inout State, report: inout Report) throws {
        guard readLocalRecipe(mine.recipe.id)?.hash == mine.hash else {
            report.problems.append("\(mine.recipe.title) changed while syncing its timeline; it will sync on the next pass.")
            return
        }
        var recipe = mine.recipe
        recipe.timeline = timeline
        let data = try RecipeCoding.makeEncoder().encode(recipe)
        try FileIO.write(data, to: library.recipes.fileURL(for: recipe.id))
        let key = recipe.id.uuidString
        if state.recipes[key]?.localHash == mine.hash { state.recipes[key]?.localHash = ServerSync.sha256(data) }
    }
}
