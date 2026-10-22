import ActivityKit
import AlarmKit
import SwiftUI
import WidgetKit

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
        MealPlanWidget()
        UpNextWidget()
        GroceriesWidget()
        RandomRecipeWidget()
    }
}

private typealias TimerContext = ActivityViewContext<AlarmAttributes<TimerAlarmMetadata>>

private let accent = Color(red: 0.86, green: 0.28, blue: 0.22)

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: AlarmAttributes<TimerAlarmMetadata>.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isDone(context) ? "Timer done" : "Timer").font(.caption).foregroundStyle(.secondary)
                    Text(label(context)).font(.headline).lineLimit(1)
                }
                Spacer(minLength: 8)
                Countdown(context: context).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.17, green: 0.14, blue: 0.125))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
            .widgetURL(url(context))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer").font(.title2).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(context: context).font(.title2.weight(.semibold)).monospacedDigit().frame(width: 96, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(label(context)).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(accent)
            } compactTrailing: {
                Countdown(context: context).monospacedDigit().frame(width: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(accent)
            }
            .widgetURL(url(context))
        }
    }

    private func label(_ context: TimerContext) -> String { context.attributes.metadata?.label ?? "Timer" }

    private func url(_ context: TimerContext) -> URL? { context.attributes.metadata?.recipeID.map(RecipeLink.cookURL(for:)) }

    private func isDone(_ context: TimerContext) -> Bool {
        if case .alert = context.state.mode { return true }
        return false
    }
}

private struct Countdown: View {
    let context: TimerContext

    var body: some View {
        switch context.state.mode {
        case .countdown(let countdown):
            Text(timerInterval: countdown.startDate...countdown.fireDate, pauseTime: nil, countsDown: true, showsHours: false)
                .multilineTextAlignment(.trailing)
        case .paused(let paused):
            Text(Duration.seconds(max(0, paused.totalCountdownDuration - paused.previouslyElapsedDuration)), format: .time(pattern: .minuteSecond))
        case .alert:
            Text("Done").foregroundStyle(accent)
        @unknown default:
            EmptyView()
        }
    }
}
