import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var captchaId: String?
    @State private var captchaImage: UIImage?
    @State private var captchaAnswer = ""
    @State private var isLoadingCaptcha = false

    var body: some View {
        CompatNavigationStack {
            ZStack {
                ITDOBackground()
                ScrollView {
                    VStack(spacing: 14) {
                        GlassTextField(title: "Имя", text: $name)
                        GlassTextField(title: "Логин", text: $username)
                        GlassTextField(title: "Email (необязательно)", text: $email)
                        GlassTextField(title: "Пароль", text: $password, isSecure: true)

                        captchaSection

                        if let error = session.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(DesignTokens.error)
                        }

                        Button {
                            Task {
                                await session.register(
                                    name: name, username: username, email: email, password: password,
                                    captchaId: captchaId, captchaAnswer: captchaAnswer
                                )
                                if session.pendingUser != nil {
                                    // СНАЧАЛА закрываем sheet, ПОТОМ переключаем view.
                                    // Иначе LoginView удаляется из иерархии пока sheet ещё открыт → краш.
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        session.completeRegistration()
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                if session.isLoading { ProgressView().tint(DesignTokens.textPrimary) }
                                Text("Зарегистрироваться").fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        }
                        .glassButton()
                        .tint(DesignTokens.accentPrimary)
                        .disabled(username.isEmpty || password.isEmpty || session.isLoading)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Регистрация")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Закрыть") { dismiss() }
                }
            }
            .task { await loadCaptcha() }
        }
    }

    private var captchaSection: some View {
        VStack(spacing: 8) {
            Group {
                if let captchaImage {
                    Image(uiImage: captchaImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 70)
                } else {
                    ProgressView()
                        .frame(height: 70)
                }
            }
            .frame(maxWidth: .infinity)
            .glassPanel(cornerRadius: 12)

            HStack {
                GlassTextField(title: "Ответ с картинки", text: $captchaAnswer)
                Button {
                    Task { await loadCaptcha() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .padding(10)
                }
                .glassButton()
            }
        }
    }

    private func loadCaptcha() async {
        isLoadingCaptcha = true
        defer { isLoadingCaptcha = false }
        do {
            let response: CaptchaResponse = try await APIClient.shared.request("auth/captcha.php")
            captchaId = response.captcha_id
            if let commaIndex = response.image.firstIndex(of: ","),
               let data = Data(base64Encoded: String(response.image[response.image.index(after: commaIndex)...])) {
                captchaImage = UIImage(data: data)
            }
        } catch {
            session.errorMessage = "Не удалось загрузить капчу"
        }
    }
}

#Preview {
    RegisterView().environmentObject(SessionStore())
}
