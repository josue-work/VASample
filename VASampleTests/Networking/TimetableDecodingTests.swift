//
//  TimetableDecodingTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/07.
//

import Foundation
import Testing
@testable import VASample

struct TimetableDecodingTests {
    private func classJSON(id: String, type: String = "spin", status: String = "available", userBookingStatus: String = "none") -> String {
        """
        {"classId":"\(id)","clubId":"club_sea_point","title":"Power Spin","trainer":"Thabo Ndlovu","type":"\(type)",
         "startsAt":"2026-10-07T07:00:00+02:00","endsAt":"2026-10-07T07:45:00+02:00","timezone":"Africa/Johannesburg",
         "spots":18,"available":10,"waitlistCount":0,"status":"\(status)","userBookingStatus":"\(userBookingStatus)"}
        """
    }

    private func decodeWeek(_ classes: [String]) throws -> TimetableResponse {
        let json = """
        {"clubId":"club_sea_point","weekStart":"2026-10-05","weekEnd":"2026-10-11","selectedDate":"2026-10-07",
         "days":[{"date":"2026-10-07","classes":[\(classes.joined(separator: ","))]}]}
        """
        return try JSONDecoder().decode(TimetableResponse.self, from: Data(json.utf8))
    }

    @Test func unknownEnumValuesDecodeAsUnknown() throws {
        let week = try decodeWeek([classJSON(id: "a", type: "boxing", status: "inProgress", userBookingStatus: "pending")])
        let classInstance = try #require(week.days.first?.classes.first)
        #expect(classInstance.type == .unknown)
        #expect(classInstance.status == .unknown)
        #expect(classInstance.userBookingStatus == .unknown)
        #expect(!classInstance.userBookingStatus.holdsPlace)
    }

    @Test func malformedClassesAreSkippedIndividually() throws {
        let week = try decodeWeek([classJSON(id: "a"), #"{"classId":"broken"}"#, classJSON(id: "b")])
        #expect(week.days.first?.classes.map(\.classId) == ["a", "b"])
    }

    @Test func unknownMembershipTierDoesNotBlockSignIn() throws {
        let json = """
        {"id":"user_001","firstName":"Avid","lastName":"Runner","email":"avid.runner@virginactive.mock",
         "membershipTier":"platinum","homeClub":{"id":"club_sea_point","name":"Virgin Active Sea Point"}}
        """
        let profile = try JSONDecoder().decode(UserProfile.self, from: Data(json.utf8))
        #expect(profile.membershipTier == .unknown)
    }
}
