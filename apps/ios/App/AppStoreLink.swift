import Foundation

enum AppStoreLink {
    /// The numeric Apple ID from App Store Connect. Leave nil until the app is listed; Settings hides the support section without it.
    static let appID: String? = nil

    static var listing: URL? {
        appID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }

    static var writeReview: URL? {
        appID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}
