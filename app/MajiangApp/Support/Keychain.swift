import Foundation
import Security
import MajiangKit

/// Gemini API Key 存在钥匙串里。只在开发阶段用；上架后走后端代理，App 里不放 Key。
struct GeminiKeychain: APIKeyProvider {
    private static let service = "majiang-ppc.gemini"
    private static let account = "api-key"

    func apiKey() throws -> String {
        guard let key = Self.read(), !key.isEmpty else { throw RecognitionError.notConfigured }
        return key
    }

    static var hasKey: Bool { !(read() ?? "").isEmpty }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func save(_ key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var add = base
        add[kSecValueData as String] = Data(trimmed.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
    }
}
