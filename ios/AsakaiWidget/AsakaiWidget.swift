import SwiftUI
import WidgetKit

private let appGroup = "group.com.asakai.asakai"

struct AsakaiEntry: TimelineEntry {
    let date: Date
    let isCurrent: Bool
    let title: String
    let prompt: String
    let lines: [String]
}

struct AsakaiProvider: TimelineProvider {
    func placeholder(in context: Context) -> AsakaiEntry {
        let copy = localizedCopy()
        return AsakaiEntry(date: .now, isCurrent: false, title: copy.title, prompt: copy.prompt, lines: [])
    }

    func getSnapshot(in context: Context, completion: @escaping (AsakaiEntry) -> Void) {
        completion(loadEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AsakaiEntry>) -> Void) {
        let entry = loadEntry()
        let nextMidnight = Calendar.current.nextDate(
            after: .now,
            matching: DateComponents(hour: 0, minute: 0, second: 0),
            matchingPolicy: .nextTime
        ) ?? .now.addingTimeInterval(24 * 60 * 60)
        let rollover = AsakaiEntry(
            date: nextMidnight,
            isCurrent: false,
            title: entry.title,
            prompt: entry.prompt,
            lines: []
        )
        completion(Timeline(entries: [entry, rollover], policy: .after(nextMidnight)))
    }

    private func loadEntry() -> AsakaiEntry {
        let defaults = UserDefaults(suiteName: appGroup)
        let copy = localizedCopy()
        let title = defaults?.string(forKey: "asakai_widget_title") ?? copy.title
        let prompt = defaults?.string(forKey: "asakai_widget_prompt") ?? copy.prompt
        let storedDate = defaults?.string(forKey: "asakai_widget_date")
        let lines = (defaults?.string(forKey: "asakai_widget_lines") ?? "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        return AsakaiEntry(
            date: .now,
            isCurrent: storedDate == localDateKey(),
            title: title,
            prompt: prompt,
            lines: lines
        )
    }

    private func localDateKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }

    private func localizedCopy() -> (title: String, prompt: String) {
        Locale.current.language.languageCode?.identifier == "ja"
            ? ("今日のタスク", "今日は何をする？")
            : ("Today’s Tasks", "What are you planning today?")
    }
}

struct AsakaiWidgetView: View {
    let entry: AsakaiEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(entry.title)
                .font(.headline)
                .lineLimit(1)
            if entry.isCurrent && !entry.lines.isEmpty {
                ForEach(Array(entry.lines.prefix(6).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.body)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 0)
            } else {
                Spacer()
                Text(entry.prompt)
                    .font(.body)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .containerBackground(for: .widget) {
            Color("WidgetBackground")
        }
        .widgetURL(URL(string: "asakai://today"))
    }
}

@main
struct AsakaiWidget: Widget {
    let kind = "AsakaiWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AsakaiProvider()) { entry in
            AsakaiWidgetView(entry: entry)
        }
        .configurationDisplayName("ASAKAI")
        .description("Your tasks for today.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
