import Foundation

extension MealieSync {
    enum HashStep: Hashable {
        case createRemote(String)
        case updateRemote(String, remoteID: String)
        case deleteRemote(String, remoteID: String)
        case createLocal(remoteID: String)
        case updateLocal(String, remoteID: String)
        case deleteLocal(String)
        case link(String, remoteID: String, hash: String)
        case unlink(String)
    }

    /// Plans a pass over items that have no edit date. `local` and `remote` map each side's id to a hash of its content;
    /// `links` holds the pairing and the content both sides had after the last pass. When both changed, the local edit wins.
    static func planHashSync(local: [String: String], remote: [String: String], links: [String: HashLink]) -> [HashStep] {
        var steps: [HashStep] = []
        for (id, link) in links.sorted(by: { $0.key < $1.key }) {
            switch (local[id], remote[link.remoteID]) {
            case (nil, nil):
                steps.append(.unlink(id))
            case (nil, let theirs?):
                steps.append(theirs == link.hash ? .deleteRemote(id, remoteID: link.remoteID) : .updateLocal(id, remoteID: link.remoteID))
            case (let mine?, nil):
                steps.append(mine == link.hash ? .deleteLocal(id) : .createRemote(id))
            case (let mine?, let theirs?):
                if mine == theirs {
                    if link.hash != mine { steps.append(.link(id, remoteID: link.remoteID, hash: mine)) }
                } else if mine != link.hash {
                    steps.append(.updateRemote(id, remoteID: link.remoteID))
                } else {
                    steps.append(.updateLocal(id, remoteID: link.remoteID))
                }
            }
        }
        let linkedRemote = Set(links.values.map(\.remoteID))
        var unlinkedRemote = remote.filter { !linkedRemote.contains($0.key) }.sorted { $0.key < $1.key }
        for (id, hash) in local.sorted(by: { $0.key < $1.key }) where links[id] == nil {
            if let match = unlinkedRemote.firstIndex(where: { $0.value == hash }) {
                steps.append(.link(id, remoteID: unlinkedRemote.remove(at: match).key, hash: hash))
            } else {
                steps.append(.createRemote(id))
            }
        }
        for (remoteID, _) in unlinkedRemote { steps.append(.createLocal(remoteID: remoteID)) }
        return steps
    }

    private func checkDeletions(_ steps: [HashStep], known: Int) throws {
        let deletions = steps.filter { if case .deleteRemote = $0 { true } else if case .deleteLocal = $0 { true } else { false } }.count
        if !options.allowMassDeletion, deletions > max(10, known / 2) { throw MealieError.tooManyDeletions(deletions) }
    }

    // MARK: - Meal plan

    private struct PlanContent {
        var day: String
        var meal: Meal
        var remoteRecipeID: String
        var title: String

        var hash: String { [day, meal.rawValue, remoteRecipeID, remoteRecipeID.isEmpty ? title : ""].joined(separator: "|") }
    }

    func syncMealPlan(_ state: inout State, report: inout Report) async throws {
        let remoteObjects = try await api.mealPlanEntries()
        let localRecipeIDs = Dictionary(state.recipes.map { ($0.value.remoteID, $0.key) }, uniquingKeysWith: { $1 })
        let entries = Dictionary(try library.mealPlan.list().map { ($0.id.uuidString, $0) }, uniquingKeysWith: { $1 })

        var localHashes: [String: String] = [:]
        for (id, entry) in entries {
            var remoteRecipeID = ""
            if let recipeID = entry.recipeID {
                guard let link = state.recipes[recipeID.uuidString] else { continue }
                remoteRecipeID = link.remoteID
            }
            localHashes[id] = PlanContent(day: entry.day, meal: entry.meal, remoteRecipeID: remoteRecipeID, title: entry.title).hash
        }
        var remoteByID: [String: MealieObject] = [:]
        var remoteHashes: [String: String] = [:]
        for object in remoteObjects {
            guard let number = (object["id"] as? NSNumber)?.intValue else { continue }
            let recipeID = object.string("recipeId") ?? ""
            if !recipeID.isEmpty, localRecipeIDs[recipeID] == nil { continue }
            remoteByID["\(number)"] = object
            remoteHashes["\(number)"] = Self.planContent(of: object).hash
        }

        let steps = Self.planHashSync(local: localHashes, remote: remoteHashes, links: state.mealPlan)
        try checkDeletions(steps, known: state.mealPlan.count)
        for step in steps {
            do {
                try await applyPlan(step, entries: entries, remoteByID: remoteByID, localHashes: localHashes, remoteHashes: remoteHashes, localRecipeIDs: localRecipeIDs, state: &state, report: &report)
            } catch MealieError.server(let status, let message) {
                report.problems.append("Meal plan: \(message) (\(status))")
            }
        }
    }

