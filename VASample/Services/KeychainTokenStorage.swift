//
//  KeychainTokenStorage.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Security
import Synchronization

nonisolated protocol TokenStorageProtocol: Sendable {
    func save(_ tokens: AuthTokens)
    func read() -> AuthTokens?
    func clear()
}

nonisolated struct KeychainTokenStorage: TokenStorageProtocol {
    private let service: String
    private let account: String

    init(service: String = Bundle.main.bundleIdentifier ?? "VASample", account: String = "auth_tokens") {
        self.service = service
        self.account = account
    }

    func save(_ tokens: AuthTokens) {
        guard let encoded = try? JSONEncoder().encode(tokens),
              let json = String(data: encoded, encoding: .utf8) else {
            return
        }
        clear()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(json.utf8)
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    func read() -> AuthTokens? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(AuthTokens.self, from: Data(json.utf8))
    }

    func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

nonisolated final class InMemoryTokenStorage: TokenStorageProtocol {
    private let tokens: Mutex<AuthTokens?>

    init(tokens: AuthTokens? = nil) {
        self.tokens = Mutex(tokens)
    }

    func save(_ tokens: AuthTokens) {
        self.tokens.withLock { $0 = tokens }
    }

    func read() -> AuthTokens? {
        tokens.withLock { $0 }
    }

    func clear() {
        tokens.withLock { $0 = nil }
    }
}
