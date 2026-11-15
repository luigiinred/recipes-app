import Foundation

/// A JSON object as Mealie sends it. Recipes stay untyped so fields the app doesn't know survive a round trip.
public typealias MealieObject = [String: Any]

public enum MealieError: LocalizedError, Equatable {
    case unauthorized
    case unreachable(String)
    case server(Int, String)
    case notMealie
    case tooManyDeletions(Int)
    case notPublic

    public var errorDescription: String? {
        switch self {
        case .unauthorized: "Mealie didn't accept the API token."
        case .unreachable(let reason): "Couldn't reach Mealie: \(reason)"
        case .server(let status, let message): "Mealie answered \(status): \(message)"
        case .notMealie: "That address doesn't look like a Mealie server."
        case .tooManyDeletions(let count): "This would delete \(count) items, which looks like a mistake. Nothing was changed."
        case .notPublic: "That server has no public recipes to browse. Paste the page of a public group (…/g/name), or ask for a Share Read-Only link."
        }
    }
}

public struct MealieRecipeSummary: Sendable, Equatable {
    public var id: String
    public var slug: String
    public var updatedAt: Date
    public var imageToken: String?
}

public struct MealieRating: Sendable, Equatable {
    public var rating: Double?
    public var isFavorite: Bool
}

public struct MealieShoppingList: Sendable, Equatable {
    public var id: String
    public var name: String
}

public struct MealieUser: Sendable, Equatable {
    public var id: String
    public var username: String
    public var groupSlug: String?

    public init(id: String, username: String, groupSlug: String? = nil) {
        self.id = id
        self.username = username
        self.groupSlug = groupSlug
    }
}

/// The part of Mealie's REST API the sync uses.
public protocol MealieAPI: Sendable {
    func currentUser() async throws -> MealieUser

    func recipeList() async throws -> [MealieRecipeSummary]
    func recipe(slug: String) async throws -> MealieObject
    func createRecipe(name: String) async throws -> String
    func updateRecipe(slug: String, _ body: MealieObject) async throws -> MealieObject
    func deleteRecipe(slug: String) async throws
    func recipeImage(id: String) async throws -> Data?
    func setRecipeImage(slug: String, data: Data) async throws
    func deleteRecipeImage(slug: String) async throws

    func tags() async throws -> [MealieObject]
    func createTag(name: String) async throws -> MealieObject
    func categories() async throws -> [MealieObject]
    func ratings() async throws -> [String: MealieRating]
    func setRating(userID: String, slug: String, rating: Double?, isFavorite: Bool) async throws

    func timelineEvents() async throws -> [MealieObject]
    func createTimelineEvent(_ body: MealieObject) async throws -> MealieObject
    func deleteTimelineEvent(id: String) async throws
    func setLastMade(slug: String, date: Date) async throws

    func mealPlanEntries() async throws -> [MealieObject]
    func createMealPlanEntry(_ body: MealieObject) async throws -> MealieObject
    func updateMealPlanEntry(id: Int, _ body: MealieObject) async throws -> MealieObject
    func deleteMealPlanEntry(id: Int) async throws

    func shoppingLists() async throws -> [MealieShoppingList]
    func createShoppingList(name: String) async throws -> MealieShoppingList
    func shoppingItems(list: String) async throws -> [MealieObject]
    func createShoppingItem(_ body: MealieObject) async throws -> MealieObject
    func updateShoppingItem(id: String, _ body: MealieObject) async throws -> MealieObject
    func deleteShoppingItem(id: String) async throws
}

public struct MealieClient: MealieAPI {
    public let server: URL
    private let token: String
    private let session: URLSession

    public init(server: URL, token: String, session: URLSession = .shared) {
        self.server = server
        self.token = token
        self.session = session
    }

    /// A recipe's page in Mealie's web app: `/g/<group>/r/<slug>`, or the older `/recipe/<slug>` when the group isn't known.
    public static func recipePageURL(server: URL, groupSlug: String?, slug: String) -> URL {
        if let groupSlug, !groupSlug.isEmpty {
            return server.appendingPathComponent("g").appendingPathComponent(groupSlug).appendingPathComponent("r").appendingPathComponent(slug)
        }
        return server.appendingPathComponent("recipe").appendingPathComponent(slug)
    }

    /// Accepts what people paste: a bare host, a trailing slash, or the `/api` address. Nil when it isn't an http(s) URL.
    public static func normalizedServer(_ text: String) -> URL? {
        var text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard var components = URLComponents(string: text), let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https", let host = components.host, !host.isEmpty else { return nil }
        components.query = nil
        components.fragment = nil
        var path = components.path
        while path.hasSuffix("/") { path.removeLast() }
        if path.hasSuffix("/api") { path.removeLast(4) }
        components.path = path
        return components.url
    }

