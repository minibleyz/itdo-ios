# ITDO — нативное iOS-приложение (SwiftUI + Liquid Glass)

Сборка полностью автоматизирована через GitHub Actions — тебе не нужен Mac,
Xcode или macOS вообще. Раннер GitHub сам генерирует Xcode-проект, собирает
и упаковывает unsigned `.ipa`.

## Как собрать .ipa (3 шага)

1. **Создай репозиторий на GitHub** и залей туда содержимое этой папки:
   ```
   git init
   git add .
   git commit -m "ITDO iOS app"
   git branch -M main
   git remote add origin https://github.com/<твой_юзернейм>/itdo-app.git
   git push -u origin main
   ```

2. **Дождись сборки.** Как только запушишь в `main`, GitHub Actions
   (файл `.github/workflows/build-ipa.yml`) автоматически:
   - установит XcodeGen
   - сгенерирует `ITDOApp.xcodeproj` из `project.yml`
   - соберёт unsigned архив (`CODE_SIGNING_ALLOWED=NO`)
   - запакует `ITDOApp.app` → `ITDOApp-unsigned.ipa`

   Прогресс смотри во вкладке **Actions** твоего репозитория.

3. **Скачай .ipa.** На странице завершившегося workflow-рана внизу будет
   раздел **Artifacts** → `ITDOApp-unsigned-ipa` → скачать zip, внутри
   `ITDOApp-unsigned.ipa`.

Если не хочешь пушить в `main` — workflow можно запустить и вручную:
вкладка **Actions** → **Build unsigned IPA** → **Run workflow**.

## Про unsigned .ipa

Файл не подписан сертификатом Apple (`CODE_SIGNING_ALLOWED=NO`), поэтому
поставить его напрямую через iTunes/Finder не получится — телефон отклонит
неподписанное приложение. Варианты установки:

- **AltStore / Sideloadly** — сами подписывают .ipa твоим бесплатным Apple ID
  при установке на устройство (лимит 7 дней, потом переустановка).
- **Свой сертификат** — если появится платный Apple Developer аккаунт,
  добавь `DEVELOPMENT_TEAM` и `CODE_SIGN_STYLE: Automatic` в `project.yml`,
  укажи Team ID и сертификат/профиль как секреты репозитория — тогда
  workflow сможет собрать сразу подписанный .ipa.

## Структура репозитория

```
ITDOApp/
├── project.yml              # XcodeGen-спека — описывает проект вместо .xcodeproj
├── .github/workflows/
│   └── build-ipa.yml        # CI: генерация проекта + сборка + упаковка .ipa
└── ITDOApp/
    ├── ITDOApp.swift        # @main точка входа
    ├── Info.plist
    ├── Models/               # Codable-модели под ответы api/*.php
    ├── Networking/           # APIClient, AgentStreamClient (SSE), Keychain
    ├── ViewModels/           # SessionStore, StreamsViewModel, AgentChatViewModel
    └── Views/
        ├── Auth/             # LoginView, RegisterView (капча с сервера)
        ├── Streams/          # список эфиров + HLS-плеер
        ├── Agent/            # чат с AI-агентом (стриминг ответа)
        ├── Profile/
        └── Components/       # LiquidGlass.swift — дизайн-система (.glassEffect)
```

## Настройки

- Базовый адрес API — `ITDOApp/Networking/APIConfig.swift` → `baseURL`
  (сейчас `https://itdo.bleyzos.ru`).
- Bundle ID — `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER`
  (сейчас `ru.bleyzos.itdo.app`, поменяй на своё при необходимости).
- Минимальная iOS — `project.yml` → `deploymentTarget.iOS` (сейчас 17.0,
  Liquid Glass эффекты активируются автоматически на iOS 26+, на более
  старых — аккуратный фолбэк на `.ultraThinMaterial`).

## Что уже реализовано

- Auth: вход, регистрация с реальной капчей-картинкой с сервера, токен в Keychain.
- Streams: лента прямых эфиров (грид), просмотр через HLS (AVKit).
- Agent: чат с AI-ассистентом, ответ печатается потоково (SSE), история бесед.
- Profile: данные пользователя, баланс монет, выход из аккаунта.
- Liquid Glass: `.glassPanel()`, `.glassButton()`, `GlassGroup` — использует
  нативный iOS 26 API (`glassEffect`, `GlassEffectContainer`).

## Что не перенесено (веб-проект намного больше)

Группы, донаты, клипы, лидерборд, verification, RTMP-стрим с камеры,
push-уведомления и т.д. — в исходнике ~100 PHP-эндпоинтов. Каркас
(auth → лента → просмотр → AI-агент → профиль) готов и собирается в CI;
остальные разделы добавляются по той же схеме: модель в `Models.swift` →
метод в `APIClient`/ViewModel → View с `.glassPanel()`. Скажи, что добавить
следующим.
