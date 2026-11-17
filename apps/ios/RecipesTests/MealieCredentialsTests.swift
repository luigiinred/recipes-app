import Foundation
import Testing
@testable import Recipes

@Suite("Mealie credentials", .serialized)
struct MealieCredentialsTests {
    private let service = "\(MealieCredentials.service).tests.\(UUID().uuidString)"

    @Test("a saved connection reads back, even in a build that can't use the iCloud Keychain")
    func savedConnectionReadsBack() {
        defer { MealieCredentials.clear(service: service) }
        let connection = MealieCredentials.Connection(server: "https://mealie.example.com", username: "sam", token: "header.payload.signature")

        #expect(MealieCredentials.save(connection, service: service))
        #expect(MealieCredentials.load(service: service) == connection)

        let replaced = MealieCredentials.Connection(server: "https://mealie.example.com", username: "sam", token: "header.other.signature")
        #expect(MealieCredentials.save(replaced, service: service))
        #expect(MealieCredentials.load(service: service) == replaced)

        MealieCredentials.clear(service: service)
        #expect(MealieCredentials.load(service: service) == nil)
    }
}
