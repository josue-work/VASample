//
//  TokenStore.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

actor TokenStore {
    
    private(set) var tokens: AuthTokens?
    private var refreshTask: Task<AuthTokens, Error>?
    private let storage: TokenStorageProtocol
    nonisolated let sessionExpirations: AsyncStream<Void>
    private let sessionExpirationContinuation: AsyncStream<Void>.Continuation

    init(storage: TokenStorageProtocol = InMemoryTokenStorage()) {
        self.storage = storage
        self.tokens = storage.read()
        (sessionExpirations, sessionExpirationContinuation) = AsyncStream.makeStream(of: Void.self)
    }

    init(tokens: AuthTokens?) {
        self.init(storage: InMemoryTokenStorage(tokens: tokens))
    }

    var accessToken: String? { tokens?.accessToken }

    func set(_ tokens: AuthTokens?) {
        self.tokens = tokens
        if let tokens {
            storage.save(tokens)
        } else {
            storage.clear()
        }
    }

    func expireSession() {
        guard tokens != nil else { return }
        set(nil)
        sessionExpirationContinuation.yield()
    }

    func refreshedTokens(
        replacing staleAccessToken: String?,
        using refresh: @escaping @Sendable (String) async throws -> AuthTokens
    ) async throws -> AuthTokens {
        if let refreshTask {
            return try await refreshTask.value
        }
        guard let tokens else { throw APIError.unauthorized }
        if tokens.accessToken != staleAccessToken {
            return tokens
        }

        let task = Task { try await refresh(tokens.refreshToken) }
        refreshTask = task
        defer { refreshTask = nil }

        do {
            let refreshed = try await task.value
            set(refreshed)
            return refreshed
        } catch let error as APIError where !error.isTransient {
            expireSession()
            throw APIError.unauthorized
        }
    }
}
