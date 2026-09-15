import SwiftUI

// MARK: - Usernames (доп. NFT-стиль юзернеймы)

/// Экран «Доп. юзернеймы» (NFT-стиль @хендлы, как в вебе: @bleyzos, @minibleyz,
/// @test...). Покупка бронирует имя за Шлёпы — после покупки его больше нельзя
/// занять ни при регистрации, ни другим пользователем (см. isUsernameTakenAnywhere
/// на бэкенде). Любой купленный юзернейм можно сделать основным — 1:1 с
/// loadExtraUsernames()/buyExtraUsername()/switchExtraUsername() в assets/js/app.js.
struct UsernamesView: View {
    @EnvironmentObject private var session: SessionStore

    @State private var primaryUsername: String = ""
    @State private var extraUsernames: [String] = []
    @State private var price: Int = 0
    @State private var balance: Int = 0

    @State private var newUsername: String = ""
    @State private var isLoading = false
    @State private var isBuying = false
    @State private var switchingUsername: String?
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            ITDOBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Доп. юзернеймы")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(DesignTokens.textPrimary)
                        Text("Забронируйте себе ещё один @хендл — им можно поделиться, упомянуть в посте или сообщении, а потом в любой момент сделать основным.")
                            .font(.system(size: 13))
                            .foregroundStyle(DesignTokens.textSecondary)
                    }

                    if isLoading && extraUsernames.isEmpty && primaryUsername.isEmpty {
                        ProgressView().tint(DesignTokens.textPrimary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                    } else {
                        usernameList
                    }

                    buySection

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.error)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Юзернеймы")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var usernameList: some View {
        VStack(spacing: 0) {
            row(username: primaryUsername, isPrimary: true)
            ForEach(extraUsernames, id: \.self) { u in
                Divider().background(DesignTokens.borderSubtle)
                row(username: u, isPrimary: false)
            }
        }
        .background(DesignTokens.backgroundBlock)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    @ViewBuilder
    private func row(username: String, isPrimary: Bool) -> some View {
        HStack {
            Text("@\(username)")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DesignTokens.textPrimary)
            Spacer()
            if isPrimary {
                Text("основной")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.textSecondary)
            } else if switchingUsername == username {
                ProgressView().tint(DesignTokens.textPrimary)
            } else {
                Button {
                    Task { await switchUsername(username) }
                } label: {
                    Text("Сделать основным")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var buySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Купить новый юзернейм")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DesignTokens.textPrimary)

            HStack(spacing: 8) {
                Text("@")
                    .foregroundStyle(DesignTokens.textSecondary)
                TextField("username", text: $newUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundStyle(DesignTokens.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(DesignTokens.backgroundBlock)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await buy() }
            } label: {
                HStack {
                    if isBuying { ProgressView().tint(.white) }
                    Text("Купить за \(price.formatted()) Шлёпов")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .foregroundStyle(.white)
            .background(DesignTokens.accentPrimary)
            .clipShape(Capsule())
            .disabled(isBuying || newUsername.trimmingCharacters(in: .whitespaces).isEmpty)

            Text("Баланс: \(balance.formatted()) Шлёпов")
                .font(.caption)
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await APIClient.shared.fetchUsernames()
            primaryUsername = resp.username
            extraUsernames = resp.extraUsernames
            price = resp.price
            balance = resp.balance
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func buy() async {
        let username = newUsername.trimmingCharacters(in: .whitespaces)
        guard !username.isEmpty else { return }
        isBuying = true
        errorMessage = nil
        defer { isBuying = false }
        do {
            let resp = try await APIClient.shared.buyExtraUsername(username)
            extraUsernames = resp.extraUsernames
            balance = resp.balance
            newUsername = ""
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func switchUsername(_ username: String) async {
        switchingUsername = username
        errorMessage = nil
        defer { switchingUsername = nil }
        do {
            let resp = try await APIClient.shared.switchExtraUsername(username)
            primaryUsername = resp.username
            extraUsernames = resp.extraUsernames
            // User.username объявлен как `let`, точечно его не обновить —
            // подтягиваем профиль заново с сервера, чтобы шапка/профиль
            // сразу показали новый основной @хендл без перезахода в аккаунт.
            await session.refreshProfile()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { UsernamesView() }.environmentObject(SessionStore())
}
