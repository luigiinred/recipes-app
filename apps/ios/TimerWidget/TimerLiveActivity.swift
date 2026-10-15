import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        TimerLiveActivity()
    }
}

private let accent = Color(red: 0.86, green: 0.28, blue: 0.22)

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            HStack(spacing: 14) {
                Image(systemName: "timer")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.isStale ? "Timer done" : "Timer").font(.caption).foregroundStyle(.secondary)
                    Text(context.attributes.label).font(.headline).lineLimit(1)
                }
                Spacer(minLength: 8)
                Countdown(context: context).font(.system(size: 34, weight: .semibold, design: .rounded)).monospacedDigit()
            }
            .padding(16)
            .activityBackgroundTint(Color(red: 0.17, green: 0.14, blue: 0.125))
            .activitySystemActionForegroundColor(.white)
            .foregroundStyle(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "timer").font(.title2).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(context: context).font(.title2.weight(.semibold)).monospacedDigit().frame(width: 96, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.label).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(accent)
            } compactTrailing: {
                Countdown(context: context).monospacedDigit().frame(width: 52)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(accent)
            }
        }
    }
}

private struct Countdown: View {
    let context: ActivityViewContext<TimerActivityAttributes>

    var body: some View {
        if context.isStale {
            Text("Done").foregroundStyle(accent)
        } else {
            Text(timerInterval: context.attributes.startedAt...context.state.endsAt, pauseTime: nil, countsDown: true, showsHours: false)
                .multilineTextAlignment(.trailing)
        }
    }
}
