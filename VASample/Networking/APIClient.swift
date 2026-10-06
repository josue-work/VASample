//
//  APIClient.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated protocol APIClientProtocol: Sendable {
    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type) async throws -> T
    func send(_ endpoint: Endpoint) async throws
    func refreshSession() async throws
}

nonisolated final class APIClient: APIClientProtocol {
    let tokenStore: TokenStore
    private let baseURL: URL
    private let session: URLSession
    private let maxRetries: Int
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(
        baseURL: URL = APIEnvironment.baseURL,
        session: URLSession? = nil,
        tokenStore: TokenStore = TokenStore(),
        maxRetries: Int = 2
    ) {
        self.baseURL = baseURL
        self.maxRetries = maxRetries
        self.tokenStore = tokenStore
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = APIEnvironment.timeout
            config.waitsForConnectivity = false
            self.session = URLSession(configuration: config)
        }
    }

    func send<T: Decodable & Sendable>(_ endpoint: Endpoint, as type: T.Type = T.self) async throws -> T {
        let data = try await data(for: endpoint)
        do {
            return try decoder.decode(T.self, from: data)
        } catch let error as DecodingError {
            throw APIError.decoding(error)
        }
    }

    func send(_ endpoint: Endpoint) async throws {
        _ = try await data(for: endpoint)
    }

    func refreshSession() async throws {
        let accessToken = await tokenStore.accessToken
        _ = try await tokenStore.refreshedTokens(replacing: accessToken) { [self] refreshToken in
            try await refresh(refreshToken)
        }
    }

    private func data(for endpoint: Endpoint, attempt: Int = 0, retryOnUnauthorized: Bool = true) async throws -> Data {
        let accessToken = endpoint.requiresAuth ? await tokenStore.accessToken : nil
        if endpoint.requiresAuth && accessToken == nil {
            throw APIError.unauthorized
        }

        let request = try makeRequest(for: endpoint, accessToken: accessToken)
        let (data, response) = try await perform(request)

        switch response.statusCode {
        case 200..<300:
            return data
        case let status where isRetryable(status, endpoint) && attempt < maxRetries:
            try await Task.sleep(for: retryDelay(attempt: attempt))
            return try await self.data(for: endpoint, attempt: attempt + 1, retryOnUnauthorized: retryOnUnauthorized)
        case 401 where endpoint.requiresAuth:
            guard retryOnUnauthorized else {
                await tokenStore.expireSession()
                throw APIError.unauthorized
            }
            _ = try await tokenStore.refreshedTokens(replacing: accessToken) { [self] refreshToken in
                try await refresh(refreshToken)
            }
            return try await self.data(for: endpoint, retryOnUnauthorized: false)
        default:
            throw APIError.server(status: response.statusCode, try? decoder.decode(ServerError.self, from: data))
        }
    }

    private func isRetryable(_ status: Int, _ endpoint: Endpoint) -> Bool {
        endpoint.isRetryable && (status == 429 || (500..<600).contains(status))
    }

    private func retryDelay(attempt: Int) -> Duration {
        .milliseconds(300 * (1 << attempt))
    }

    private func refresh(_ refreshToken: String) async throws -> AuthTokens {
        let response = try await send(.refresh(RefreshRequest(refreshToken: refreshToken)), as: AuthTokens.self)
        return response
    }

    private func makeRequest(for endpoint: Endpoint, accessToken: String?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.path = endpoint.path
        components.queryItems = endpoint.queryItems.isEmpty ? nil : endpoint.queryItems
        guard let url = components.url else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if endpoint.body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
            return (data, http)
        } catch let error as URLError {
            throw APIError.transport(error)
        }
    }
}
