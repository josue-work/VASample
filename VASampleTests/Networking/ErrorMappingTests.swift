//
//  ErrorMappingTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

struct APIErrorTests {
    @Test(arguments: [
        (APIError.transport(URLError(.timedOut)), true),
        (APIError.transport(URLError(.notConnectedToInternet)), true),
        (APIError.transport(URLError(.cancelled)), false),
        (Fixtures.serverError(500, "ChaosFailure"), true),
        (Fixtures.serverError(503, "Unavailable"), true),
        (Fixtures.serverError(429, "RateLimited"), true),
        (Fixtures.serverError(404, "ClassNotFound"), false),
        (Fixtures.serverError(409, "AlreadyBooked"), false),
        (APIError.unauthorized, false),
        (APIError.invalidResponse, false)
    ])
    func classifiesTransientFailures(error: APIError, isTransient: Bool) {
        #expect(error.isTransient == isTransient)
    }

    @Test func readsServerErrorCode() {
        let error = Fixtures.serverError(409, "AlreadyBooked")
        #expect(error.hasServerCode("AlreadyBooked"))
        #expect(!error.hasServerCode("AlreadyWaitlisted"))
        #expect(!APIError.unauthorized.hasServerCode("AlreadyBooked"))
    }
}

struct UIErrorMappingTests {
    @Test func cancellationIsSilent() {
        #expect(UIError(CancellationError()) == nil)
        #expect(UIError(APIError.transport(URLError(.cancelled))) == nil)
    }

    @Test func clientErrorsShowTheServerMessageWithoutRetry() {
        let error = UIError(Fixtures.serverError(401, "InvalidCredentials", message: "The username or password is incorrect.")) { }
        guard case .userInput(let message) = error else {
            Issue.record("Expected userInput, got \(String(describing: error))")
            return
        }
        #expect(message == "The username or password is incorrect.")
    }

    @Test func serverFailuresOfferRetry() {
        var retried = false
        let error = UIError(Fixtures.serverError(500, "ChaosFailure", message: "Try again.")) { retried = true }
        guard case .server(let message, let retry?) = error else {
            Issue.record("Expected retryable server error")
            return
        }
        #expect(message == "Try again.")
        retry()
        #expect(retried)
    }

    @Test func rateLimitIsRetryable() {
        let error = UIError(Fixtures.serverError(429, "RateLimited"), retry: {})
        guard case .server(_, .some) = error else {
            Issue.record("429 should be retryable")
            return
        }
    }

    @Test func connectivityProblemsOfferRetry() {
        let error = UIError(APIError.transport(URLError(.notConnectedToInternet)), retry: {})
        guard case .server(_, .some) = error else {
            Issue.record("Transport errors should be retryable")
            return
        }
    }

    @Test func expiredSessionMapsToUnauthorized() {
        guard case .unauthorized = UIError(APIError.unauthorized) else {
            Issue.record("Expected unauthorized")
            return
        }
    }

    @Test func decodingProblemsAreNotRetryable() {
        let decodingError = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "bad"))
        let error = UIError(APIError.decoding(decodingError), retry: {})
        guard case .server(nil, nil) = error else {
            Issue.record("Decoding errors should not be retryable")
            return
        }
    }

    @Test func unknownErrorsAreClientErrors() {
        struct Boom: Error {}
        guard case .client = UIError(Boom()) else {
            Issue.record("Expected client error")
            return
        }
    }

    @Test func clientTitleAndMessageAreSeparate() {
        let error = UIError.client(message: "Body", title: "Title")
        #expect(error.title == "Title")
        #expect(error.message == "Body")
    }
}
