//
//  SignInView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI

fileprivate enum Login: CaseIterable, Hashable {
    case email, password
}

struct SignInView<ViewModel: SignInViewModelProtocol>: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: ViewModel
    @State private var hidePassword: Bool = true
    @State private var disableButton: Bool = false
    @State private var isLoading: Bool = false
    @FocusState private var focused: Login?
    
    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }
    
    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            VStack(alignment: .center, spacing: 0) {
                Text("Virgin Active")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.red)
                
                Text("Sign in to your account")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary)
                    .padding(.top, 12)
                
                TextField("Email", text: $viewModel.email)
                    .focused($focused, equals: .email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.next)
                    .padding(.vertical, 8)
                    .padding(.horizontal)
                    .frame(minHeight: 40)
                    .background {
                        Rectangle()
                            .stroke(viewModel.invalidEmail ? Color.red.opacity(0.9) : Color.black.opacity(0.8), lineWidth: 1)
                    }
                    .padding(.top, 32)
                    .onChange(of: viewModel.email) { _, newValue in
                        checkFieldsValidity(email: newValue, password: nil)
                    }
                    .onSubmit { focused = .password }
                
                HStack(spacing: 0) {
                    Group {
                        if hidePassword {
                            SecureField("Password", text: $viewModel.password)
                        } else {
                            TextField("Password", text: $viewModel.password)
                        }
                    }
                        .focused($focused, equals: .password)
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        .onSubmit {
                            login()
                        }
                    
                    Button(action: {
                        withAnimation(.easeInOut) {
                            hidePassword = !hidePassword
                        }
                    }, label: {
                        Image(systemName: hidePassword ? "eye.circle" : "eye.slash.circle")
                            .foregroundStyle(Color.black.opacity(0.8))
                            .frame(width: 40, height: 40)
                    })
                }
                .background {
                    Rectangle()
                        .stroke(viewModel.invalidPassword ? Color.red.opacity(0.9) : Color.black.opacity(0.8), lineWidth: 1)
                }
                .padding(.top)
                .onChange(of: viewModel.password) { _, newValue in
                    checkFieldsValidity(email: nil, password: newValue)
                }
                
                Button(action: {
                    login()
                }, label: {
                    Text("Sign in")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(10)
                        .clipped()
                    
                })
                .overlay {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(Color.black.opacity(0.8))
                    }
                }
                .background {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(disableButton ? Color.gray : Color.red.opacity(0.9))
                }
                .padding(.top, 24)
                .disabled(disableButton || isLoading)
            }
            .padding(.horizontal)
            .errorAlert($viewModel.error)
            .onChange(of: router.sessionExpired, initial: true) { _, expired in
                if expired {
                    viewModel.error = .unauthorized
                    router.sessionExpired = false
                }
            }
            
            if isLoading {
                Color.black.opacity(0.15).ignoresSafeArea()
            }
        }
    }
    
    private func login() {
        Task {
            defer {
                isLoading = false
            }
            isLoading = true
            await viewModel.login()
            if viewModel.userProfile != nil {
                router.signIn()
            }
        }
    }
    
    private func checkFieldsValidity(email: String?, password: String?) {
        viewModel.evaluateFields(
            email: email,
            password: password
        )
        disableButton = viewModel.invalidEmail || viewModel.invalidPassword
    }
}

#Preview {
    SignInView(
        viewModel: SignInViewModel(service: APIServices.live().auth)
    )
    .environmentObject(AppRouter())
}