    // MARK: - Account

    public func currentUser() async throws -> MealieUser {
        let object: MealieObject
        do {
            object = try await self.object("GET", "users/self")
        } catch MealieError.server(404, _) {
            throw MealieError.notMealie
        }
        guard let id = object["id"] as? String else { throw MealieError.notMealie }
        return MealieUser(id: id, username: object["username"] as? String ?? "", groupSlug: object["groupSlug"] as? String)
    }

    /// Makes a new API token for the signed-in user and returns its secret, which Mealie shows only once.
    public func createAPIToken(name: String) async throws -> String {
        let created = try await object("POST", "users/api-tokens", body: ["name": name])
        guard let token = created["token"] as? String, !token.isEmpty else { throw MealieError.notMealie }
        return token
    }

    /// An invitation to join the signed-in user's household, good for `uses` sign-ups. Falls back to the group
    /// invitations of Mealie servers older than households.
    public func createInvitation(uses: Int = 1) async throws -> String {
        let created: MealieObject
        do {
            created = try await object("POST", "households/invitations", body: ["uses": uses])
        } catch MealieError.server(404, _) {
            created = try await object("POST", "groups/invitations", body: ["uses": uses])
        }
        guard let token = created["token"] as? String, !token.isEmpty else { throw MealieError.notMealie }
        return token
    }

    public struct Registration: Sendable, Equatable {
        public var fullName: String
        public var email: String
        public var username: String
        public var password: String

        public init(fullName: String, email: String, username: String, password: String) {
            self.fullName = fullName
            self.email = email
            self.username = username
            self.password = password
        }
    }

    /// Signs up a new user with an invitation, signs in as them, and returns an API token for that user.
    public static func join(
        server: URL, invitation: String, as registration: Registration, tokenName: String, session: URLSession = .shared
    ) async throws -> String {
        let anonymous = MealieClient(server: server, token: "", session: session)
        _ = try await anonymous.object("POST", "users/register", body: [
            "groupToken": invitation,
            "email": registration.email,
            "username": registration.username,
            "fullName": registration.fullName,
            "password": registration.password,
            "passwordConfirm": registration.password,
            "advanced": false,
            "private": false,
            "seedData": false,
            "locale": Locale.current.identifier(.bcp47),
        ])
        let access = try await anonymous.signIn(username: registration.username, password: registration.password)
        return try await MealieClient(server: server, token: access, session: session).createAPIToken(name: tokenName)
    }

    private func signIn(username: String, password: String) async throws -> String {
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        func encoded(_ text: String) -> String { text.addingPercentEncoding(withAllowedCharacters: unreserved) ?? text }
        let body = Data("username=\(encoded(username))&password=\(encoded(password))".utf8)
        let (data, _) = try await send("POST", "auth/token", body: body, contentType: "application/x-www-form-urlencoded")
        guard let json = try? JSONSerialization.jsonObject(with: data) as? MealieObject,
              let token = json["access_token"] as? String, !token.isEmpty else { throw MealieError.notMealie }
        return token
    }

    // MARK: - Public pages

    /// A group's public page, `https://host/g/<group>` or anything under it, as the server and group it names.
    public static func publicPage(_ text: String) -> (server: URL, group: String)? {
        guard let url = normalizedServer(text) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let index = parts.firstIndex(of: "g"), index + 1 < parts.count,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        components.path = parts[..<index].isEmpty ? "" : "/" + parts[..<index].joined(separator: "/")
        guard let server = components.url else { return nil }
        return (server, parts[index + 1])
    }

