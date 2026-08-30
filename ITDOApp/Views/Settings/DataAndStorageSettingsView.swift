import SwiftUI

/// Экран "Данные и память" — адаптация одноимённого раздела настроек Telegram
/// (submodules/SettingsUI/Sources/Data and Storage/DataAndStorageSettingsController.swift)
/// под SwiftUI-стек ITDOApp. Оригинал написан на UIKit + AsyncDisplayKit и завязан
/// на внутренние фреймворки Telegram (AccountContext, TelegramCore, Postbox), поэтому
/// исходный файл скопировать напрямую нельзя — здесь воспроизведена структура разделов
/// и их смысл, переложенные на Form/@AppStorage в духе PerformanceSettingsView.
struct DataAndStorageSettingsView: View {
    // Автозагрузка медиа
    @AppStorage("data_autodownload_cellular") private var autoDownloadCellular = true
    @AppStorage("data_autodownload_wifi") private var autoDownloadWifi = true

    // Автосохранение
    @AppStorage("data_autosave_private") private var autoSavePrivateChats = true
    @AppStorage("data_autosave_groups") private var autoSaveGroups = false
    @AppStorage("data_autosave_channels") private var autoSaveChannels = false

    // Фоновая загрузка
    @AppStorage("data_download_in_background") private var downloadInBackground = true

    // Голосовые сообщения / звонки
    @AppStorage("data_voice_use_less_data") private var voiceUseLessData = false

    // Прочее
    @AppStorage("data_save_edited_photos") private var saveEditedPhotos = false
    @AppStorage("data_pause_music_on_recording") private var pauseMusicOnRecording = true
    @AppStorage("data_raise_to_listen") private var raiseToListen = true

    @State private var showResetConfirm = false
    @State private var showClearCacheConfirm = false
    @State private var isClearingCache = false
    @State private var cacheSize: String = "…"

