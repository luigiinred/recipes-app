import Foundation

enum AppStoreLink {
    /// The numeric Apple ID from App Store Connect; Settings hides the support section without it.
    static let appID: String? = "6822002864"

    static var listing: URL? {
        appID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)") }
    }

    static var writeReview: URL? {
        appID.flatMap { URL(string: "https://apps.apple.com/app/id\($0)?action=write-review") }
    }
}
