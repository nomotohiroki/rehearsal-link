import Foundation
import Security

/// Keychainへのアクセスを抽象化するヘルパークラス
final class KeychainHelper: @unchecked Sendable {
    static let shared = KeychainHelper()
    private init() {}

    /// データをKeychainに保存します
    func save(_ data: Data, service: String, account: String) {
        let query = [
            kSecValueData: data,
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ] as CFDictionary

        let status = SecItemAdd(query, nil)

        if status == errSecDuplicateItem {
            let query = [
                kSecAttrService: service,
                kSecAttrAccount: account,
                kSecClass: kSecClassGenericPassword
            ] as CFDictionary

            let attributesToUpdate = [kSecValueData: data] as CFDictionary

            SecItemUpdate(query, attributesToUpdate)
        }
    }

    /// Keychainからデータを読み取ります
    func readData(service: String, account: String) -> Data? {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword,
            kSecReturnData: true
        ] as CFDictionary

        var result: AnyObject?
        SecItemCopyMatching(query, &result)

        return result as? Data
    }

    /// Keychainからデータを削除します
    func delete(service: String, account: String) {
        let query = [
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecClass: kSecClassGenericPassword
        ] as CFDictionary

        SecItemDelete(query)
    }
}

extension KeychainHelper {
    /// 文字列をKeychainに保存します
    func save(_ string: String, service: String, account: String) {
        guard let data = string.data(using: .utf8) else { return }
        save(data, service: service, account: account)
    }

    /// Keychainから文字列を読み取ります
    func readString(service: String, account: String) -> String? {
        guard let data = readData(service: service, account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
