//
//  HomeAPI.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated protocol HomeAPIProtocol: Sendable {
    func manifest() async throws -> HomeManifest
}

nonisolated final class HomeAPI: HomeAPIProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func manifest() async throws -> HomeManifest {
        try await client.send(.homeManifest, as: HomeManifest.self)
    }
}
