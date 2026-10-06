//
//  HomeManifestDecodingTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

struct HomeManifestDecodingTests {
    private func decodeFixture() throws -> HomeManifest {
        try JSONDecoder().decode(HomeManifest.self, from: Data(Fixtures.manifestJSON.utf8))
    }

    @Test func skipsUnknownMalformedAndExperimentalBlocksWithoutFailing() throws {
        let manifest = try decodeFixture()
        #expect(manifest.blocks.map(\.type) == [
            .greeting, .hero, .myClub, .classCarousel, .myRewards, .myGoals, .promotion
        ])
    }

    @Test func keepsServerOrder() throws {
        let manifest = try decodeFixture()
        #expect(manifest.blocks.first == .greeting(GreetingBlock(title: "Good evening, Avid")))
    }

    @Test func decodesCarouselActionsAndVenueTimes() throws {
        let manifest = try decodeFixture()
        let carousel = try #require(manifest.blocks.compactMap { block -> ClassCarouselBlock? in
            if case .classCarousel(let carousel) = block { carousel } else { nil }
        }.first)

        #expect(carousel.viewAllAction == .openTimetable(clubId: "club_sea_point"))
        #expect(carousel.items[0].actionRef == .openClass(clubId: "club_sea_point", classId: "sp-power-spin::2026-10-05"))
        #expect(carousel.items[0].startsAt.timeZone.secondsFromGMT() == 7200)
        #expect(carousel.items[1].actionRef == .unsupported("openSomethingNew"))
        #expect(carousel.items[1].badge == nil)
    }

    @Test func optionalFieldsMayBeMissing() throws {
        let manifest = try decodeFixture()
        guard case .myGoals(let goals) = manifest.blocks[5] else {
            Issue.record("Expected myGoals at index 5")
            return
        }
        #expect(goals.title == nil)
        #expect(goals.items.first?.subtitle == nil)
    }

    @Test func emptyManifestIsValid() throws {
        let manifest = try JSONDecoder().decode(HomeManifest.self, from: Data(#"{"blocks":[]}"#.utf8))
        #expect(manifest.blocks.isEmpty)
    }
}
