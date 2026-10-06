//
//  VenueDate+Formatting.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation

extension VenueDate {
    var time: String {
        formatted(.dateTime.hour().minute())
    }

    var dayAndTime: String {
        formatted(.dateTime.weekday(.wide).hour().minute())
    }

    var fullDate: String {
        formatted(.dateTime.weekday(.wide).month(.wide).day().year())
    }

    private func formatted(_ style: Date.FormatStyle) -> String {
        var style = style
        style.timeZone = timeZone
        return date.formatted(style)
    }
}

enum DayFormatter {
    private static let utc = TimeZone(secondsFromGMT: 0) ?? .gmt

    static func header(for isoDay: String) -> String {
        guard let date = try? Date(isoDay, strategy: Date.ISO8601FormatStyle(timeZone: utc).year().month().day()) else {
            return isoDay
        }
        var style = Date.FormatStyle.dateTime.weekday(.abbreviated).month(.wide).day()
        style.timeZone = utc
        return date.formatted(style)
    }
}
