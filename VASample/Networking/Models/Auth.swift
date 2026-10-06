//
//  Auth.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated struct LoginRequest: Encodable, Sendable {
    let username: String
    let password: String
}

nonisolated struct LoginResponse: Decodable, Sendable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
    let user: UserProfile
}

nonisolated struct RefreshRequest: Encodable, Sendable {
    let refreshToken: String
}

nonisolated struct AuthTokens: Codable, Sendable, Equatable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let expiresIn: Int
}
