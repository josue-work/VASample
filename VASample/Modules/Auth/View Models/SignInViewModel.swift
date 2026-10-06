//
//  SignInViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation
import Combine

@MainActor protocol SignInViewModelProtocol: ObservableObject {
    var email: String { get set }
    var password: String { get set }
    var error: UIError? { get set }
    var userProfile: UserProfile? { get }
    var invalidEmail: Bool { get }
    var invalidPassword: Bool { get }
    
    func login() async
    func evaluateFields(email: String?, password: String?)
}

@MainActor final class SignInViewModel: SignInViewModelProtocol {
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var error: UIError?
    @Published private(set) var userProfile: UserProfile?
    @Published private(set) var invalidEmail: Bool = false
    @Published private(set) var invalidPassword: Bool = false
    private let service: AuthAPIProtocol
    
    init(
        service: (any AuthAPIProtocol)
    ) {
        self.service = service
    }
    
    func login() async {
        evaluateFields(email: email, password: password)
        guard !invalidEmail, !invalidPassword else {
            error = .userInput(message: "Please check your username and password.")
            return
        }
        do {
            userProfile = try await service.login(username: email, password: password)
#if DEBUG
            debugPrint("Auth: Login successful")
#endif
        } catch {
#if DEBUG
            debugPrint("Error: \(error.localizedDescription)")
#endif
            self.error = UIError(error)
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let pattern = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: pattern, options: .regularExpression) != nil
    }
    
    
    func evaluateFields(email: String?, password: String?) {
        if email != nil {
            invalidEmail = !isValidEmail(email ?? self.email)
        }
        if password != nil {
            invalidPassword = (password ?? self.password).isEmpty
        }
    }
}
