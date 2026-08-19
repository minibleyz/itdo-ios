import SwiftUI

@main
struct ITDOApp: App {
    @StateObject private var session = SessionStore()
    @StateObject private var rtc = WebRTCManager.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showIncomingCall = false
    // Тумблер "Тёмная тема" в настройках менял AppStorage("dark_mode"), но здесь
    // всегда был захардкожен .dark — поэтому светлая тема никогда не включалась.
    @AppStorage("dark_mode") private var isDarkMode = true

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(session)
                .preferredColorScheme(isDarkMode ? .dark : .light)
                .task {
                    // Стартуем мониторинг сети как можно раньше — до
                    // restoreSession() в RootView, — чтобы холодный запуск
                    // без интернета сразу знал об этом и не пытался
                    // разлогинить пользователя по таймауту (см. NetworkMonitor.swift).
                    NetworkMonitor.shared.start()
                }
                .onChange(of: scenePhase) { _, phase in
                    switch phase {
                    case .active:
                        // Приложение на переднем плане — подключаем WS
                        if session.currentUser != nil {
                            WSClient.shared.connect()
                            Task { try? await APIClient.shared.setOnline() }
                            // Вернулись из фона/офлайна — досинхронизируем
                            // профиль, если в прошлый раз не получилось.
                            if session.isOfflineSession {
                                Task { await session.refreshProfile() }
                            }
                        }
                    case .background:
                        // Ушли в фон — отключаем WS
                        WSClient.shared.disconnect()
                        Task { try? await APIClient.shared.setOffline() }
                    default:
                        break
                    }
                }
                .onChange(of: rtc.callState) { _, newState in
                    // PushKit получил входящий звонок — показываем UI
                    if case .incomingRinging = newState {
                        showIncomingCall = true
                    }
                }
                .fullScreenCover(isPresented: $showIncomingCall) {
                    if case .incomingRinging(let callId, let callerName, let callType) = rtc.callState {
                        IncomingCallScreen(
                            callId: callId,
                            callerName: callerName,
                            callType: callType,
                            rtc: rtc,
                            onDismiss: { showIncomingCall = false }
                        )
                    }
                }
        }
    }
}

/// Полноэкранный UI входящего звонка (показывается поверх всего, включая экран блокировки)
struct IncomingCallScreen: View {
    let callId: Int
    let callerName: String
    let callType: String
    @ObservedObject var rtc: WebRTCManager
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(hex: "#1a1a2e")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Аватар
                Circle()
                    .fill(DesignTokens.accentPrimary.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Text(callerName.prefix(1).uppercased())
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(DesignTokens.accentPrimary)
                    )

                VStack(spacing: 8) {
                    Text(callerName)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)

                    Text(callType == "video" ? "Видеозвонок" : "Аудиозвонок")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.7))
                }

                Spacer()

                // Кнопки
                HStack(spacing: 60) {
                    // Отклонить
                    Button {
                        rtc.declineCall(callId: callId)
                        onDismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: "phone.down.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.red)
                                .clipShape(Circle())
                            Text("Отклонить")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }

                    // Принять
                    Button {
                        rtc.acceptCall(callId: callId)
                        onDismiss()
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: callType == "video" ? "video.fill" : "phone.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(.white)
                                .frame(width: 70, height: 70)
                                .background(Color.green)
                                .clipShape(Circle())
                            Text("Принять")
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .statusBarHidden(true)
    }
}
