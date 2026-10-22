#if os(iOS)
import AlarmKit
import Foundation

struct TimerAlarmMetadata: AlarmMetadata {
    var label: String
    var recipeID: UUID?
}
#endif