    /// The group a bare address browses: the server's default group, or Mealie's own default name.
    public func defaultGroup() async -> String {
        let about = try? await object("GET", "app/about")
        return (about?["defaultGroupSlug"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? "home"
    }

    /// What anyone can read without signing in: the recipes a public group's public households marked public.
    public func publicRecipeSummaries(group: String) async throws -> [MealieObject] {
        do {
            return try await paged("explore/groups/\(group)/recipes")
        } catch MealieError.server(404, _) {
            throw MealieError.notPublic
        }
    }

    public func publicRecipe(group: String, slug: String) async throws -> MealieObject {
        try await object("GET", "explore/groups/\(group)/recipes/\(slug)")
    }

    // MARK: - Recipes

    public func recipeList() async throws -> [MealieRecipeSummary] {
        try await paged("recipes").compactMap { item in
            guard let id = item["id"] as? String, let slug = item["slug"] as? String else { return nil }
            let stamp = (item["updatedAt"] as? String).flatMap(MealieDate.parse) ?? .distantPast
            return MealieRecipeSummary(id: id, slug: slug, updatedAt: stamp, imageToken: item["image"] as? String)
        }
    }

    /// Every recipe as Mealie lists them: names, descriptions, times and labels, without ingredients or steps.
    public func recipeSummaries() async throws -> [MealieObject] { try await paged("recipes") }

    public func recipe(slug: String) async throws -> MealieObject {
        try await object("GET", "recipes/\(slug)")
    }

    public func createRecipe(name: String) async throws -> String {
        let (data, _) = try await send("POST", "recipes", body: try JSONSerialization.data(withJSONObject: ["name": name]))
        guard let slug = try? JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed) as? String else { throw MealieError.notMealie }
        return slug
    }

    public func updateRecipe(slug: String, _ body: MealieObject) async throws -> MealieObject {
        try await object("PUT", "recipes/\(slug)", body: body)
    }

    public func deleteRecipe(slug: String) async throws {
        _ = try await send("DELETE", "recipes/\(slug)", allowing: [404])
    }

    public func recipeImage(id: String) async throws -> Data? {
        try await recipeImage(id: id, file: "original.webp")
    }

    /// `file` is one of Mealie's sizes: `original.webp`, `min-original.webp` or `tiny-original.webp`.
    public func recipeImage(id: String, file: String) async throws -> Data? {
        let (data, response) = try await send("GET", "media/recipes/\(id)/images/\(file)", allowing: [404])
        return response.statusCode == 404 ? nil : data
    }

    public func setRecipeImage(slug: String, data: Data) async throws {
        let boundary = "recipes-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"extension\"\r\n\r\njpg\r\n")
        body.append("--\(boundary)\r\nContent-Disposition: form-data; name=\"image\"; filename=\"image.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n")
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n")
        _ = try await send("PUT", "recipes/\(slug)/image", body: body, contentType: "multipart/form-data; boundary=\(boundary)")
    }

    public func deleteRecipeImage(slug: String) async throws {
        _ = try await send("DELETE", "recipes/\(slug)/image", allowing: [404])
    }

    // MARK: - Organizers and ratings

    public func tags() async throws -> [MealieObject] { try await paged("organizers/tags") }

    public func createTag(name: String) async throws -> MealieObject {
        try await object("POST", "organizers/tags", body: ["name": name])
    }

    public func categories() async throws -> [MealieObject] { try await paged("organizers/categories") }

    public func ratings() async throws -> [String: MealieRating] {
        let list = try await object("GET", "users/self/ratings")["ratings"] as? [MealieObject] ?? []
        var result: [String: MealieRating] = [:]
        for item in list {
            guard let id = item["recipeId"] as? String else { continue }
            result[id] = MealieRating(rating: (item["rating"] as? NSNumber)?.doubleValue, isFavorite: item["isFavorite"] as? Bool ?? false)
        }
        return result
    }

    public func setRating(userID: String, slug: String, rating: Double?, isFavorite: Bool) async throws {
        let body: MealieObject = ["rating": rating ?? 0, "isFavorite": isFavorite]
        _ = try await send("POST", "users/\(userID)/ratings/\(slug)", body: try JSONSerialization.data(withJSONObject: body))
    }

    // MARK: - Timeline

    public func timelineEvents() async throws -> [MealieObject] {
        try await paged("recipes/timeline/events")
    }

    public func createTimelineEvent(_ body: MealieObject) async throws -> MealieObject {
        try await object("POST", "recipes/timeline/events", body: body)
    }

    public func deleteTimelineEvent(id: String) async throws {
        _ = try await send("DELETE", "recipes/timeline/events/\(id)", allowing: [404])
    }

    public func setLastMade(slug: String, date: Date) async throws {
        let body: MealieObject = ["timestamp": MealieDate.format(date)]
        _ = try await send("PATCH", "recipes/\(slug)/last-made", body: try JSONSerialization.data(withJSONObject: body))
    }

    // MARK: - Meal plan

    public func mealPlanEntries() async throws -> [MealieObject] {
        try await paged("households/mealplans", query: [("start_date", "2000-01-01"), ("end_date", "2100-12-31")])
    }

    public func createMealPlanEntry(_ body: MealieObject) async throws -> MealieObject {
        try await object("POST", "households/mealplans", body: body)
    }

    public func updateMealPlanEntry(id: Int, _ body: MealieObject) async throws -> MealieObject {
        try await object("PUT", "households/mealplans/\(id)", body: body)
    }

    public func deleteMealPlanEntry(id: Int) async throws {
        _ = try await send("DELETE", "households/mealplans/\(id)", allowing: [404])
    }

