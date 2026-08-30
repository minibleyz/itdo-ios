import SwiftUI
import UIKit

/// Оборачивает произвольный SwiftUI-контент в "защищённый" слой,
/// который iOS исключает из скриншотов, записи экрана/AirPlay и снимка
/// в App Switcher.
///
/// Основано на давно известном трюке с `UITextField.isSecureTextEntry`:
/// секретное текстовое поле рендерит своё содержимое через отдельный,
/// специально защищённый Core Animation слой (`_UITextLayoutCanvasView`
/// / `CASecureTextLayer` в зависимости от версии iOS) — тот же механизм,
/// что не даёт паролю "утечь" в скриншот. Система не документирует этот
/// layer публично, но его поведение стабильно используется в проде
/// банковскими приложениями и менеджерами паролей именно для этой цели.
/// Мы подставляем в этот слой не текст, а произвольный SwiftUI-контент
/// (например, PasscodeUnlockView).
///
/// Ограничение: это защита от штатных механизмов захвата экрана самой
/// iOS. От специализированных инструментов на джейлбрейке или внешней
/// камеры, направленной на экран, она не защищает — как и любое другое
/// приложение.
struct ScreenCaptureProtected<Content: View>: UIViewRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIView(context: Context) -> UIView {
        let secureField = UITextField()
        secureField.isSecureTextEntry = true

        // Защищённый слой — первый (и обычно единственный) sublayer поля;
        // его delegate — приватный UIView-контейнер, в который система и
        // рендерит "секретное" содержимое. Если Apple когда-нибудь изменит
        // эту деталь реализации и структура окажется другой — откатываемся
        // на обычный (незащищённый) хостинг контента, чтобы экран вообще
        // не сломался.
        guard let protectedLayer = secureField.layer.sublayers?.first,
              let containerView = protectedLayer.delegate as? UIView else {
            let fallback = UIHostingController(rootView: content).view!
            fallback.backgroundColor = .clear
            return fallback
        }

        containerView.subviews.forEach { $0.removeFromSuperview() }
        containerView.isUserInteractionEnabled = true

        let hosting = UIHostingController(rootView: content)
        hosting.view.backgroundColor = .clear
        hosting.view.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(hosting.view)
        NSLayoutConstraint.activate([
            hosting.view.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hosting.view.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hosting.view.topAnchor.constraint(equalTo: containerView.topAnchor),
            hosting.view.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])

        return containerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

extension View {
    /// Скрывает эту вью из скриншотов, записи экрана/AirPlay и снимка
    /// в App Switcher. См. `ScreenCaptureProtected`.
    func screenCaptureProtected() -> some View {
        ScreenCaptureProtected { self }
            .ignoresSafeArea()
    }
}
