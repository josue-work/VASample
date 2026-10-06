//
//  APIClientTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@Suite(.serialized)
struct APIClientTests {
    private let profileJSON = """
    {"id":"user_001","firstName":"Avid","lastName":"Runner","email":"avid.runner@virginactive.mock",
     "membershipTier":"premium","homeClub":{"id":"club_sea_point","name":"Virgin Active Sea Point"}}
    """
    private let tokensJSON = #"{"accessToken":"new-access","refreshToken":"new-refresh","tokenType":"Bearer","expiresIn":300}"#
    private let chaosJSON = #"{"error":"ChaosFailure","message":"The service is temporarily unavailable.","requestId":"r1"}"#

    private func makeClient(tokens: AuthTokens? = AuthTokens(accessToken: "access", refreshToken: "refresh", tokenType: "Bearer", expiresIn: 300)) -> APIClient {
        APIClient(
            baseURL: URL(string: "http://localhost:8080")!,
            session: StubURLProtocol.makeSession(),
            tokenStore: TokenStore(tokens: tokens)
        )
    }

    @Test func attachesBearerTokenAndDecodes() async throws {
        StubURLProtocol.reset([.init(status: 200, body: profileJSON)])
        let profile = try await makeClient().send(.me, as: UserProfile.self)

        #expect(profile.homeClub.id == "club_sea_point")
        #expect(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer access")
        #expect(StubURLProtocol.requests.first?.url?.path == "/me")
    }

    @Test func refusesAuthenticatedCallsWithoutATokenBeforeHittingTheNetwork() async {
        StubURLProtocol.reset([])
        await #expect(throws: APIError.self) {
            try await makeClient(tokens: nil).send(.me, as: UserProfile.self)
        }
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test func retriesIdempotentRequestsOnChaosFailures() async throws {
        StubURLProtocol.reset([
            .init(status: 500, body: chaosJSON),
            .init(status: 500, body: chaosJSON),
            .init(status: 200, body: profileJSON)
        ])
        _ = try await makeClient().send(.me, as: UserProfile.self)
        #expect(StubURLProtocol.requests.count == 3)
    }

