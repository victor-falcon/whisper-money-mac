import Foundation
import Security

public struct Credentials: Codable, Sendable, Equatable {
    public let endpoint: URL
    public let token: String

    public init(endpoint: URL, token: String) {
        self.endpoint = endpoint
        self.token = token
    }
}

/// URL del endpoint MCP y token en el Llavero de macOS. Es lo único que se persiste: credenciales,
/// nunca datos financieros. Con `accessGroup`, la app y el widget comparten el mismo elemento.
public struct CredentialStore: Sendable {
    public static let service = "mx.diego.whispermac"
    private static let account = "whisper-money-mcp"

    private let accessGroup: String?

    public init(accessGroup: String?) {
        self.accessGroup = accessGroup
    }

    /// Grupo de llavero declarado en el Info.plist (`KeychainAccessGroup`, expandido por Xcode).
    public static func fromBundle(_ bundle: Bundle = .main) -> CredentialStore {
        CredentialStore(accessGroup: bundle.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String)
    }

    private var baseQuery: [String: Any] {
        var q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.service,
            kSecAttrAccount as String: Self.account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup { q[kSecAttrAccessGroup as String] = accessGroup }
        return q
    }

    public func load() throws -> Credentials? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else { throw KeychainError(status: status) }
        return try JSONDecoder().decode(Credentials.self, from: data)
    }

    public func save(_ credentials: Credentials) throws {
        let data = try JSONEncoder().encode(credentials)
        let update = [kSecValueData as String: data]
        var status = SecItemUpdate(baseQuery as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = baseQuery
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            status = SecItemAdd(add as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw KeychainError(status: status) }
    }

    public func delete() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError(status: status) }
    }
}

public struct KeychainError: Error, LocalizedError {
    public let status: OSStatus
    public var errorDescription: String? {
        let message = SecCopyErrorMessageString(status, nil) as String? ?? "código \(status)"
        return "Llavero: \(message)"
    }
}
