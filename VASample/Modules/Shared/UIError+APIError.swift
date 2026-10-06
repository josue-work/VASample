//
//  UIError+APIError.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//


import Foundation

extension UIError {
    init?(_ error: Error, retry: (() -> Void)? = nil) {
        if error is CancellationError { return nil }
        guard let apiError = error as? APIError else {
            self = .client(message: error.localizedDescription, title: "Unexpected error")
            return
        }
        switch apiError {
        case .transport(let urlError) where urlError.code == .cancelled:
            return nil
        case .transport(let urlError):
            self = .server(message: urlError.localizedDescription, retryable: retry)
        case .unauthorized:
            self = .unauthorized
        case .server(let status, let body) where (400..<500).contains(status) && status != 429:
            self = .userInput(message: body?.message ?? HTTPURLResponse.localizedString(forStatusCode: status))
        case .server(_, let body):
            self = .server(message: body?.message, retryable: retry)
        case .invalidURL, .invalidResponse, .decoding:
            self = .server(message: nil, retryable: nil)
        }
    }
}
