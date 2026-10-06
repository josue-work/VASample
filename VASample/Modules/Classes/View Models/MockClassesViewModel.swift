//
//  MockClassesViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Combine

@MainActor final class MockClassesViewModel: ClassesViewModelProtocol {
    @Published private(set) var days: [TimetableDay] = []
    @Published var selectedDate: String?
    @Published private(set) var isLoading: Bool = false
    @Published var error: UIError?
    private let mockError: UIError?

    init(mockError: UIError?) {
        self.mockError = mockError
    }

    var selectedClasses: [ClassInstance] {
        days.first { $0.date == selectedDate }?.classes ?? []
    }

    func loadClasses() async {
        defer { isLoading = false }
        isLoading = true
        if let mockError {
            self.error = mockError
        } else {
            days = Self.allClasses
            selectedDate = selectedDate ?? days.first?.date
        }
    }

    func makeDetailsViewModelFor(_ classInstance: ClassInstance) -> MockClassesDetailsViewModel {
        MockClassesDetailsViewModel(classInstance: classInstance, mockError: mockError)
    }
    
}

extension MockClassesViewModel {
    static let allClasses: [TimetableDay] = [
        TimetableDay(
            date: mockDay(daysFromNow: 1),
            classes: [
                MockClassesDetailsViewModel.booked,
                MockClassesDetailsViewModel.available,
                MockClassesDetailsViewModel.waitlisted
            ]
        ),
        TimetableDay(
            date: mockDay(daysFromNow: 2),
            classes: [
                MockClassesDetailsViewModel.full,
                ClassInstance(
                    classId: "sp-pilates-core::2026-10-06",
                    clubId: "club_sea_point",
                    title: "Pilates Core",
                    trainer: "Zanele Khumalo",
                    type: .pilates,
                    startsAt: mockDate(daysFromNow: 2, hour: 8),
                    endsAt: mockDate(daysFromNow: 2, hour: 8, minute: 50),
                    timezone: "Africa/Johannesburg",
                    spots: 14,
                    available: 2,
                    waitlistCount: 0,
                    status: .available,
                    userBookingStatus: .none
                ),
                MockClassesDetailsViewModel.cancelled
            ]
        ),
        TimetableDay(
            date: mockDay(daysFromNow: 3),
            classes: [
                ClassInstance(
                    classId: "sp-group-blast::2026-10-07",
                    clubId: "club_sea_point",
                    title: "Group Blast",
                    trainer: "Sipho Dlamini",
                    type: .groupWorkout,
                    startsAt: mockDate(daysFromNow: 3, hour: 7),
                    endsAt: mockDate(daysFromNow: 3, hour: 7, minute: 45),
                    timezone: "Africa/Johannesburg",
                    spots: 25,
                    available: 25,
                    waitlistCount: 0,
                    status: .available,
                    userBookingStatus: .none
                ),
                ClassInstance(
                    classId: "sp-lunchtime-spin::2026-10-07",
                    clubId: "club_sea_point",
                    title: "Lunchtime Spin",
                    trainer: "Thabo Ndlovu",
                    type: .spin,
                    startsAt: mockDate(daysFromNow: 3, hour: 12),
                    endsAt: mockDate(daysFromNow: 3, hour: 12, minute: 45),
                    timezone: "Africa/Johannesburg",
                    spots: 18,
                    available: 9,
                    waitlistCount: 0,
                    status: .available,
                    userBookingStatus: .none
                )
            ]
        ),
        TimetableDay(date: mockDay(daysFromNow: 4), classes: [])
    ]
}

private let mockTimeZone = TimeZone(identifier: "Africa/Johannesburg") ?? .current

private var mockCalendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = mockTimeZone
    return calendar
}

func mockDate(daysFromNow: Int, hour: Int, minute: Int = 0) -> VenueDate {
    let day = mockCalendar.date(byAdding: .day, value: daysFromNow, to: mockCalendar.startOfDay(for: .now)) ?? .now
    let date = mockCalendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) ?? day
    return VenueDate(date: date, timeZone: mockTimeZone)
}

func mockDay(daysFromNow: Int) -> String {
    mockDate(daysFromNow: daysFromNow, hour: 0).date
        .formatted(Date.ISO8601FormatStyle(dateSeparator: .dash, timeZone: mockTimeZone).year().month().day())
}
