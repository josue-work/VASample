//
//  Fixtures.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
@testable import VASample

enum Fixtures {
    static let johannesburg = TimeZone(secondsFromGMT: 2 * 3600)!

    static func classInstance(
        id: String = "sp-power-spin::2026-10-07",
        clubId: String = "club_sea_point",
        startsIn: TimeInterval = 24 * 60 * 60,
        spots: Int = 18,
        available: Int = 10,
        waitlistCount: Int = 0,
        status: ClassStatus = .available,
        userBookingStatus: UserBookingStatus = .none
    ) -> ClassInstance {
        let start = Date.now.addingTimeInterval(startsIn)
        return ClassInstance(
            classId: id,
            clubId: clubId,
            title: "Power Spin",
            trainer: "Thabo Ndlovu",
            type: .spin,
            startsAt: VenueDate(date: start, timeZone: johannesburg),
            endsAt: VenueDate(date: start.addingTimeInterval(45 * 60), timeZone: johannesburg),
            timezone: "Africa/Johannesburg",
            spots: spots,
            available: available,
            waitlistCount: waitlistCount,
            status: status,
            userBookingStatus: userBookingStatus
        )
    }

    static func timetable(clubId: String = "club_sea_point", classes: [ClassInstance]) -> TimetableResponse {
        TimetableResponse(
            clubId: clubId,
            weekStart: "2026-10-05",
            weekEnd: "2026-10-11",
            selectedDate: "2026-10-07",
            days: [
                TimetableDay(date: "2026-10-06", classes: []),
                TimetableDay(date: "2026-10-07", classes: classes)
            ]
        )
    }

    static let profile = UserProfile(
        id: "user_001",
        firstName: "Avid",
        lastName: "Runner",
        email: "avid.runner@virginactive.mock",
        membershipTier: .premium,
        homeClub: ClubSummary(id: "club_sea_point", name: "Virgin Active Sea Point")
    )

    static let venue = Venue(
        name: "Virgin Active Sea Point",
        address: "96 Beach Rd, Sea Point, Cape Town, 8005",
        phoneNumber: "+27 21 439 1240"
    )

    static func booking(_ classInstance: ClassInstance, status: BookingStatus = .booked, waitlistPosition: Int? = nil) -> BookingResponse {
        BookingResponse(bookingId: "booking_1", status: status, waitlistPosition: waitlistPosition, classInstance: classInstance)
    }

    static func serverError(_ status: Int, _ code: String, message: String? = nil) -> APIError {
        .server(status: status, ServerError(error: code, message: message ?? code, code: nil, requestId: "req_1"))
    }

    static let manifestJSON = """
    {
      "blocks": [
        { "type": "greeting", "title": "Good evening, Avid" },
        { "type": "hero", "title": "Crush your goals", "subtitle": "1 more class" },
        { "type": "myClub", "name": "Virgin Active Sea Point", "addressLine": "96 Beach Rd" },
        { "type": "newBlockFromTheFuture", "title": "Skip me" },
        { "type": "hero" },
        {
          "type": "classCarousel",
          "title": "Your week",
          "viewAllAction": { "type": "openTimetable", "clubId": "club_sea_point" },
          "items": [
            {
              "id": "sp-power-spin::2026-10-05",
              "title": "Power Spin",
              "subtitle": "Thabo Ndlovu",
              "imageRef": "spin",
              "badge": "Booked",
              "startsAt": "2026-10-05T06:00:00+02:00",
              "actionLabel": "View",
              "actionRef": { "type": "openClass", "clubId": "club_sea_point", "classId": "sp-power-spin::2026-10-05" }
            },
            {
              "id": "sp-hiit-lab::2026-10-05",
              "title": "HIIT Lab",
              "startsAt": "2026-10-05T17:30:00+02:00",
              "actionRef": { "type": "openSomethingNew" }
            }
          ]
        },
        { "type": "myRewards", "title": "Your rewards", "items": [{ "id": "reward_001", "title": "Free smoothie", "badge": "Expires Sunday" }] },
        { "type": "myGoals", "items": [{ "id": "goal_get_started", "title": "Set your first goal" }] },
        { "type": "promotion", "title": "Summer Shape-Up", "imageRef": "promo_summer_challenge" },
        { "type": "experimental", "payload": { "kind": "futureFeature", "data": { "foo": "bar" } } }
      ]
    }
    """
}

@MainActor
func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition() && ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
}
