//
//  ErrorAlertModifier.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI

struct ErrorAlertModifier: ViewModifier {
    @Binding var error: UIError?

    private var isPresented: Binding<Bool> {
        Binding(
            get: { error != nil },
            set: { _ in }
        )
    }

    func body(content: Content) -> some View {
        content.alert(
            error?.title ?? "",
            isPresented: isPresented,
            presenting: error
        ) { presented in
            if case .server(_, let retry?) = presented {
                Button("Retry") {
                    error = nil
                    retry()
                }
                Button("Cancel", role: .cancel) { error = nil }
            } else {
                Button("OK", role: .cancel) { error = nil }
            }
        } message: { error in
            Text(error.message)
        }
        .tint(Color.red.opacity(0.9))
    }
}

extension View {
    func errorAlert(_ error: Binding<UIError?>) -> some View {
        modifier(ErrorAlertModifier(error: error))
    }
}
