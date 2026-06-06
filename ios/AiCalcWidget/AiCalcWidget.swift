import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct CalcEntry: TimelineEntry {
    let date: Date
    let expression: String
    let result: String
}

// MARK: - Timeline Provider

struct CalcProvider: TimelineProvider {
    private let appGroupID = "group.com.yama.genbacalc"

    func placeholder(in context: Context) -> CalcEntry {
        CalcEntry(date: Date(), expression: "12 × 3.5", result: "42")
    }

    func getSnapshot(in context: Context, completion: @escaping (CalcEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CalcEntry>) -> Void) {
        let entry = loadEntry()
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }

    private func loadEntry() -> CalcEntry {
        let ud = UserDefaults(suiteName: appGroupID)
        let expression = ud?.string(forKey: "last_expression") ?? ""
        let result = ud?.string(forKey: "last_result") ?? "タップして起動"
        return CalcEntry(date: Date(), expression: expression, result: result)
    }
}

// MARK: - Widget View

struct CalcWidgetEntryView: View {
    var entry: CalcProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if family != .accessoryRectangular && family != .accessoryInline {
                Text("GenbaCalc")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !entry.expression.isEmpty {
                Text(entry.expression)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.head)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            Text(entry.result)
                .font(family == .accessoryCircular ? .caption : .title2)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.4)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(family == .accessoryRectangular ? 0 : 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            Color(red: 0.05, green: 0.05, blue: 0.08)
        }
    }
}

// MARK: - Widget Configuration

struct AiCalcWidget: Widget {
    let kind: String = "AiCalcWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CalcProvider()) { entry in
            CalcWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("GenbaCalc")
        .description("最近の計算結果を表示し、アプリを素早く起動できます")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryRectangular,
            .accessoryCircular,
            .accessoryInline,
        ])
    }
}

// MARK: - Preview

#Preview(as: .systemSmall) {
    AiCalcWidget()
} timeline: {
    CalcEntry(date: .now, expression: "12 × 3.5", result: "42")
}