    private static func planContent(of object: MealieObject) -> PlanContent {
        let recipeID = object.string("recipeId") ?? ""
        let title = object.string("title")?.trimmed.nonEmpty ?? (object["recipe"] as? MealieObject)?.string("name") ?? "Untitled"
        return PlanContent(day: object.string("date") ?? "", meal: Meal(rawValue: object.string("entryType") ?? "") ?? .snack, remoteRecipeID: recipeID, title: title)
    }

    private func applyPlan(
        _ step: HashStep, entries: [String: MealPlanEntry], remoteByID: [String: MealieObject], localHashes: [String: String],
        remoteHashes: [String: String], localRecipeIDs: [String: String], state: inout State, report: inout Report
    ) async throws {
        switch step {
        case .unlink(let id):
            state.mealPlan[id] = nil
        case .link(let id, let remoteID, let hash):
            state.mealPlan[id] = HashLink(remoteID: remoteID, hash: hash)
        case .createRemote(let id), .updateRemote(let id, _):
            guard let entry = entries[id] else { return }
            let recipeKey = entry.recipeID.flatMap { state.recipes[$0.uuidString]?.remoteID }
            var body: MealieObject = [
                "date": entry.day, "entryType": entry.meal.rawValue, "title": recipeKey == nil ? entry.title : "",
                "text": "", "recipeId": recipeKey ?? NSNull(),
            ]
            let result: MealieObject
            if case .updateRemote(_, let remoteID) = step, let existing = remoteByID[remoteID], let number = Int(remoteID) {
                for key in ["id", "groupId", "userId", "recipeScale"] { body[key] = existing[key] }
                result = try await api.updateMealPlanEntry(id: number, body)
                report.mealPlan.sent += 1
            } else {
                result = try await api.createMealPlanEntry(body)
                report.mealPlan.sent += 1
            }
            guard let number = (result["id"] as? NSNumber)?.intValue, let hash = localHashes[id] else { return }
            state.mealPlan[id] = HashLink(remoteID: "\(number)", hash: hash)
        case .deleteRemote(let id, let remoteID):
            if let number = Int(remoteID) { try await api.deleteMealPlanEntry(id: number) }
            state.mealPlan[id] = nil
            report.mealPlan.deletedInMealie += 1
        case .createLocal(let remoteID), .updateLocal(_, let remoteID):
            guard let object = remoteByID[remoteID], let hash = remoteHashes[remoteID] else { return }
            let content = Self.planContent(of: object)
            var id = UUID()
            if case .updateLocal(let existing, _) = step, let known = UUID(uuidString: existing) { id = known }
            var entry = entries[id.uuidString] ?? MealPlanEntry(id: id, title: content.title, day: content.day, meal: content.meal)
            entry.day = content.day
            entry.meal = content.meal
            entry.title = content.title
            entry.recipeID = localRecipeIDs[content.remoteRecipeID].flatMap(UUID.init)
            entry.updatedAt = Date()
            try library.mealPlan.save(entry)
            state.mealPlan[id.uuidString] = HashLink(remoteID: remoteID, hash: hash)
            report.mealPlan.received += 1
        case .deleteLocal(let id):
            if let entry = entries[id] { try library.mealPlan.delete(entry) }
            state.mealPlan[id] = nil
            report.mealPlan.deletedHere += 1
        }
    }

    // MARK: - Groceries

    private struct GroceryContent {
        var name: String
        var quantity: String
        var isChecked: Bool

        var hash: String { [name, quantity, String(isChecked)].joined(separator: "|") }
    }

    static let groceryNameKey = "recipesAppName"
    static let groceryQuantityKey = "recipesAppQuantity"
    static let groceryRecipeKey = "recipesAppRecipe"

    func syncGroceries(_ state: inout State, report: inout Report) async throws {
        let listID = try await shoppingListID(&state)
        let remoteObjects = try await api.shoppingItems(list: listID)
        let items = Dictionary(try library.groceries.list().map { ($0.id.uuidString, $0) }, uniquingKeysWith: { $1 })

        let localHashes = items.mapValues { GroceryContent(name: $0.name, quantity: $0.quantity, isChecked: $0.isChecked).hash }
        var remoteByID: [String: MealieObject] = [:]
        var remoteHashes: [String: String] = [:]
        for object in remoteObjects {
            guard let id = object.string("id") else { continue }
            remoteByID[id] = object
            remoteHashes[id] = Self.groceryContent(of: object).hash
        }

        let steps = Self.planHashSync(local: localHashes, remote: remoteHashes, links: state.groceries)
        try checkDeletions(steps, known: state.groceries.count)
        for step in steps {
            do {
                try await applyGrocery(step, list: listID, items: items, remoteByID: remoteByID, localHashes: localHashes, remoteHashes: remoteHashes, state: &state, report: &report)
            } catch MealieError.server(let status, let message) {
                report.problems.append("Groceries: \(message) (\(status))")
            }
        }
    }

