//
//  AuthAPI.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated protocol AuthAPIProtocol: Sendable {
    func login(username: String, password: String) async throws -> UserProfile
    func logout() async
    func restoreSession() async -> Bool
}

nonisolated final class AuthAPI: AuthAPIProtocol {
    private let client: APIClientProtocol
    private let tokenStore: TokenStore

    init(client: APIClientProtocol, tokenStore: TokenStore) {
        self.client = client
        self.tokenStore = tokenStore
    }

    func login(username: String, password: String) async throws -> UserProfile {
        let response = try await client.send(
            .login(LoginRequest(username: username, password: password)),
            as: LoginResponse.self
        )
        await tokenStore.set(
            AuthTokens(
                accessToken: response.accessToken,
                refreshToken: response.refreshToken,
                tokenType: response.tokenType,
                expiresIn: response.expiresIn
            )
        )
        return response.user
    }

    func logout() async {
        await tokenStore.set(nil)
    }

    func restoreSession() async -> Bool {
        guard await tokenStore.tokens != nil else { return false }
        do {
            try await client.refreshSession()
            return true
        } catch {
            return false
        }
    }
}
