//
//  VenueDateTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

struct VenueDateTests {
    private func decode(_ string: String) -> VenueDate? {
        try? JSONDecoder().decode([VenueDate].self, from: Data("[\"\(string)\"]".utf8)).first
    }

    @Test(arguments: [
        ("2026-10-05T06:00:00+02:00", 7200),
        ("2026-10-07T17:30:00+01:00", 3600),
        ("2026-10-07T07:15:00-05:00", -18000),
        ("2026-10-07T17:30:00.123+05:30", 19800),
        ("2026-10-07T17:30:00Z", 0)
    ])
    func keepsTheVenueOffset(string: String, offset: Int) throws {
        let venueDate = try #require(decode(string))
        #expect(venueDate.timeZone.secondsFromGMT() == offset)
    }

    @Test(arguments: ["", "2026-10-05", "2026-10-05T06:00:00", "not a date"])
    func rejectsStringsWithoutAnOffset(string: String) {
        #expect(decode(string) == nil)
    }

    @Test func rendersInVenueTimeNotDeviceTime() throws {
        let newYork = try #require(decode("2026-10-07T07:15:00-05:00"))
        let london = try #require(decode("2026-10-07T17:30:00+01:00"))

        #expect(newYork.time.contains("7:15"))
        #expect(london.time.contains(":30"))
        #expect(london.fullDate.contains("7"))
    }

    @Test func decodingFailsLoudlyOnBadInput() {
        let json = Data(#"["2026-10-05 06:00"]"#.utf8)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([VenueDate].self, from: json)
        }
    }

    @Test func comparesByInstantNotWallClock() throws {
        let joburg = try #require(decode("2026-10-07T18:00:00+02:00"))
        let london = try #require(decode("2026-10-07T17:30:00+01:00"))
        #expect(joburg < london)
    }

    @Test func dayHeaderIgnoresDeviceTimeZone() {
        #expect(DayFormatter.header(for: "2026-10-05").contains("5"))
        #expect(DayFormatter.header(for: "garbage") == "garbage")
    }
}