    private func shoppingListID(_ state: inout State) async throws -> String {
        let lists = try await api.shoppingLists()
        let name = options.shoppingListName
        if let id = state.shoppingListID, state.shoppingListName == name, lists.contains(where: { $0.id == id }) { return id }
        let list: MealieShoppingList
        if let found = lists.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            list = found
        } else {
            list = try await api.createShoppingList(name: name)
        }
        if state.shoppingListID != list.id { state.groceries = [:] }
        state.shoppingListID = list.id
        state.shoppingListName = name
        return list.id
    }

    /// What an item reads as in the app. Items the app wrote carry their own name and quantity; items made in Mealie are read from its fields.
    private static func groceryContent(of object: MealieObject) -> GroceryContent {
        let note = object.string("note")?.trimmed ?? ""
        let extras = object["extras"] as? MealieObject
        let checked = object["checked"] as? Bool ?? false
        if let name = extras?.string(groceryNameKey) {
            let quantity = extras?.string(groceryQuantityKey) ?? ""
            if note == reminderTitle(name: name, quantity: quantity) { return GroceryContent(name: name, quantity: quantity, isChecked: checked) }
        }
        let amount = object.double("quantity") ?? 0
        let unit = object["unit"] as? MealieObject
        let unitText = unit?.string("abbreviation")?.nonEmpty ?? unit?.string("name") ?? ""
        let food = (object["food"] as? MealieObject)?.string("name")
        let quantity = amount > 0 && !(amount == 1 && unitText.isEmpty) ? [formatted(amount), unitText].filter { !$0.isEmpty }.joined(separator: " ") : ""
        let name = food ?? note.nonEmpty ?? object.string("display")?.trimmed ?? "Item"
        return GroceryContent(name: name, quantity: quantity, isChecked: checked)
    }

    private static func reminderTitle(name: String, quantity: String) -> String {
        quantity.isEmpty ? name : "\(quantity) \(name)"
    }

    private static func formatted(_ amount: Double) -> String {
        amount == amount.rounded() ? String(Int(amount)) : String(format: "%g", amount)
    }

    private func applyGrocery(
        _ step: HashStep, list: String, items: [String: GroceryItem], remoteByID: [String: MealieObject], localHashes: [String: String],
        remoteHashes: [String: String], state: inout State, report: inout Report
    ) async throws {
        switch step {
        case .unlink(let id):
            state.groceries[id] = nil
        case .link(let id, let remoteID, let hash):
            state.groceries[id] = HashLink(remoteID: remoteID, hash: hash)
        case .createRemote(let id), .updateRemote(let id, _):
            guard let item = items[id], let hash = localHashes[id] else { return }
            var body: MealieObject = [:]
            if case .updateRemote(_, let remoteID) = step, let existing = remoteByID[remoteID] {
                body = existing
                let current = Self.groceryContent(of: existing)
                if current.name != item.name || current.quantity != item.quantity {
                    for key in ["food", "unit", "foodId", "unitId"] { body[key] = NSNull() }
                    body["quantity"] = 0
                    body["note"] = item.reminderTitle
                }
            } else {
                body = ["quantity": 0, "note": item.reminderTitle]
            }
            body["shoppingListId"] = list
            body["checked"] = item.isChecked
            var extras = body["extras"] as? MealieObject ?? [:]
            extras[Self.groceryNameKey] = item.name
            extras[Self.groceryQuantityKey] = item.quantity
            extras[Self.groceryRecipeKey] = item.recipeID?.uuidString ?? ""
            body["extras"] = extras
            let result: MealieObject
            if case .updateRemote(_, let remoteID) = step {
                result = try await api.updateShoppingItem(id: remoteID, body)
            } else {
                result = try await api.createShoppingItem(body)
            }
            guard let remoteID = result.string("id") else { return }
            state.groceries[id] = HashLink(remoteID: remoteID, hash: hash)
            report.groceries.sent += 1
        case .deleteRemote(let id, let remoteID):
            try await api.deleteShoppingItem(id: remoteID)
            state.groceries[id] = nil
            report.groceries.deletedInMealie += 1
        case .createLocal(let remoteID), .updateLocal(_, let remoteID):
            guard let object = remoteByID[remoteID], let hash = remoteHashes[remoteID] else { return }
            let content = Self.groceryContent(of: object)
            var id = UUID()
            if case .updateLocal(let existing, _) = step, let known = UUID(uuidString: existing) { id = known }
            var item = items[id.uuidString] ?? GroceryItem(id: id, name: content.name)
            item.name = content.name
            item.quantity = content.quantity
            item.isChecked = content.isChecked
            if let recipe = (object["extras"] as? MealieObject)?.string(Self.groceryRecipeKey), let recipeID = UUID(uuidString: recipe) { item.recipeID = recipeID }
            item.updatedAt = Date()
            try library.groceries.save(item)
            state.groceries[id.uuidString] = HashLink(remoteID: remoteID, hash: hash)
            report.groceries.received += 1
        case .deleteLocal(let id):
            if let item = items[id] { try library.groceries.delete(item) }
            state.groceries[id] = nil
            report.groceries.deletedHere += 1
        }
    }
}
