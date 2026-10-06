//
//  ClassesViewModelTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@MainActor
struct ClassesViewModelTests {
    private let store = FakeTimetableStore()
    private let profile = FakeProfileAPI()
    private let spin = Fixtures.classInstance()
    private let venueStore = VenueStore()

    private func makeViewModel() -> ClassesViewModel {
        ClassesViewModel(store: store, venueStore: venueStore, profileService: profile)
    }

    @Test func detailsGetTheSessionVenueWhenKnown() {
        let viewModel = makeViewModel()
        #expect(viewModel.makeDetailsViewModelFor(spin).venue == nil)

        venueStore.update(Fixtures.venue)

        #expect(viewModel.makeDetailsViewModelFor(spin).venue == Fixtures.venue)
    }

    @Test func alwaysForceRefreshesTheHomeClubsWeek() async {
        store.timetableResult = .success(Fixtures.timetable(classes: [spin]))
        let viewModel = makeViewModel()

        await viewModel.loadClasses()

        #expect(store.timetableCalls.first?.clubId == "club_sea_point")
        #expect(store.timetableCalls.first?.forceRefresh == true)
        #expect(viewModel.days.count == 2)
        #expect(viewModel.selectedDate == "2026-10-07")
        #expect(viewModel.selectedClasses == [spin])
        #expect(!viewModel.isLoading)
    }

    @Test func resolvesTheClubOnlyOnce() async {
        store.timetableResult = .success(Fixtures.timetable(classes: [spin]))
        let viewModel = makeViewModel()

        await viewModel.loadClasses()
        await viewModel.loadClasses()

        #expect(profile.calls == 1)
        #expect(store.timetableCalls.count == 2)
    }

    @Test func keepsTheUsersSelectedDayAcrossReloads() async {
        store.timetableResult = .success(Fixtures.timetable(classes: [spin]))
        let viewModel = makeViewModel()
        await viewModel.loadClasses()

        viewModel.selectedDate = "2026-10-06"
        await viewModel.loadClasses()

        #expect(viewModel.selectedDate == "2026-10-06")
    }

    @Test func profileFailureSurfacesAnError() async {
        profile.result = .failure(Fixtures.serverError(500, "ChaosFailure"))
        let viewModel = makeViewModel()

        await viewModel.loadClasses()

        #expect(store.timetableCalls.isEmpty)
        guard case .server(_, .some) = viewModel.error else {
            Issue.record("Expected retryable error")
            return
        }
    }

    @Test func bookingFromDetailsUpdatesTheList() async {
        store.timetableResult = .success(Fixtures.timetable(classes: [spin]))
        let booked = Fixtures.classInstance(available: 9, userBookingStatus: .booked)
        store.bookResult = .success(BookingResult(classInstance: booked, response: Fixtures.booking(booked)))
        let viewModel = makeViewModel()
        await viewModel.loadClasses()

        let details = viewModel.makeDetailsViewModelFor(spin)
        await details.book()

        #expect(viewModel.selectedClasses.first?.userBookingStatus == .booked)
        #expect(viewModel.selectedClasses.first?.available == 9)
    }
}
