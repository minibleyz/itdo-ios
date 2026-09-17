import WidgetKit
import SwiftUI

// MARK: - Timeline Entry

struct RecentEntry: TimelineEntry {
    let date: Date
    let data: WidgetSharedData
}

// MARK: - Provider

struct RecentProvider: TimelineProvider {
    func placeholder(in context: Context) -> RecentEntry {
        RecentEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RecentEntry) -> Void) {
        completion(RecentEntry(
            date: Date(),
            data: context.isPreview ? .placeholder : loadSharedData()
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<RecentEntry>) -> Void) {
        let now = Date()
        let nextRefresh = Calendar.current.date(byAdding: .minute, value: 15, to: now)
            ?? now.addingTimeInterval(900)
        completion(Timeline(
            entries: [RecentEntry(date: now, data: loadSharedData())],
            policy: .after(nextRefresh)
        ))
    }

    private func loadSharedData() -> WidgetSharedData {
        guard
            let defaults = SharedStorage.defaults,
            let raw = defaults.data(forKey: SharedStorage.recentDataKey),
            let decoded = try? JSONDecoder().decode(WidgetSharedData.self, from: raw)
        else {
            return .empty
        }
        return decoded
    }
}

extension WidgetSharedData {
    static let empty = WidgetSharedData(chats: [], calls: [], updatedAt: .distantPast)

    static let placeholder = WidgetSharedData(
        chats: [
            RecentChatItem(
                id: "1",
                title: "Анна",
                subtitle: "Привет! Ты завтра свободна?",
                timestamp: Date(),
                hasUnreadNotification: true,
                avatarSystemImage: "person.crop.circle"
            ),
            RecentChatItem(
                id: "2",
                title: "Рабочий чат",
                subtitle: "Митап в 15:00",
                timestamp: Date().addingTimeInterval(-3600),
                hasUnreadNotification: false,
                avatarSystemImage: "person.3"
            )
        ],
        calls: [
            RecentCallItem(
                id: "1",
                name: "Игорь",
                missed: true,
                timestamp: Date().addingTimeInterval(-1800)
            )
        ],
        updatedAt: Date()
    )
}

struct ITDOAppWidget: Widget {
    let kind = "ITDOAppRecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: RecentProvider()) { entry in
            RecentWidgetView(data: entry.data)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Недавнее в ITDO")
        .description("Последние чаты с уведомлениями и недавние звонки.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@main
struct ITDOAppWidgetBundle: WidgetBundle {
    var body: some Widget {
        ITDOAppWidget()
    }
}
