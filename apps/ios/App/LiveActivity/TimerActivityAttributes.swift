#if os(iOS)
import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endsAt: Date
    }

    var label: String
    var startedAt: Date
}
#endif
