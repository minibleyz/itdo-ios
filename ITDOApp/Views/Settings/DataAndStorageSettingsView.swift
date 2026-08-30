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
                        StorageUsageView(cacheSize: $cacheSize)
                    } label: {
                        Label("Использование памяти", systemImage: "internaldrive")
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
            cacheSize = await currentCacheSizeDescription()
        }
    }

    private func clearCache() async {
        isClearingCache = true
        defer { isClearingCache = false }
        DataAndStorageCache.clear()
        cacheSize = await currentCacheSizeDescription()
    }

    private func currentCacheSizeDescription() async -> String {
        let bytes = DataAndStorageCache.currentSizeBytes()
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

/// Подробный экран использования памяти — детализация по типам данных.
struct StorageUsageView: View {
    @Binding var cacheSize: String

    var body: some View {
        ZStack {
            ITDOBackground()
            Form {
                Section {
                    HStack {
                        Text("Занято на устройстве")
                        Spacer()
                        Text(cacheSize)
                            .foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                Section("По типам") {
                    storageRow(title: "Фото", icon: "photo")
                    storageRow(title: "Видео", icon: "video")
                    storageRow(title: "Файлы", icon: "doc")
                    storageRow(title: "Голосовые сообщения", icon: "waveform")
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Использование памяти")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func storageRow(title: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text("—")
                .foregroundStyle(DesignTokens.textSecondary)
        }
    }
}

/// Расход трафика — счётчики отправленных/полученных байт по типам сети.
struct NetworkUsageView: View {
    var body: some View {
        ZStack {
            ITDOBackground()
            Form {
                Section("Мобильная сеть") {
                    HStack {
                        Text("Отправлено")
                        Spacer()
                        Text("—").foregroundStyle(DesignTokens.textSecondary)
                    }
                    HStack {
                        Text("Получено")
                        Spacer()
                        Text("—").foregroundStyle(DesignTokens.textSecondary)
                    }
                }
                Section("Wi-Fi") {
                    HStack {
                        Text("Отправлено")
                        Spacer()
                        Text("—").foregroundStyle(DesignTokens.textSecondary)
                    }
                    HStack {
                        Text("Получено")
                        Spacer()
                        Text("—").foregroundStyle(DesignTokens.textSecondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Расход трафика")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Простой подсчёт/очистка размера папки Caches — заменяет отсутствующий в
/// проекте выделенный медиа-кэш-менеджер (в Telegram эту роль играет
/// StorageUsageScreen + Postbox media cache).
enum DataAndStorageCache {
    private static var cachesDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    }

    static func currentSizeBytes() -> Int64 {
        guard let cachesDirectory else { return 0 }
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: cachesDirectory,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey])
            total += Int64(values?.fileSize ?? 0)
        }
        return total
    }

    static func clear() {
        guard let cachesDirectory else { return }
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(at: cachesDirectory, includingPropertiesForKeys: nil) else { return }
        for url in contents {
            try? fileManager.removeItem(at: url)
        }
        URLCache.shared.removeAllCachedResponses()
    }
}

#Preview {
    CompatNavigationStack {
        DataAndStorageSettingsView()
    }
}
