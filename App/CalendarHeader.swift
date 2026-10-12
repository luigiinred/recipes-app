import RecipeKit
import SwiftUI

enum CalendarRange: String, CaseIterable {
    case week, month

    var title: String { self == .week ? "Week" : "Month" }
}

/// A week strip or month grid with a dot under every day that has something planned.
struct CalendarHeader: View {
    @Binding var range: CalendarRange
    @Binding var selected: Date
    let counts: [String: Int]
    let today: Date

    @AppStorage(AppSettings.Key.weekStart) private var weekStartSetting = AppSettings.WeekStart.system.rawValue
    private var calendar: Calendar { AppSettings.calendar(weekStart: weekStartSetting) }

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Text(title).font(.system(.title3, design: .serif, weight: .semibold))
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(CalendarRange.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
                HStack(spacing: 2) {
                    Button { shift(-1) } label: { Image(systemName: "chevron.left").frame(width: 30, height: 30) }
                    Button { selected = calendar.startOfDay(for: today) } label: { Image(systemName: "circle.fill").font(.system(size: 6)).frame(width: 24, height: 30) }
                    Button { shift(1) } label: { Image(systemName: "chevron.right").frame(width: 30, height: 30) }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol).font(.caption2.weight(.semibold)).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
            ForEach(rows, id: \.first) { row in
                HStack(spacing: 0) {
                    ForEach(row, id: \.self) { day in cell(day) }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .gesture(DragGesture(minimumDistance: 30).onEnded { value in
            if abs(value.translation.width) > abs(value.translation.height) { shift(value.translation.width < 0 ? 1 : -1) }
        })
    }

    private var title: String {
        selected.formatted(range == .month ? .dateTime.month(.wide).year() : .dateTime.month(.abbreviated).day().year())
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var rows: [[Date]] {
        switch range {
        case .week:
            return [weekDays(of: selected)]
        case .month:
            guard let month = calendar.dateInterval(of: .month, for: selected) else { return [] }
            let first = weekDays(of: month.start)[0]
            let weeks = Int(ceil(Double(calendar.dateComponents([.day], from: first, to: month.end).day ?? 35) / 7))
            return (0..<weeks).map { week in
                (0..<7).compactMap { calendar.date(byAdding: .day, value: week * 7 + $0, to: first) }
            }
        }
    }

    private func weekDays(of date: Date) -> [Date] {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private func shift(_ direction: Int) {
        let component: Calendar.Component = range == .month ? .month : .weekOfYear
        if let next = calendar.date(byAdding: component, value: direction, to: selected) { selected = next }
    }

    private func cell(_ day: Date) -> some View {
        let isSelected = calendar.isDate(day, inSameDayAs: selected)
        let isToday = calendar.isDate(day, inSameDayAs: today)
        let inMonth = range == .week || calendar.isDate(day, equalTo: selected, toGranularity: .month)
        let count = counts[DayKey.string(from: day)] ?? 0
        return Button { selected = day } label: {
            VStack(spacing: 2) {
                Text(day, format: .dateTime.day())
                    .font(.system(.body, design: .rounded, weight: isSelected || isToday ? .semibold : .regular))
                    .frame(width: 34, height: 34)
                    .foregroundStyle(isSelected ? Color.white : (isToday ? Theme.accent : (inMonth ? Color.primary : Color.secondary.opacity(0.5))))
                    .background(isSelected ? Theme.accent : Color.clear, in: Circle())
                HStack(spacing: 3) {
                    ForEach(0..<min(count, 3), id: \.self) { _ in
                        Circle().fill(isSelected ? Theme.accent : Theme.accent.opacity(0.7)).frame(width: 5, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).month().day()) + (count > 0 ? ", \(count) planned" : ""))
    }
}
