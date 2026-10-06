//
//  ClassesAPI.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated protocol ClassesAPIProtocol: Sendable {
    func timetable(clubId: String, date: String?) async throws -> TimetableResponse
    func book(clubId: String, classId: String) async throws -> BookingResponse
    func cancelBooking(clubId: String, classId: String) async throws
}

nonisolated final class ClassesAPI: ClassesAPIProtocol {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }

    func timetable(clubId: String, date: String? = nil) async throws -> TimetableResponse {
        try await client.send(.timetable(clubId: clubId, date: date), as: TimetableResponse.self)
    }

    func book(clubId: String, classId: String) async throws -> BookingResponse {
        try await client.send(.book(clubId: clubId, classId: classId), as: BookingResponse.self)
    }

    func cancelBooking(clubId: String, classId: String) async throws {
        try await client.send(.cancelBooking(clubId: clubId, classId: classId))
    }
}
