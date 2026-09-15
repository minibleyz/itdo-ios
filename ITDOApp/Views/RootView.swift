import SwiftUI

struct RootView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var didRestore = false
    @State private var selection = 0
    @State private var showMore = false
    @State private var moreSelection: MoreItem?
    @EnvironmentObject private var composeTrigger: ComposeTrigger

    struct MoreItem: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let view: AnyView
    }

    private var moreSections: [(String, [MoreItem])] {
        [
            ("Активность", [
                MoreItem(title: "Уведомления", icon: "bell", view: AnyView(NotificationsView())),
                MoreItem(title: "Лидерборд", icon: "trophy", view: AnyView(LeaderboardView())),
                MoreItem(title: "Квесты", icon: "checklist", view: AnyView(QuestsView())),
            ]),
            ("Медиа", [
                MoreItem(title: "Клипы", icon: "play.rectangle", view: AnyView(ClipsView())),
                MoreItem(title: "Плейлисты", icon: "music.note.list", view: AnyView(PlaylistsView())),
                MoreItem(title: "Статьи", icon: "doc.text", view: AnyView(ArticlesListView())),
                MoreItem(title: "Эфиры", icon: "dot.radiowaves.left.and.right", view: AnyView(StreamsListView())),
            ]),
            ("ИИ", [
                MoreItem(title: "ITDO Agent", icon: "sparkles", view: AnyView(AgentChatView())),
            ]),
            ("Финансы", [
                MoreItem(title: "Кошелёк", icon: "creditcard", view: AnyView(WalletView())),
                MoreItem(title: "ITDO Pro", icon: "star.fill", view: AnyView(NukstaView())),
            ]),
        ]
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selection) {
                FeedView()
                    .tabItem { Label("Лента", systemImage: "house") }
                    .tag(0)

                ExploreView()
                    .tabItem { Label("Поиск", systemImage: "magnifyingglass") }
                    .tag(1)

                Color.clear
                    .tabItem { Label("Создать", systemImage: "plus.circle") }
                    .tag(2)

                MessagesView()
                    .tabItem { Label("Сообщения", systemImage: "message") }
                    .tag(3)

                ProfileView()
                    .tabItem { Label("Профиль", systemImage: "person") }
                    .tag(4)
            }
            .onChange(of: selection) { _, newValue in
                if newValue == 2 {
                    selection = 0
                    composeTrigger.show = true
                }
            }
        }
        .sheet(isPresented: $composeTrigger.show) {
            ComposeView()
        }
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected {
                offlineBanner
            }
        }
        .task {
            guard !didRestore else { return }
            didRestore = true
            await session.restoreSession()
        }
        .sheet(item: $moreSelection) { item in
            item.view
        }
    }

    private var offlineBanner: some View {
        Text("Нет соединения с интернетом")
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(Color.red)
    }
}
