//
//  APIError.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated struct ServerError: Decodable, Sendable, Equatable {
    let error: String
    let message: String
    let code: String?
    let requestId: String
}

nonisolated enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case transport(URLError)
    case decoding(DecodingError)
    case server(status: Int, ServerError?)

    var errorDescription: String? {
        switch self {
        case .invalidURL, .invalidResponse, .decoding:
            "Something went wrong. Please try again."
        case .unauthorized:
            "Your session has expired. Please sign in again."
        case .transport(let error):
            error.localizedDescription
        case .server(let status, let body):
            body?.message ?? HTTPURLResponse.localizedString(forStatusCode: status)
        }
    }

    var serverError: ServerError? {
        if case .server(_, let body) = self { body } else { nil }
    }

    var isTransient: Bool {
        switch self {
        case .transport(let error):
            error.code != .cancelled
        case .server(let status, _):
            status == 429 || (500..<600).contains(status)
        case .invalidURL, .invalidResponse, .unauthorized, .decoding:
            false
        }
    }

    func hasServerCode(_ code: String) -> Bool {
        serverError?.error == code
    }
}
