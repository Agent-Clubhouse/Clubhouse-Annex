import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.Agent-Clubhouse.Annex"
    private static let tokenAccount = "session-token"
    private static let hostAccount = "server-host"
    private static let portAccount = "server-port"

    // MARK: - Token

    static func saveToken(_ token: String) {
        save(account: tokenAccount, data: Data(token.utf8))
    }

    static func loadToken() -> String? {
        guard let data = load(account: tokenAccount) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func deleteToken() {
        delete(account: tokenAccount)
    }

    // MARK: - Server Connection Info

    static func saveServer(host: String, port: UInt16) {
        save(account: hostAccount, data: Data(host.utf8))
        save(account: portAccount, data: Data(String(port).utf8))
    }

    static func loadServer() -> (host: String, port: UInt16)? {
        guard let hostData = load(account: hostAccount),
              let host = String(data: hostData, encoding: .utf8),
              let portData = load(account: portAccount),
              let portStr = String(data: portData, encoding: .utf8),
              let port = UInt16(portStr) else { return nil }
        return (host, port)
    }

    static func deleteServer() {
        delete(account: hostAccount)
        delete(account: portAccount)
    }

    static func clearAll() {
        deleteToken()
        deleteServer()
    }

    // MARK: - Generic Keychain Operations

    private static func save(account: String, data: Data) {
        delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
