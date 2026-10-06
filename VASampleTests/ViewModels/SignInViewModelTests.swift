//
//  SignInViewModelTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@MainActor
struct SignInViewModelTests {
    private func makeViewModel(_ auth: FakeAuthAPI = FakeAuthAPI()) -> SignInViewModel {
        let viewModel = SignInViewModel(service: auth)
        viewModel.email = "avid.runner@virginactive.mock"
        viewModel.password = "password123"
        return viewModel
    }

    @Test func signsInWithTheEnteredCredentials() async {
        let auth = FakeAuthAPI()
        let viewModel = makeViewModel(auth)

        await viewModel.login()

        #expect(viewModel.userProfile == Fixtures.profile)
        #expect(viewModel.error == nil)
        #expect(auth.loginCalls.first?.username == "avid.runner@virginactive.mock")
        #expect(auth.loginCalls.first?.password == "password123")
    }

    @Test(arguments: [
        ("not-an-email", "password123"),
        ("avid.runner@virginactive.mock", ""),
        ("", "")
    ])
    func invalidInputNeverHitsTheAPI(email: String, password: String) async {
        let auth = FakeAuthAPI()
        let viewModel = makeViewModel(auth)
        viewModel.email = email
        viewModel.password = password

        await viewModel.login()

        #expect(auth.loginCalls.isEmpty)
        #expect(viewModel.userProfile == nil)
        guard case .userInput = viewModel.error else {
            Issue.record("Expected userInput error")
            return
        }
    }

    @Test func passwordRulesAreLeftToTheServer() async {
        let auth = FakeAuthAPI()
        let viewModel = makeViewModel(auth)
        viewModel.password = "X"

        await viewModel.login()

        #expect(auth.loginCalls.first?.password == "X")
    }

    @Test func wrongPasswordShowsTheServerMessage() async {
        let auth = FakeAuthAPI()
        auth.loginResult = .failure(Fixtures.serverError(401, "InvalidCredentials", message: "The username or password is incorrect."))
        let viewModel = makeViewModel(auth)

        await viewModel.login()

        guard case .userInput(let message) = viewModel.error else {
            Issue.record("Expected userInput error")
            return
        }
        #expect(message == "The username or password is incorrect.")
        #expect(viewModel.userProfile == nil)
    }

    @Test func serverOutageIsReportedAsAServerError() async {
        let auth = FakeAuthAPI()
        auth.loginResult = .failure(Fixtures.serverError(500, "ChaosFailure"))
        let viewModel = makeViewModel(auth)

        await viewModel.login()

        guard case .server = viewModel.error else {
            Issue.record("Expected server error")
            return
        }
    }

    @Test func fieldValidationFlagsOnlyTheFieldThatChanged() {
        let viewModel = SignInViewModel(service: FakeAuthAPI())

        viewModel.evaluateFields(email: "bad", password: nil)
        #expect(viewModel.invalidEmail)
        #expect(!viewModel.invalidPassword)

        viewModel.evaluateFields(email: nil, password: "password123")
        #expect(viewModel.invalidEmail)
        #expect(!viewModel.invalidPassword)

        viewModel.evaluateFields(email: "avid.runner@virginactive.mock", password: nil)
        #expect(!viewModel.invalidEmail)
    }
}
