//
//  TimetableStoreTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@MainActor
struct VenueStoreTests {
    @Test func holdsTheVenueUntilCleared() {
        let store = VenueStore()
        #expect(store.venue == nil)

        store.update(Fixtures.venue)
        #expect(store.venue == Fixtures.venue)

        store.clear()
        #expect(store.venue == nil)
    }
}

struct TimetableStoreTests {
    private let spin = Fixtures.classInstance()
    private let yoga = Fixtures.classInstance(id: "sp-yoga::2026-10-07")

    private func makeStore(_ api: FakeClassesAPI) -> TimetableStore {
        TimetableStore(service: api)
    }

    @Test func servesCachedWeekUntilForcedToRefresh() async throws {
        let api = FakeClassesAPI()
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin]))]
        let store = makeStore(api)

        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: false)
        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: false)
        #expect(api.timetableCalls == 1)

        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: true)
        #expect(api.timetableCalls == 2)
    }

    @Test func concurrentRequestsShareOneFetch() async throws {
        let api = FakeClassesAPI()
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin]))]
        api.timetableDelay = .milliseconds(100)
        let store = makeStore(api)

        async let home = store.timetable(clubId: "club_sea_point", forceRefresh: true)
        async let classes = store.timetable(clubId: "club_sea_point", forceRefresh: true)
        _ = try await (home, classes)

        #expect(api.timetableCalls == 1)
    }

    @Test func classLookupsAreServedFromTheCachedWeek() async throws {
        let api = FakeClassesAPI()
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin, yoga]))]
        let store = makeStore(api)

        #expect(try await store.classInstance(clubId: "club_sea_point", classId: spin.classId) == spin)
        #expect(try await store.classInstance(clubId: "club_sea_point", classId: yoga.classId) == yoga)
        #expect(api.timetableCalls == 1)
    }

    @Test func missingClassTriggersARefetchThenReturnsNil() async throws {
        let api = FakeClassesAPI()
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin]))]
        let store = makeStore(api)

        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: false)
        #expect(try await store.classInstance(clubId: "club_sea_point", classId: "gone::2026-10-07") == nil)
        #expect(api.timetableCalls == 2)
    }

    @Test func bookingUpdatesTheCache() async throws {
        let api = FakeClassesAPI()
        let booked = Fixtures.classInstance(available: 9, userBookingStatus: .booked)
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin]))]
        api.bookResults = [.success(Fixtures.booking(booked))]
        let store = makeStore(api)
        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: false)

        let result = try await store.book(spin)

        #expect(result.response?.bookingId == "booking_1")
        #expect(try await store.classInstance(clubId: "club_sea_point", classId: spin.classId)?.userBookingStatus == .booked)
        #expect(api.timetableCalls == 1)
    }

    @Test func bookingRetriesChaosFailures() async throws {
        let api = FakeClassesAPI()
        api.bookResults = [.failure(Fixtures.serverError(500, "ChaosFailure")), .success(Fixtures.booking(spin))]

        let result = try await makeStore(api).book(spin)

        #expect(api.bookCalls == 2)
        #expect(result.response != nil)
    }

    @Test(arguments: ["AlreadyBooked", "AlreadyWaitlisted"])
    func conflictOnRetryMeansTheFirstAttemptLanded(code: String) async throws {
        let api = FakeClassesAPI()
        let booked = Fixtures.classInstance(userBookingStatus: .booked)
        api.timetableResults = [.success(Fixtures.timetable(classes: [booked]))]
        api.bookResults = [.failure(Fixtures.serverError(500, "ChaosFailure")), .failure(Fixtures.serverError(409, code))]

        let result = try await makeStore(api).book(spin)

        #expect(result.response == nil)
        #expect(result.classInstance.userBookingStatus == .booked)
        #expect(api.timetableCalls == 1)
    }

    @Test func conflictOnFirstAttemptIsARealError() async {
        let api = FakeClassesAPI()
        api.bookResults = [.failure(Fixtures.serverError(409, "AlreadyBooked"))]
        await #expect(throws: APIError.self) { try await makeStore(api).book(spin) }
        #expect(api.bookCalls == 1)
    }

    @Test func bookingGivesUpAfterMaxRetries() async {
        let api = FakeClassesAPI()
        api.bookResults = Array(repeating: .failure(Fixtures.serverError(500, "ChaosFailure")), count: 3)
        await #expect(throws: APIError.self) { try await makeStore(api).book(spin) }
        #expect(api.bookCalls == 3)
    }

    @Test func clientErrorsAreNotRetried() async {
        let api = FakeClassesAPI()
        api.bookResults = [.failure(Fixtures.serverError(422, "ClassInPast"))]
        await #expect(throws: APIError.self) { try await makeStore(api).book(spin) }
        #expect(api.bookCalls == 1)
    }

    @Test func cancelReturnsTheServersView() async throws {
        let api = FakeClassesAPI()
        let fromServer = Fixtures.classInstance(available: 11)
        api.cancelResults = [.success(())]
        api.timetableResults = [.success(Fixtures.timetable(classes: [fromServer]))]

        let result = try await makeStore(api).cancelBooking(Fixtures.classInstance(userBookingStatus: .booked))
        #expect(result == fromServer)
    }

    @Test func notFoundOnRetryMeansTheCancelLanded() async throws {
        let api = FakeClassesAPI()
        api.cancelResults = [.failure(Fixtures.serverError(500, "ChaosFailure")), .failure(Fixtures.serverError(404, "BookingNotFound"))]
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin]))]

        _ = try await makeStore(api).cancelBooking(Fixtures.classInstance(userBookingStatus: .booked))
        #expect(api.cancelCalls == 2)
    }

    @Test func cancelFallsBackLocallyWhenTheRefetchFails() async throws {
        let api = FakeClassesAPI()
        api.cancelResults = [.success(())]
        api.timetableResults = [.failure(Fixtures.serverError(404, "ClubNotFound"))]
        let booked = Fixtures.classInstance(available: 0, status: .full, userBookingStatus: .booked)

        let result = try await makeStore(api).cancelBooking(booked)

        #expect(result.userBookingStatus == UserBookingStatus.none)
        #expect(result.available == 1)
        #expect(result.status == .available)
    }

    @Test func leavingTheWaitlistShrinksIt() async throws {
        let api = FakeClassesAPI()
        api.cancelResults = [.success(())]
        api.timetableResults = [.failure(Fixtures.serverError(404, "ClubNotFound"))]
        let waitlisted = Fixtures.classInstance(available: 0, waitlistCount: 3, status: .full, userBookingStatus: .waitlisted)

        let result = try await makeStore(api).cancelBooking(waitlisted)

        #expect(result.waitlistCount == 2)
        #expect(result.available == 0)
        #expect(result.status == .full)
    }

    @Test func invalidateDropsTheCache() async throws {
        let api = FakeClassesAPI()
        api.timetableResults = [.success(Fixtures.timetable(classes: [spin]))]
        let store = makeStore(api)

        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: false)
        await store.invalidate()
        _ = try await store.timetable(clubId: "club_sea_point", forceRefresh: false)

        #expect(api.timetableCalls == 2)
    }
}
