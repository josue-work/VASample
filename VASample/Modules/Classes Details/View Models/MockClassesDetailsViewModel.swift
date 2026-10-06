//
//  MockClassesDetailsViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Combine

@MainActor final class MockClassesDetailsViewModel: ClassesDetailsViewModelProtocol {
    
    @Published private(set) var classInstance: ClassInstance
    @Published private(set) var bookingResponse: BookingResponse?
    @Published private(set) var justBooked: Bool = false
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var hasReminder: Bool = false
    @Published var calendarEvent: CalendarEventDraft?
    @Published var error: UIError?
    let venue: Venue?
    private let mockError: UIError?

    init(classInstance: ClassInstance, venue: Venue? = MockClassesDetailsViewModel.venue, mockError: UIError? = nil) {
        self.classInstance = classInstance
        self.venue = venue
        self.mockError = mockError
    }

    var canBook: Bool {
        classInstance.userBookingStatus == .none
            && classInstance.status != .cancelled
            && !hasStarted
            && !isProcessing
    }

    var canCancel: Bool {
        classInstance.userBookingStatus != .none && !hasStarted && !isProcessing
    }

    var canSetReminder: Bool {
        classInstance.userBookingStatus != .none && !hasReminder && reminderDate > .now && !isProcessing
    }

    func book() async {
        isProcessing = true
        defer { isProcessing = false }
        if let mockError {
            error = mockError
            return
        }
        justBooked = true
        if classInstance.available > 0 {
            classInstance = classInstance.mocked(
                available: classInstance.available - 1,
                waitlistCount: classInstance.waitlistCount,
                userBookingStatus: .booked
            )
            bookingResponse = BookingResponse(
                bookingId: UUID().uuidString,
                status: .booked,
                waitlistPosition: nil,
                classInstance: classInstance
            )
        } else {
            classInstance = classInstance.mocked(
                available: 0,
                waitlistCount: classInstance.waitlistCount + 1,
                userBookingStatus: .waitlisted
            )
            bookingResponse = BookingResponse(
                bookingId: UUID().uuidString,
                status: .waitlisted,
                waitlistPosition: classInstance.waitlistCount,
                classInstance: classInstance
            )
        }
    }

    func cancelBooking() async {
        isProcessing = true
        defer { isProcessing = false }
        if let mockError {
            error = mockError
            return
        }
        let wasBooked = classInstance.userBookingStatus == .booked
        bookingResponse = nil
        justBooked = false
        hasReminder = false
        classInstance = classInstance.mocked(
            available: wasBooked ? classInstance.available + 1 : classInstance.available,
            waitlistCount: wasBooked ? classInstance.waitlistCount : max(classInstance.waitlistCount - 1, 0),
            userBookingStatus: .none
        )
    }
    
    func setReminder() async {
        if let mockError {
            error = mockError
            return
        }
        hasReminder = true
    }
    
    func removeReminder() async {
        if let mockError {
            error = mockError
            return
        }
        hasReminder = false
    }
    
    func loadReminderState() async {
    }

    func addToCalendar() {
        guard canAddToCalendar else { return }
        calendarEvent = calendarEventDraft
    }

    func finishAddingToCalendar() {
        calendarEvent = nil
    }
}

extension MockClassesDetailsViewModel {
    nonisolated static let venue = Venue(
        name: "Virgin Active Sea Point",
        address: "96 Beach Rd, Sea Point, Cape Town, 8005",
        phoneNumber: "+27 21 439 1240"
    )

    static let available = ClassInstance(
        classId: "sp-sunrise-yoga::2026-10-05",
        clubId: "club_sea_point",
        title: "Sunrise Yoga",
        trainer: "Lerato Molefe",
        type: .yoga,
        startsAt: mockDate(daysFromNow: 1, hour: 7),
        endsAt: mockDate(daysFromNow: 1, hour: 8),
        timezone: "Africa/Johannesburg",
        spots: 20,
        available: 12,
        waitlistCount: 0,
        status: .available,
        userBookingStatus: .none
    )

    static let booked = ClassInstance(
        classId: "sp-power-spin::2026-10-05",
        clubId: "club_sea_point",
        title: "Power Spin",
        trainer: "Thabo Ndlovu",
        type: .spin,
        startsAt: mockDate(daysFromNow: 1, hour: 6),
        endsAt: mockDate(daysFromNow: 1, hour: 6, minute: 45),
        timezone: "Africa/Johannesburg",
        spots: 18,
        available: 17,
        waitlistCount: 0,
        status: .available,
        userBookingStatus: .booked
    )

    static let waitlisted = ClassInstance(
        classId: "sp-hiit-lab::2026-10-05",
        clubId: "club_sea_point",
        title: "HIIT Lab",
        trainer: "Sipho Dlamini",
        type: .hiit,
        startsAt: mockDate(daysFromNow: 1, hour: 17, minute: 30),
        endsAt: mockDate(daysFromNow: 1, hour: 18, minute: 15),
        timezone: "Africa/Johannesburg",
        spots: 16,
        available: 0,
        waitlistCount: 3,
        status: .full,
        userBookingStatus: .waitlisted
    )

    static let full = ClassInstance(
        classId: "sp-aqua-lanes::2026-10-06",
        clubId: "club_sea_point",
        title: "Aqua Lanes",
        trainer: "Naledi Botha",
        type: .swimming,
        startsAt: mockDate(daysFromNow: 2, hour: 6, minute: 30),
        endsAt: mockDate(daysFromNow: 2, hour: 7, minute: 15),
        timezone: "Africa/Johannesburg",
        spots: 8,
        available: 0,
        waitlistCount: 1,
        status: .full,
        userBookingStatus: .none
    )

    static let cancelled = ClassInstance(
        classId: "sp-evening-spin::2026-10-06",
        clubId: "club_sea_point",
        title: "Evening Spin",
        trainer: "Thabo Ndlovu",
        type: .spin,
        startsAt: mockDate(daysFromNow: 2, hour: 18),
        endsAt: mockDate(daysFromNow: 2, hour: 18, minute: 45),
        timezone: "Africa/Johannesburg",
        spots: 18,
        available: 18,
        waitlistCount: 0,
        status: .cancelled,
        userBookingStatus: .none
    )
}

private extension ClassInstance {
    func mocked(available: Int, waitlistCount: Int, userBookingStatus: UserBookingStatus) -> ClassInstance {
        ClassInstance(
            classId: classId,
            clubId: clubId,
            title: title,
            trainer: trainer,
            type: type,
            startsAt: startsAt,
            endsAt: endsAt,
            timezone: timezone,
            spots: spots,
            available: available,
            waitlistCount: waitlistCount,
            status: available == 0 && status == .available ? .full : status,
            userBookingStatus: userBookingStatus
        )
    }
}