    // MARK: - Shopping lists

    public func shoppingLists() async throws -> [MealieShoppingList] {
        try await paged("households/shopping/lists").compactMap { item in
            guard let id = item["id"] as? String else { return nil }
            return MealieShoppingList(id: id, name: item["name"] as? String ?? "")
        }
    }

    public func createShoppingList(name: String) async throws -> MealieShoppingList {
        let created = try await object("POST", "households/shopping/lists", body: ["name": name])
        guard let id = created["id"] as? String else { throw MealieError.notMealie }
        return MealieShoppingList(id: id, name: name)
    }

    public func shoppingItems(list: String) async throws -> [MealieObject] {
        try await object("GET", "households/shopping/lists/\(list)")["listItems"] as? [MealieObject] ?? []
    }

    public func createShoppingItem(_ body: MealieObject) async throws -> MealieObject {
        let result = try await object("POST", "households/shopping/items", body: body)
        guard let created = (result["createdItems"] as? [MealieObject])?.first else { throw MealieError.notMealie }
        return created
    }

    public func updateShoppingItem(id: String, _ body: MealieObject) async throws -> MealieObject {
        let result = try await object("PUT", "households/shopping/items/\(id)", body: body)
        return (result["updatedItems"] as? [MealieObject])?.first ?? result
    }

    public func deleteShoppingItem(id: String) async throws {
        _ = try await send("DELETE", "households/shopping/items", query: [("ids", id)], allowing: [404])
    }

    // MARK: - Transport

    private func paged(_ path: String, query: [(String, String)] = []) async throws -> [MealieObject] {
        var items: [MealieObject] = []
        var page = 1
        while true {
            let result = try await object("GET", path, query: query + [("page", "\(page)"), ("perPage", "200")])
            let batch = result["items"] as? [MealieObject] ?? []
            items += batch
            let totalPages = (result["total_pages"] as? NSNumber)?.intValue ?? 1
            if batch.isEmpty || page >= totalPages { return items }
            page += 1
        }
    }

    private func object(_ method: String, _ path: String, query: [(String, String)] = [], body: MealieObject? = nil) async throws -> MealieObject {
        let payload = try body.map { try JSONSerialization.data(withJSONObject: $0) }
        let (data, _) = try await send(method, path, query: query, body: payload)
        guard let object = try? JSONSerialization.jsonObject(with: data) as? MealieObject else { throw MealieError.notMealie }
        return object
    }

    private func send(
        _ method: String,
        _ path: String,
        query: [(String, String)] = [],
        body: Data? = nil,
        contentType: String = "application/json",
        allowing extra: Set<Int> = []
    ) async throws -> (Data, HTTPURLResponse) {
        var url = server.appendingPathComponent("api")
        for part in path.split(separator: "/") { url.appendPathComponent(String(part)) }
        if !query.isEmpty {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) }
            url = components?.url ?? url
        }
        var request = URLRequest(url: url, timeoutInterval: 30)
        request.httpMethod = method
        request.httpBody = body
        if !token.isEmpty { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil { request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw MealieError.unreachable(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else { throw MealieError.server(0, "No response.") }
        switch http.statusCode {
        case 200..<300: return (data, http)
        case let status where extra.contains(status): return (data, http)
        case 401: throw MealieError.unauthorized
        default: throw MealieError.server(http.statusCode, Self.message(in: data))
        }
    }

    private static func message(in data: Data) -> String {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? MealieObject else { return "Unexpected response." }
        if let detail = json["detail"] as? String { return detail }
        if let detail = json["detail"] as? [MealieObject], let message = detail.first?["msg"] as? String { return message }
        if let detail = json["detail"] as? MealieObject, let message = detail["message"] as? String { return message }
        return "Unexpected response."
    }
}

enum MealieDate {
    static func format(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    /// Mealie writes `…09.569421Z` in one place and `…09.569421+00:00` in another; both parse to the same millisecond.
    static func parse(_ text: String) -> Date? {
        var text = text.replacingOccurrences(of: "+00:00", with: "Z")
        if !text.hasSuffix("Z") { text += "Z" }
        if let range = text.range(of: #"\.\d+"#, options: .regularExpression) {
            let digits = text[text.index(after: range.lowerBound)..<range.upperBound].prefix(3)
            text.replaceSubrange(range, with: "." + String(digits).padding(toLength: 3, withPad: "0", startingAt: 0))
        }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: text) ?? ISO8601DateFormatter().date(from: text)
    }
}

private extension Data {
    mutating func append(_ text: String) { append(Data(text.utf8)) }
}
