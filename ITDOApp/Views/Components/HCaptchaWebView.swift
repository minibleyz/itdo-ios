import SwiftUI
import WebKit

/// Хостит РЕАЛЬНЫЙ hCaptcha-виджет (тот же sitekey, что и на вебе) в WKWebView.
/// Токен решённой капчи прилетает в Swift через WKScriptMessageHandler и
/// прокидывается в тело login/register запроса как `hcaptcha_token` —
/// именно то поле, которое реально проверяет бэкенд (`requireLoginCaptcha`
/// / `requireRegistrationCaptcha` → hCaptcha siteverify). Раньше форма
/// регистрации в приложении показывала СВОЮ отдельную математическую
/// капчу (auth/captcha.php + captcha_id/captcha_answer), а бэкенд её
/// вообще не читает — он спрашивает только hcaptcha_token. Поэтому
/// правильно решённая капча всё равно возвращала ошибку "не пройдена":
/// сервер проверял совсем другое поле, которого приложение не отправляло.
/// А у логина в приложении капчи не было вовсе, поэтому вход всегда
/// падал с 403 "Проверка hCaptcha обязательна".
struct HCaptchaWebView: UIViewRepresentable {
    /// Тот же sitekey, что используется на сайте (login.html / register).
    static let siteKey = "5f92e784-d356-42ce-8244-5672a768ae26"

    var onToken: (String) -> Void
    var onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onToken: onToken, onError: onError)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "hcaptchaHandler")
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.loadHTMLString(Self.html, baseURL: URL(string: "https://itdo.app/"))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "hcaptchaHandler")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        let onToken: (String) -> Void
        let onError: (String) -> Void

        init(onToken: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onToken = onToken
            self.onError = onError
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let dict = message.body as? [String: String] else { return }
            if let token = dict["token"], !token.isEmpty {
                onToken(token)
            } else if let error = dict["error"] {
                onError(error)
            }
        }
    }

    /// baseURL важен: hCaptcha делает клиентские проверки домена/origin,
    /// поэтому грузим виджет как "https://itdo.app/" (боевой домен сайта),
    /// а не file:// — иначе виджет может показывать ошибку интеграции
    /// сам по себе, ещё до отправки на бэкенд.
    private static let html = """
    <!DOCTYPE html>
    <html>
    <head>
      <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
      <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
      <style>
        html, body { margin:0; padding:0; background:transparent; display:flex; align-items:center; justify-content:center; min-height:100vh; }
      </style>
    </head>
    <body>
      <div class="h-captcha"
           data-sitekey="\(siteKey)"
           data-callback="onToken"
           data-expired-callback="onExpired"
           data-error-callback="onError"></div>
      <script>
        function onToken(token) {
          window.webkit.messageHandlers.hcaptchaHandler.postMessage({ token: token });
        }
        function onExpired() {
          window.webkit.messageHandlers.hcaptchaHandler.postMessage({ error: 'expired' });
        }
        function onError(err) {
          window.webkit.messageHandlers.hcaptchaHandler.postMessage({ error: String(err || 'hcaptcha-error') });
        }
      </script>
    </body>
    </html>
    """
}

/// Модальный экран капчи — переиспользуется и логином, и регистрацией.
struct HCaptchaSheet: View {
    let onCompleted: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let errorText {
                    Text(errorText)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                HCaptchaWebView(
                    onToken: { token in
                        onCompleted(token)
                        dismiss()
                    },
                    onError: { err in
                        errorText = "Капча не пройдена, попробуйте ещё раз (\(err))"
                    }
                )
                .frame(height: 120)
                Spacer()
            }
            .padding()
            .navigationTitle("Подтверждение")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
