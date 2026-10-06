//
//  TokenStoreTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}

struct TokenStoreTests {
    private let initial = AuthTokens(accessToken: "a0", refreshToken: "r0", tokenType: "Bearer", expiresIn: 300)
    private let refreshed = AuthTokens(accessToken: "a1", refreshToken: "r1", tokenType: "Bearer", expiresIn: 300)

    @Test func concurrentRefreshesShareOneRequest() async throws {
        let store = TokenStore(tokens: initial)
        let counter = CallCounter()
        let refreshed = refreshed
        let refresh: @Sendable (String) async throws -> AuthTokens = { _ in
            await counter.increment()
            try await Task.sleep(for: .milliseconds(100))
            return refreshed
        }

        async let first = store.refreshedTokens(replacing: "a0", using: refresh)
        async let second = store.refreshedTokens(replacing: "a0", using: refresh)
        let results = try await [first, second]

        #expect(results.map(\.accessToken) == ["a1", "a1"])
        #expect(await counter.count == 1)
    }

    @Test func skipsRefreshWhenAnotherRequestAlreadyRotatedTheToken() async throws {
        let store = TokenStore(tokens: refreshed)
        let counter = CallCounter()
        let result = try await store.refreshedTokens(replacing: "a0") { _ in
            await counter.increment()
            return AuthTokens(accessToken: "never", refreshToken: "never", tokenType: "Bearer", expiresIn: 300)
        }
        #expect(result.accessToken == "a1")
        #expect(await counter.count == 0)
    }

    @Test func transientRefreshFailureKeepsTheUserSignedIn() async {
        let store = TokenStore(tokens: initial)
        await #expect(throws: APIError.self) {
            try await store.refreshedTokens(replacing: "a0") { _ in throw Fixtures.serverError(500, "ChaosFailure") }
        }
        #expect(await store.accessToken == "a0")
    }

    @Test func rejectedRefreshSignsOutAndEmitsExpiry() async {
        let store = TokenStore(tokens: initial)
        var expirations = store.sessionExpirations.makeAsyncIterator()

        await #expect(throws: APIError.self) {
            try await store.refreshedTokens(replacing: "a0") { _ in throw Fixtures.serverError(401, "InvalidRefreshToken") }
        }
        #expect(await store.accessToken == nil)
        #expect(await expirations.next() != nil)
    }

    @Test func refreshWithoutTokensIsUnauthorized() async {
        let store = TokenStore()
        await #expect(throws: APIError.self) {
            try await store.refreshedTokens(replacing: nil) { _ in Issue.record("Should not refresh"); throw APIError.unauthorized }
        }
    }

    // MARK: - Persistence

    @Test func loadsSavedTokensWhenCreated() async {
        let store = TokenStore(storage: InMemoryTokenStorage(tokens: initial))
        #expect(await store.tokens == initial)
    }

    @Test func persistsSignInAndSignOut() async {
        let storage = InMemoryTokenStorage()
        let store = TokenStore(storage: storage)

        await store.set(initial)
        #expect(storage.read() == initial)

        await store.set(nil)
        #expect(storage.read() == nil)
    }

    @Test func persistsRotatedTokens() async throws {
        let storage = InMemoryTokenStorage(tokens: initial)
        let store = TokenStore(storage: storage)
        let refreshed = refreshed

        _ = try await store.refreshedTokens(replacing: "a0") { _ in refreshed }

        #expect(storage.read() == refreshed)
    }

    @Test func rejectedRefreshWipesSavedTokens() async {
        let storage = InMemoryTokenStorage(tokens: initial)
        let store = TokenStore(storage: storage)

        _ = try? await store.refreshedTokens(replacing: "a0") { _ in throw Fixtures.serverError(401, "InvalidRefreshToken") }

        #expect(storage.read() == nil)
    }

    @Test func transientRefreshFailureKeepsSavedTokens() async {
        let storage = InMemoryTokenStorage(tokens: initial)
        let store = TokenStore(storage: storage)

        _ = try? await store.refreshedTokens(replacing: "a0") { _ in throw Fixtures.serverError(500, "ChaosFailure") }

        #expect(storage.read() == initial)
    }
}

@Suite(.serialized)
struct KeychainTokenStorageTests {
    private let storage = KeychainTokenStorage(service: "VASampleTests", account: "auth_tokens_test")
    private let tokens = AuthTokens(accessToken: "a0", refreshToken: "r0", tokenType: "Bearer", expiresIn: 300)

    @Test func roundTripsTokensThroughTheKeychain() {
        storage.clear()
        #expect(storage.read() == nil)

        storage.save(tokens)
        #expect(storage.read() == tokens)

        let rotated = AuthTokens(accessToken: "a1", refreshToken: "r1", tokenType: "Bearer", expiresIn: 300)
        storage.save(rotated)
        #expect(storage.read() == rotated)

        storage.clear()
        #expect(storage.read() == nil)
    }
}
