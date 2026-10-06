//
//  HomeViewModelTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@MainActor
struct HomeViewModelTests {
    private let home = FakeHomeAPI()
    private let store = FakeTimetableStore()
    private let auth = FakeAuthAPI()
    private let venueStore = VenueStore()

    private func makeViewModel() -> HomeViewModel {
        HomeViewModel(service: home, store: store, venueStore: venueStore, authService: auth)
    }

    private var manifest: HomeManifest {
        HomeManifest(blocks: [.greeting(GreetingBlock(title: "Good evening, Avid"))])
    }

    @Test func rendersWhateverTheServerReturns() async {
        home.results = [.success(manifest)]
        let viewModel = makeViewModel()

        await viewModel.load()

        #expect(viewModel.blocks == manifest.blocks)
        #expect(!viewModel.isLoading)
        #expect(viewModel.error == nil)
    }

    @Test func loadingDoesNotTouchTheTimetableCache() async {
        home.results = [.success(manifest)]
        await makeViewModel().load()
        #expect(store.invalidateCalls == 0)
    }

    @Test func failureOffersRetry() async {
        home.results = [.failure(Fixtures.serverError(500, "ChaosFailure")), .success(manifest)]
        let viewModel = makeViewModel()

        await viewModel.load()
        guard case .server(_, let retry?) = viewModel.error else {
            Issue.record("Expected retryable error")
            return
        }
        retry()
        await waitUntil { !viewModel.blocks.isEmpty }

        #expect(home.calls == 2)
        #expect(viewModel.blocks == manifest.blocks)
    }

    @Test func openingAClassResolvesTheFullInstance() async {
        let spin = Fixtures.classInstance()
        store.classInstanceResult = .success(spin)
        let viewModel = makeViewModel()

        await viewModel.openClass(clubId: "club_sea_point", classId: spin.classId)

        #expect(viewModel.selectedClass == spin)
        #expect(viewModel.openingClassId == nil)
    }

    @Test func classNoLongerOnTheTimetable() async {
        store.classInstanceResult = .success(nil)
        let viewModel = makeViewModel()

        await viewModel.openClass(clubId: "club_sea_point", classId: "gone::2026-10-07")

        #expect(viewModel.selectedClass == nil)
        guard case .client(_, let title) = viewModel.error else {
            Issue.record("Expected client error")
            return
        }
        #expect(title == "Class unavailable")
    }

    @Test func doubleTapOnlyResolvesOnce() async {
        store.classInstanceResult = .success(Fixtures.classInstance())
        store.classInstanceDelay = .milliseconds(100)
        let viewModel = makeViewModel()

        let first = Task { await viewModel.openClass(clubId: "club_sea_point", classId: "a") }
        await waitUntil { viewModel.openingClassId != nil }
        await viewModel.openClass(clubId: "club_sea_point", classId: "b")
        await first.value

        #expect(store.classInstanceCalls == 1)
    }

    @Test func lookupFailureOffersRetry() async {
        store.classInstanceResult = .failure(Fixtures.serverError(500, "ChaosFailure"))
        let viewModel = makeViewModel()

        await viewModel.openClass(clubId: "club_sea_point", classId: "a")

        guard case .server(_, .some) = viewModel.error else {
            Issue.record("Expected retryable error")
            return
        }
    }

    @Test func detailsViewModelStartsFromTheResolvedClass() {
        let spin = Fixtures.classInstance()
        #expect(makeViewModel().makeDetailsViewModelFor(spin).classInstance == spin)
    }

    @Test func logoutClearsSessionCacheVenueAndScreen() async {
        home.results = [.success(manifestWithClub)]
        let viewModel = makeViewModel()
        await viewModel.load()

        await viewModel.logout()

        #expect(auth.logoutCalls == 1)
        #expect(store.invalidateCalls == 1)
        #expect(venueStore.venue == nil)
        #expect(viewModel.blocks.isEmpty)
    }

    private var manifestWithClub: HomeManifest {
        HomeManifest(blocks: [
            .greeting(GreetingBlock(title: "Good evening, Avid")),
            .myClub(MyClubBlock(
                name: "Virgin Active Sea Point",
                addressLine: "96 Beach Rd, Sea Point, Cape Town, 8005",
                openingHoursToday: "05:00 – 22:00",
                phoneNumber: "+27 21 439 1240"
            ))
        ])
    }

    @Test func remembersTheHomeClubFromTheManifest() async {
        home.results = [.success(manifestWithClub)]

        await makeViewModel().load()

        #expect(venueStore.venue == Fixtures.venue)
    }

    @Test func keepsTheKnownVenueWhenAManifestHasNoClubBlock() async {
        home.results = [.success(manifestWithClub), .success(manifest)]
        let viewModel = makeViewModel()

        await viewModel.load()
        await viewModel.load()

        #expect(venueStore.venue == Fixtures.venue)
    }

    @Test func detailsGetTheSessionVenue() async {
        home.results = [.success(manifestWithClub)]
        let viewModel = makeViewModel()
        await viewModel.load()

        #expect(viewModel.makeDetailsViewModelFor(Fixtures.classInstance()).venue == Fixtures.venue)
    }
}
