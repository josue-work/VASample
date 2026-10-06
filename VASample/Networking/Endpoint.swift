//
//  Endpoint.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

nonisolated struct Endpoint: Sendable {
    var path: String
    var method: HTTPMethod = .get
    var queryItems: [URLQueryItem] = []
    var body: Data? = nil
    var requiresAuth: Bool = true
    var isRetryable: Bool = false
}

nonisolated extension Endpoint {
    static func login(_ request: LoginRequest) throws -> Endpoint {
        Endpoint(path: "/auth/login", method: .post, body: try JSONEncoder().encode(request), requiresAuth: false)
    }

    static func refresh(_ request: RefreshRequest) throws -> Endpoint {
        Endpoint(path: "/auth/refresh", method: .post, body: try JSONEncoder().encode(request), requiresAuth: false, isRetryable: true)
    }

    static let me = Endpoint(path: "/me", isRetryable: true)

    static let homeManifest = Endpoint(path: "/home/manifest", isRetryable: true)

    static func timetable(clubId: String, date: String?) -> Endpoint {
        Endpoint(
            path: "/clubs/\(clubId)/classes/timetable",
            queryItems: date.map { [URLQueryItem(name: "date", value: $0)] } ?? [],
            isRetryable: true
        )
    }

    static func book(clubId: String, classId: String) -> Endpoint {
        Endpoint(path: "/clubs/\(clubId)/classes/\(classId)/bookings", method: .post)
    }

    static func cancelBooking(clubId: String, classId: String) -> Endpoint {
        Endpoint(path: "/clubs/\(clubId)/classes/\(classId)/bookings", method: .delete)
    }
}
