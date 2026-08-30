import Foundation
import Security

/// Простая обёртка над Keychain для хранения access-токена.
enum KeychainStore {
    static func set(_ value: String, forKey key: String, deviceOnly: Bool = false) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        if deviceOnly {
            // Используется для хэша код-пароля (см. PasscodeLock) — без этого
            // флага значение попадает в зашифрованный бэкап устройства и может
            // быть восстановлено на другом iPhone вместе с самим приложением,
            // что позволило бы подбирать код-пароль офлайн на чужом устройстве.
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// Существует ли элемент — без чтения самих данных. Проверка присутствия
    /// не требует расшифровки защищённого блоба, поэтому НЕ запрашивает
    /// Face ID/Touch ID/пароль, даже если элемент был сохранён через
    /// `setProtected`. Используйте это вместо `get`/`getProtected`, когда
    /// нужен только факт "код-пароль установлен", а не сам хэш.
    static func exists(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Сохраняет значение, привязанное к текущей биометрии устройства или
    /// его паролю блокировки экрана (`kSecAttrAccessControl`), а не просто
    /// к устройству в целом. Это сильнее, чем `set(..., deviceOnly: true)`:
    /// даже если сам Keychain-контейнер физически извлечь с устройства
    /// (в обход обычного iCloud/iTunes-бэкапа, из которого deviceOnly уже
    /// исключает элемент), значение всё равно нельзя расшифровать без
    /// Face ID/Touch ID/пароля владельца экрана блокировки. Если владелец
    /// удалит все отпечатки/лица и настроит новые, старая запись
    /// становится недоступной автоматически (.biometryCurrentSet).
    ///
    /// На устройстве без Face ID/Touch ID и без пароля блокировки экрана
    /// `SecAccessControlCreateWithFlags` вернёт nil — тогда откатываемся
    /// на обычное deviceOnly-хранение, чтобы не потерять код-пароль.
    ///
    /// Внимание: чтение через `getProtected` может показать системный
    /// промпт Face ID/Touch ID/пароля — вызывающий код должен быть готов
    /// к этой задержке и к возможному отказу пользователя.
    @discardableResult
    static func setProtected(_ value: String, forKey key: String) -> Bool {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data

        if let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            [.biometryCurrentSet, .or, .devicePasscode],
            nil
        ) {
            attributes[kSecAttrAccessControl as String] = access
        } else {
            attributes[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        }
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    /// Читает значение, сохранённое через `set` или `setProtected` — если
    /// элемент был защищён `kSecAttrAccessControl`, система сама покажет
    /// промпт Face ID/Touch ID/пароля перед тем, как вернуть данные.
    static func getProtected(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseOperationPrompt as String: "Подтвердите личность, чтобы разблокировать ITDO"
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