    var body: some View {
        ZStack {
            ITDOBackground()
            Form {
                Section {
                    NavigationLink {
                        StorageUsageView()
                    } label: {
                        HStack {
                            Label("Использование памяти", systemImage: "internaldrive")
                            Spacer()
                            Text(cacheSize)
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                    NavigationLink {
                        NetworkUsageView()
                    } label: {
                        Label("Расход трафика", systemImage: "chart.bar")
                    }
                }

                Section {
                    Toggle(isOn: $autoDownloadCellular) {
                        Label("По мобильной сети", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    Toggle(isOn: $autoDownloadWifi) {
                        Label("По Wi-Fi", systemImage: "wifi")
                    }
                    Button(role: .destructive) {
                        showResetConfirm = true
                    } label: {
                        Text("Сбросить автозагрузку")
                    }
                } header: {
                    Text("Автозагрузка медиа")
                } footer: {
                    Text("Фото, видео и файлы будут загружаться автоматически при получении, в зависимости от типа сети.")
                }

                Section {
                    Toggle("Личные чаты", isOn: $autoSavePrivateChats)
                    Toggle("Группы", isOn: $autoSaveGroups)
                    Toggle("Каналы", isOn: $autoSaveChannels)
                } header: {
                    Text("Автосохранение медиа")
                } footer: {
                    Text("Полученные фото и видео будут сохраняться в галерею устройства.")
                }

                Section {
                    Toggle("Загружать в фоне", isOn: $downloadInBackground)
                } footer: {
                    Text("Продолжать загрузку файлов, когда приложение свёрнуто.")
                }

                Section {
                    Toggle("Меньше данных для звонков", isOn: $voiceUseLessData)
                } header: {
                    Text("Голосовые вызовы")
                } footer: {
                    Text("Уменьшает расход трафика во время звонков за счёт качества связи.")
                }

                Section {
                    Toggle("Сохранять отредактированные фото", isOn: $saveEditedPhotos)
                    Toggle("Останавливать музыку при записи", isOn: $pauseMusicOnRecording)
                    Toggle("Поднести к уху для прослушивания", isOn: $raiseToListen)
                } header: {
                    Text("Прочее")
                }

                Section {
                    Button(role: .destructive) {
                        showClearCacheConfirm = true
                    } label: {
                        HStack {
                            Text("Очистить кэш")
                            Spacer()
                            if isClearingCache {
                                ProgressView()
                            } else {
                                Text(cacheSize)
                                    .foregroundStyle(DesignTokens.textSecondary)
                            }
                        }
                    }
                } footer: {
                    Text("Реальный размер данных на диске (Caches + офлайн-кэш ответов сервера).")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Данные и память")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Сбросить настройки автозагрузки?", isPresented: $showResetConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) {
                autoDownloadCellular = true
                autoDownloadWifi = true
            }
        }
        .alert("Очистить кэш?", isPresented: $showClearCacheConfirm) {
            Button("Отмена", role: .cancel) {}
            Button("Очистить", role: .destructive) {
                Task { await clearCache() }
            }
        } message: {
            Text("Загруженные медиафайлы будут удалены с устройства. Сами сообщения удалены не будут.")
        }
        .task {
            await refreshCacheSize()
        }
        .onAppear {
            Task { await refreshCacheSize() }
        }
    }

    private func clearCache() async {
        isClearingCache = true
        defer { isClearingCache = false }
        await DataAndStorageCache.clear()
        await refreshCacheSize()
    }

    private func refreshCacheSize() async {
        let bytes = await DataAndStorageCache.currentSizeBytes()
        cacheSize = ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Подробный экран использования памяти — реальная детализация по типам
/// данных: сканирует Caches на диске и определяет тип каждого файла по
/// сигнатуре байт (magic bytes), а не по расширению — файлы URLCache и
/// AsyncImage хранятся без осмысленных расширений, поэтому только так
/// цифры соответствуют тому, что реально занимает место.
struct StorageUsageView: View {
    @State private var breakdown: StorageBreakdown?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            ITDOBackground()
            Form {
                Section {
                    HStack {
                        Text("Занято на устройстве")
                        Spacer()
                        if isLoading {
                            ProgressView()
                        } else {
                            Text(sizeString(breakdown?.total ?? 0))
                                .foregroundStyle(DesignTokens.textSecondary)
                        }
                    }
                }
                Section {
                    if isLoading {
                        ProgressView()
                    } else if let breakdown, breakdown.total > 0 {
                        storageRow(title: "Фото", icon: "photo", bytes: breakdown.photos, total: breakdown.total)
                        storageRow(title: "Видео", icon: "video", bytes: breakdown.videos, total: breakdown.total)
                        storageRow(title: "Голосовые и аудио", icon: "waveform", bytes: breakdown.audio, total: breakdown.total)
                        storageRow(title: "Ответы сервера (JSON)", icon: "doc.text", bytes: breakdown.documents, total: breakdown.total)
                        storageRow(title: "Прочее", icon: "questionmark.folder", bytes: breakdown.other, total: breakdown.total)
                    } else {
                        Text("Кэш пуст")
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                } header: {
                    Text("По типам")
                } footer: {
                    Text("Подсчитано по фактическому содержимому папки кэша на устройстве.")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Использование памяти")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            breakdown = await DataAndStorageCache.currentBreakdown()
            isLoading = false
        }
    }

    private func storageRow(title: String, icon: String, bytes: Int64, total: Int64) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text(sizeString(bytes))
                    .foregroundStyle(DesignTokens.textSecondary)
            }
            if total > 0 {
                ProgressView(value: Double(bytes), total: Double(total))
                    .tint(DesignTokens.accentPrimary)
            }
        }
        .padding(.vertical, 2)
    }

    private func sizeString(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Расход трафика — счётчики отправленных/полученных байт по типам сети.
/// В отличие от использования памяти, ОС не даёт приложению точных
/// счётчиков трафика по отдельным сетевым запросам без специальных
/// разрешений/энтайтлментов, поэтому здесь остаётся заглушка — в отличие
/// от вкладки "Использование памяти", это не то, что можно честно посчитать
/// сканированием диска.
struct NetworkUsageView: View {
    var body: some View {
        ZStack {
            ITDOBackground()
            Form {
                Section {
                    Text("Подробная статистика по мобильной сети и Wi-Fi недоступна без доступа к системным сетевым счётчикам.")
                        .foregroundStyle(DesignTokens.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Расход трафика")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Разбивка занятого места по реальным категориям данных.
struct StorageBreakdown {
    var photos: Int64 = 0
    var videos: Int64 = 0
    var audio: Int64 = 0
    var documents: Int64 = 0
    var other: Int64 = 0

    var total: Int64 { photos + videos + audio + documents + other }
}

/// Реальный подсчёт и очистка дискового кэша приложения: системного
/// URLCache (изображения, подгружаемые через AsyncImage/URLSession) и
/// собственного офлайн-кэша ответов сервера (APIClient.cacheDirectory,
/// "itdo-api-cache"). Заменяет отсутствующий в проекте выделенный
/// медиа-кэш-менеджер (в Telegram эту роль играет StorageUsageScreen +
/// Postbox media cache).
enum DataAndStorageCache {
    private static var cachesDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    /// Суммарный реальный размер всего, что лежит в Caches (включая
    /// системный URLCache и офлайн-кэш API), в байтах.
    static func currentSizeBytes() async -> Int64 {
        await currentBreakdown().total
    }

    /// Сканирует Caches и классифицирует каждый файл по сигнатуре байт
    /// (magic bytes), суммируя реальные размеры на диске по категориям.
    static func currentBreakdown() async -> StorageBreakdown {
        await Task.detached(priority: .utility) { () -> StorageBreakdown in
            guard let cachesDirectory else { return StorageBreakdown() }
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(
                at: cachesDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
                options: [.skipsHiddenFiles]
            ) else { return StorageBreakdown() }

            var breakdown = StorageBreakdown()
            for case let url as URL in enumerator {
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
                guard values?.isRegularFile == true else { continue }
                let size = Int64(values?.fileSize ?? 0)
                guard size > 0 else { continue }

                switch classify(url: url) {
                case .photo: breakdown.photos += size
                case .video: breakdown.videos += size
                case .audio: breakdown.audio += size
                case .document: breakdown.documents += size
                case .other: breakdown.other += size
                }
            }
            return breakdown
        }.value
    }

    static func clear() async {
        await Task.detached(priority: .utility) {
            guard let cachesDirectory else { return }
            let fileManager = FileManager.default
            if let contents = try? fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil) {
                for url in contents {
                    try? fileManager.removeItem(at: url)
                }
            }
        }.value
        URLCache.shared.removeAllCachedResponses()
    }

    private enum Kind {
        case photo, video, audio, document, other
    }

    /// Определяет тип файла по первым байтам содержимого (magic numbers),
    /// а не по расширению — файлы системного URLCache и загруженные через
    /// AsyncImage хранятся под хешированными именами без расширений.
    private static func classify(url: URL) -> Kind {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return .other }
        defer { try? handle.close() }
        guard let header = try? handle.read(upToCount: 32), !header.isEmpty else { return .other }
        let bytes = [UInt8](header)

        func matches(_ signature: [UInt8], at offset: Int = 0) -> Bool {
            guard bytes.count >= offset + signature.count else { return false }
            return Array(bytes[offset..<offset + signature.count]) == signature
        }

        // Изображения
        if matches([0xFF, 0xD8, 0xFF]) { return .photo }                       // JPEG
        if matches([0x89, 0x50, 0x4E, 0x47]) { return .photo }                 // PNG
        if matches([0x47, 0x49, 0x46, 0x38]) { return .photo }                 // GIF
        if matches([0x52, 0x49, 0x46, 0x46], at: 0), matches([0x57, 0x45, 0x42, 0x50], at: 8) { return .photo } // WEBP
        if bytes.count >= 12, matches([0x66, 0x74, 0x79, 0x70], at: 4) {
            // ISO base media container ("ftyp") — различаем по бренду
            let brand = String(decoding: bytes[8..<min(12, bytes.count)], as: UTF8.self)
            if ["heic", "heix", "heif", "mif1", "msf1", "avif"].contains(brand) { return .photo }
            if ["mp41", "mp42", "isom", "M4V ", "qt  "].contains(brand) { return .video }
            if ["M4A ", "M4B "].contains(brand) { return .audio }
        }

        // Видео
        if matches([0x00, 0x00, 0x00, 0x18]) || matches([0x00, 0x00, 0x00, 0x1C]) { return .video } // частые размеры box у mp4/mov
        if matches([0x1A, 0x45, 0xDF, 0xA3]) { return .video }                 // WebM/Matroska

        // Аудио
        if matches([0x49, 0x44, 0x33]) { return .audio }                       // MP3 (ID3)
        if bytes.count >= 2, bytes[0] == 0xFF, (bytes[1] & 0xE0) == 0xE0 { return .audio } // MPEG audio frame
        if matches([0x52, 0x49, 0x46, 0x46], at: 0), matches([0x57, 0x41, 0x56, 0x45], at: 8) { return .audio } // WAV
        if matches([0x63, 0x61, 0x66, 0x66]) { return .audio }                 // CAF (голосовые заметки)

        // JSON-ответы API (наш собственный офлайн-кэш и системный URLCache для JSON)
        if let first = bytes.first, first == UInt8(ascii: "{") || first == UInt8(ascii: "[") { return .document }

        return .other
    }
}

#Preview {
    CompatNavigationStack {
        DataAndStorageSettingsView()
    }
}
