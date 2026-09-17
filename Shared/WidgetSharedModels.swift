import Foundation

/// Shared App Group identifier and payload models used by the app and widget.
enum SharedStorage {
    static let appGroupID = "group.ru.bleyzos.itdo"
    static let recentDataKey = "widget.recentData"

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }
}

struct RecentChatItem: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let timestamp: Date
    let hasUnreadNotification: Bool
    let avatarSystemImage: String
}

struct RecentCallItem: Codable, Identifiable {
    let id: String
    let name: String
    let missed: Bool
    let timestamp: Date
}

struct WidgetSharedData: Codable {
    var chats: [RecentChatItem]
    var calls: [RecentCallItem]
    var updatedAt: Date
}
