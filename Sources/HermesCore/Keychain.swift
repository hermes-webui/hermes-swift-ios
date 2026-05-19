import Foundation
import Security

/// Thin Keychain wrapper for storing pairing tokens and other secrets.
/// All values are stored as kSecClassGenericPassword scoped to the app's keychain access group.
public enum Keychain {

    public enum Error: Swift.Error {
        case unexpectedStatus(OSStatus)
        case itemNotFound
        case dataCorrupted
    }

    public static func set(_ data: Data, for key: String, accessible: CFString = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var add = query
            add.merge(attributes) { _, new in new }
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw Error.unexpectedStatus(addStatus) }
        default:
            throw Error.unexpectedStatus(updateStatus)
        }
    }

    public static func setString(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else { throw Error.dataCorrupted }
        try set(data, for: key)
    }

    public static func data(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw Error.dataCorrupted }
            return data
        case errSecItemNotFound:
            throw Error.itemNotFound
        default:
            throw Error.unexpectedStatus(status)
        }
    }

    public static func string(for key: String) throws -> String {
        let data = try data(for: key)
        guard let s = String(data: data, encoding: .utf8) else { throw Error.dataCorrupted }
        return s
    }

    public static func delete(_ key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw Error.unexpectedStatus(status)
        }
    }
}
