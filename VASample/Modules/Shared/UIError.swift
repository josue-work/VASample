//
//  UIError.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated enum UIError: Error, LocalizedError {
    case userInput(message: String)
    case client(message: String, title: String)
    case server(message: String?, retryable: (() -> Void)?)
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .unauthorized:
            "Your session has expired. Please sign in again."
        case .client(let message, let title):
            "\(title): \(message)"
        case .server(let message, _):
            message ?? "Something went wrong. Please try again."
        case .userInput(let message):
            message
        }
    }
    
    var title: String {
        switch self {
        case .userInput: "Check your details"
        case .client(_, let title): title
        case .server: "Something went wrong"
        case .unauthorized: "Session expired"
        }
    }

    var message: String {
        switch self {
        case .client(let message, _): message
        default: errorDescription ?? ""
        }
    }
}
