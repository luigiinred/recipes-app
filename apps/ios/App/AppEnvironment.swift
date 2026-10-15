import SwiftUI

private struct ReferenceDateKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    /// Fixes "now" so previews and snapshot tests render the same every run.
    var referenceDate: Date? {
        get { self[ReferenceDateKey.self] }
        set { self[ReferenceDateKey.self] = newValue }
    }
}

extension Date: @retroactive Identifiable {
    public var id: TimeInterval { timeIntervalSince1970 }
}
