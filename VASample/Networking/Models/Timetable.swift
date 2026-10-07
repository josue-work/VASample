//
//  Timetable.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated struct TimetableResponse: Decodable, Sendable {
    let clubId: String
    let weekStart: String
    let weekEnd: String
    let selectedDate: String
    let days: [TimetableDay]
}

nonisolated struct TimetableDay: Decodable, Sendable, Identifiable, Hashable {
    let date: String
    let classes: [ClassInstance]

    var id: String { date }

    private enum CodingKeys: String, CodingKey {
        case date, classes
    }

    init(date: String, classes: [ClassInstance]) {
        self.date = date
        self.classes = classes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        classes = try container.decode([Lossy<ClassInstance>].self, forKey: .classes).compactMap(\.value)
    }
}

nonisolated struct ClassInstance: Decodable, Sendable, Identifiable, Equatable, Hashable {
    let classId: String
    let clubId: String
    let title: String
    let trainer: String
    let type: ClassType
    let startsAt: VenueDate
    let endsAt: VenueDate
    let timezone: String
    let spots: Int
    let available: Int
    let waitlistCount: Int
    let status: ClassStatus
    let userBookingStatus: UserBookingStatus

    var id: String { classId }
}

nonisolated enum ClassType: String, Sendable, UnknownCaseDecodable {
    case groupWorkout, yoga, spin, pilates, hiit, swimming, unknown
}

nonisolated enum ClassStatus: String, Sendable, UnknownCaseDecodable {
    case available, full, cancelled, unknown
}

nonisolated enum UserBookingStatus: String, Sendable, UnknownCaseDecodable {
    case none, booked, waitlisted, unknown

    var holdsPlace: Bool {
        self == .booked || self == .waitlisted
    }
}

nonisolated struct BookingResponse: Decodable, Sendable {
    let bookingId: String
    let status: BookingStatus
    let waitlistPosition: Int?
    let classInstance: ClassInstance
}

nonisolated enum BookingStatus: String, Decodable, Sendable {
    case booked, waitlisted
}
