import RecipeKit
import SwiftUI

struct WeekBar: View {
    @Binding var weekStart: Date
    let calendar: Calendar
    let today: Date

    private var days: [Date] { (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) } }
    private var isThisWeek: Bool { days.contains { calendar.isDate($0, inSameDayAs: today) } }

    var body: some View {
        HStack(spacing: 12) {
            Button { shift(-1) } label: { Image(systemName: "chevron.left") }
                .accessibilityLabel("Previous week")
            Text(rangeTitle).appFont(.headline).frame(maxWidth: .infinity)
                .contentTransition(.numericText())
            Button { shift(1) } label: { Image(systemName: "chevron.right") }
                .accessibilityLabel("Next week")
        }
        .buttonStyle(.plain)
        .foregroundStyle(Theme.accent)
        .padding(.horizontal, 20).padding(.vertical, 6)
        .overlay(alignment: .trailing) {
            if !isThisWeek {
                Button("Today") { withAnimation(.snappy) { weekStart = calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today } }
                    .appFont(.footnote, weight: .semibold).foregroundStyle(Theme.accent)
                    .padding(.trailing, 48)
            }
        }
    }

    private var rangeTitle: String {
        guard let last = days.last else { return "" }
        let style = Date.FormatStyle().month(.abbreviated).day()
        return "\(weekStart.formatted(style)) – \(last.formatted(style))"
    }

    private func shift(_ weeks: Int) {
        withAnimation(.snappy) { weekStart = calendar.date(byAdding: .weekOfYear, value: weeks, to: weekStart) ?? weekStart }
    }
}