    @Test func givesUpAfterMaxRetriesAndSurfacesTheServerError() async {
        StubURLProtocol.reset(Array(repeating: .init(status: 500, body: chaosJSON), count: 3))
        do {
            _ = try await makeClient().send(.me, as: UserProfile.self)
            Issue.record("Expected failure")
        } catch let error as APIError {
            #expect(error.hasServerCode("ChaosFailure"))
            #expect(StubURLProtocol.requests.count == 3)
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func neverRetriesBookingPosts() async {
        StubURLProtocol.reset([.init(status: 500, body: chaosJSON), .init(status: 201, body: "{}")])
        await #expect(throws: APIError.self) {
            try await makeClient().send(.book(clubId: "club_sea_point", classId: "sp-power-spin::2026-10-07"))
        }
        #expect(StubURLProtocol.requests.count == 1)
        #expect(StubURLProtocol.requests.first?.httpMethod == "POST")
        #expect(StubURLProtocol.requests.first?.url?.path == "/clubs/club_sea_point/classes/sp-power-spin::2026-10-07/bookings")
    }

    @Test func refreshesOnceOn401AndReplaysWithTheNewToken() async throws {
        StubURLProtocol.reset([
            .init(status: 401, body: #"{"error":"Unauthorized","message":"","requestId":"r"}"#),
            .init(status: 200, body: tokensJSON),
            .init(status: 200, body: profileJSON)
        ])
        let client = makeClient()
        _ = try await client.send(.me, as: UserProfile.self)

        let requests = StubURLProtocol.requests
        #expect(requests.map(\.url?.path) == ["/me", "/auth/refresh", "/me"])
        #expect(StubURLProtocol.body(of: requests[1])?["refreshToken"] as? String == "refresh")
        #expect(requests[2].value(forHTTPHeaderField: "Authorization") == "Bearer new-access")
        #expect(await client.tokenStore.tokens?.refreshToken == "new-refresh")
    }

    @Test func rejectedRefreshExpiresTheSession() async {
        StubURLProtocol.reset([
            .init(status: 401, body: "{}"),
            .init(status: 401, body: #"{"error":"InvalidRefreshToken","message":"rotated","requestId":"r"}"#)
        ])
        let client = makeClient()
        var expirations = client.tokenStore.sessionExpirations.makeAsyncIterator()

        await #expect(throws: APIError.self) {
            try await client.send(.me, as: UserProfile.self)
        }
        #expect(await client.tokenStore.tokens == nil)
        #expect(await expirations.next() != nil)
    }

    @Test func refreshSurvivesAChaosFailure() async throws {
        StubURLProtocol.reset([
            .init(status: 401, body: "{}"),
            .init(status: 500, body: chaosJSON),
            .init(status: 200, body: tokensJSON),
            .init(status: 200, body: profileJSON)
        ])
        let client = makeClient()
        _ = try await client.send(.me, as: UserProfile.self)
        #expect(await client.tokenStore.accessToken == "new-access")
    }

    @Test func decodesTheServerErrorBody() async {
        StubURLProtocol.reset([.init(status: 409, body: #"{"error":"AlreadyBooked","message":"You are already booked for this class.","requestId":"r"}"#)])
        do {
            try await makeClient().send(.book(clubId: "c", classId: "x::2026-10-07"))
            Issue.record("Expected failure")
        } catch let error as APIError {
            #expect(error.serverError?.message == "You are already booked for this class.")
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func surfacesDecodingErrors() async {
        StubURLProtocol.reset([.init(status: 200, body: #"{"unexpected":true}"#)])
        do {
            _ = try await makeClient().send(.me, as: UserProfile.self)
            Issue.record("Expected failure")
        } catch APIError.decoding {
        } catch {
            Issue.record("Unexpected error \(error)")
        }
    }

    @Test func restoresASavedSessionByRefreshing() async {
        StubURLProtocol.reset([.init(status: 200, body: tokensJSON)])
        let storage = InMemoryTokenStorage(tokens: AuthTokens(accessToken: "expired", refreshToken: "refresh", tokenType: "Bearer", expiresIn: 300))
        let tokenStore = TokenStore(storage: storage)
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, session: StubURLProtocol.makeSession(), tokenStore: tokenStore)

        let restored = await AuthAPI(client: client, tokenStore: tokenStore).restoreSession()

        #expect(restored)
        #expect(StubURLProtocol.requests.map(\.url?.path) == ["/auth/refresh"])
        #expect(storage.read()?.accessToken == "new-access")
    }

    @Test func failedRestoreFallsBackToSignIn() async {
        StubURLProtocol.reset([.init(status: 401, body: #"{"error":"InvalidRefreshToken","message":"rotated","requestId":"r"}"#)])
        let storage = InMemoryTokenStorage(tokens: AuthTokens(accessToken: "expired", refreshToken: "old", tokenType: "Bearer", expiresIn: 300))
        let tokenStore = TokenStore(storage: storage)
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, session: StubURLProtocol.makeSession(), tokenStore: tokenStore)

        let restored = await AuthAPI(client: client, tokenStore: tokenStore).restoreSession()

        #expect(!restored)
        #expect(storage.read() == nil)
    }

    @Test func nothingSavedMeansNoRestoreAndNoRequest() async {
        StubURLProtocol.reset([])
        let tokenStore = TokenStore()
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, session: StubURLProtocol.makeSession(), tokenStore: tokenStore)

        #expect(await AuthAPI(client: client, tokenStore: tokenStore).restoreSession() == false)
        #expect(StubURLProtocol.requests.isEmpty)
    }

    @Test func loginStoresTokensAndSendsCredentials() async throws {
        StubURLProtocol.reset([.init(status: 200, body: """
        {"accessToken":"a1","refreshToken":"r1","tokenType":"Bearer","expiresIn":300,"user":\(profileJSON)}
        """)])
        let tokenStore = TokenStore()
        let client = APIClient(baseURL: URL(string: "http://localhost:8080")!, session: StubURLProtocol.makeSession(), tokenStore: tokenStore)
        let auth = AuthAPI(client: client, tokenStore: tokenStore)

        let user = try await auth.login(username: "avid.runner@virginactive.mock", password: "password123")

        #expect(user.firstName == "Avid")
        #expect(await tokenStore.accessToken == "a1")
        #expect(StubURLProtocol.requests.first?.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(StubURLProtocol.body(of: StubURLProtocol.requests[0])?["username"] as? String == "avid.runner@virginactive.mock")

        await auth.logout()
        #expect(await tokenStore.accessToken == nil)
    }
}
