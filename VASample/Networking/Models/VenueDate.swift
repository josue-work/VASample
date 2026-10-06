//
//  VenueDate.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation

nonisolated struct VenueDate: Decodable, Sendable, Hashable, Comparable {
    let date: Date
    let timeZone: TimeZone

    init(date: Date, timeZone: TimeZone = .current) {
        self.date = date
        self.timeZone = timeZone
    }

    private init?(iso8601 string: String) {
        guard let date = try? Date(string, strategy: .iso8601),
              let offset = Self.offsetSeconds(in: string),
              let timeZone = TimeZone(secondsFromGMT: offset) else {
            return nil
        }
        self.init(date: date, timeZone: timeZone)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let value = VenueDate(iso8601: string) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date with offset: \(string)")
        }
        self = value
    }

    static func < (lhs: VenueDate, rhs: VenueDate) -> Bool {
        lhs.date < rhs.date
    }

    private static func offsetSeconds(in string: String) -> Int? {
        if string.hasSuffix("Z") { return 0 }
        let suffix = string.suffix(6)
        guard suffix.count == 6,
              let sign = suffix.first, sign == "+" || sign == "-",
              suffix.dropFirst(3).first == ":",
              let hours = Int(suffix.dropFirst().prefix(2)),
              let minutes = Int(suffix.suffix(2)) else {
            return nil
        }
        return (sign == "-" ? -1 : 1) * (hours * 3600 + minutes * 60)
    }
}
