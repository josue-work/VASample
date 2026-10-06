//
//  ProfileAPI.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated protocol ProfileAPIProtocol: Sendable {
    func me() async throws -> UserProfile
}

nonisolated final class ProfileAPI: ProfileAPIProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func me() async throws -> UserProfile {
        try await client.send(.me, as: UserProfile.self)
    }
}
