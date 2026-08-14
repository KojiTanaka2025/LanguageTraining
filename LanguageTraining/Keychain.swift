import Foundation
import Security

enum Keychain {
    static func readString(service: String, account: String) throws -> String? {
        for accessGroup in accessGroupsToSearch {
            if let synced = try readString(service: service, account: account, synchronizable: true, accessGroup: accessGroup) {
                return synced
            }
            if let local = try readString(service: service, account: account, synchronizable: false, accessGroup: accessGroup) {
                return local
            }
        }
        return nil
    }

    static func upsertString(_ value: String, service: String, account: String) throws {
        try upsertString(value, service: service, account: account, synchronizable: true, accessGroup: preferredAccessGroup)
    }

    static func delete(service: String, account: String) throws {
        for accessGroup in accessGroupsToSearch {
            try delete(service: service, account: account, synchronizable: true, accessGroup: accessGroup)
            try delete(service: service, account: account, synchronizable: false, accessGroup: accessGroup)
        }
    }

    private static func readString(service: String, account: String, synchronizable: Bool, accessGroup: String?) throws -> String? {
        var query = baseQuery(service: service, account: account, synchronizable: synchronizable, accessGroup: accessGroup)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound || status == errSecMissingEntitlement { return nil }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
        guard let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func upsertString(_ value: String, service: String, account: String, synchronizable: Bool, accessGroup: String?) throws {
        let data = Data(value.utf8)
        let query = baseQuery(service: service, account: account, synchronizable: synchronizable, accessGroup: accessGroup)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(add as CFDictionary, nil)
            if addStatus == errSecMissingEntitlement, synchronizable {
                try upsertString(value, service: service, account: account, synchronizable: false, accessGroup: accessGroup)
                return
            }
            if addStatus == errSecMissingEntitlement, accessGroup != nil {
                try upsertString(value, service: service, account: account, synchronizable: synchronizable, accessGroup: nil)
                return
            }
            guard addStatus == errSecSuccess else { throw KeychainError(status: addStatus) }
            return
        }

        if status == errSecMissingEntitlement, synchronizable {
            try upsertString(value, service: service, account: account, synchronizable: false, accessGroup: accessGroup)
            return
        }
        if status == errSecMissingEntitlement, accessGroup != nil {
            try upsertString(value, service: service, account: account, synchronizable: synchronizable, accessGroup: nil)
            return
        }

        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private static func delete(service: String, account: String, synchronizable: Bool, accessGroup: String?) throws {
        let query = baseQuery(service: service, account: account, synchronizable: synchronizable, accessGroup: accessGroup)
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound || status == errSecMissingEntitlement { return }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    private static func baseQuery(service: String, account: String, synchronizable: Bool, accessGroup: String?) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: synchronizable ? kCFBooleanTrue as Any : kCFBooleanFalse as Any
        ]
        if let accessGroup {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private static var preferredAccessGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "LanguageTrainingKeychainAccessGroup") as? String
    }

    private static var accessGroupsToSearch: [String?] {
        if let preferredAccessGroup {
            return [preferredAccessGroup, nil]
        }
        return [nil]
    }
}

struct KeychainError: Error, LocalizedError {
    let status: OSStatus
    var errorDescription: String? {
        if let message = SecCopyErrorMessageString(status, nil) as String? {
            return "Keychain error: \(message) (\(status))"
        }
        return "Keychain error (\(status))"
    }
}
