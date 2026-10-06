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

nonisolated enum ClassType: String, Decodable, Sendable {
    case groupWorkout, yoga, spin, pilates, hiit, swimming
}

nonisolated enum ClassStatus: String, Decodable, Sendable {
    case available, full, cancelled
}

nonisolated enum UserBookingStatus: String, Decodable, Sendable {
    case none, booked, waitlisted
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
