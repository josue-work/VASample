//
//  ClassesDetailsViewModelTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@MainActor
struct ClassesDetailsViewModelTests {
    private let store = FakeTimetableStore()
    private let reminders = FakeReminderScheduler()

    private func makeViewModel(_ classInstance: ClassInstance, onUpdate: @escaping (ClassInstance) -> Void = { _ in }) -> ClassesDetailsViewModel {
        ClassesDetailsViewModel(classInstance: classInstance, store: store, reminders: reminders, onUpdate: onUpdate)
    }

    // MARK: - Booking rules

    @Test func upcomingClassCanBeBooked() {
        let viewModel = makeViewModel(Fixtures.classInstance())
        #expect(viewModel.canBook)
        #expect(!viewModel.canCancel)
        #expect(!viewModel.isFull)
    }

    @Test func fullClassOffersTheWaitlist() {
        let viewModel = makeViewModel(Fixtures.classInstance(available: 0, status: .full))
        #expect(viewModel.canBook)
        #expect(viewModel.isFull)
    }

    @Test func startedOrCancelledClassesCannotBeBooked() {
        #expect(!makeViewModel(Fixtures.classInstance(startsIn: -60)).canBook)
        #expect(!makeViewModel(Fixtures.classInstance(status: .cancelled)).canBook)
    }

    @Test func bookedOrWaitlistedClassesCanBeCancelledUntilTheyStart() {
        #expect(makeViewModel(Fixtures.classInstance(userBookingStatus: .booked)).canCancel)
        #expect(makeViewModel(Fixtures.classInstance(userBookingStatus: .waitlisted)).canCancel)
        #expect(!makeViewModel(Fixtures.classInstance(startsIn: -60, userBookingStatus: .booked)).canCancel)
    }

    private static let cancellationWindowCases: [(startsIn: TimeInterval, expected: Bool)] = [
        (7_200, true),
        (42_840, true),
        (43_560, false),
        (172_800, false),
        (-60, false)
    ]

    @Test(arguments: cancellationWindowCases)
    func cancellationWarningWindow(startsIn: TimeInterval, expected: Bool) {
        let viewModel = makeViewModel(Fixtures.classInstance(startsIn: startsIn, userBookingStatus: .booked))
        #expect(viewModel.isWithinCancellationWindow == expected)
    }

    // MARK: - Booking

    @Test func bookingConfirmsAndNotifiesTheParent() async {
        let booked = Fixtures.classInstance(available: 9, userBookingStatus: .booked)
        store.bookResult = .success(BookingResult(classInstance: booked, response: Fixtures.booking(booked)))
        var updates: [ClassInstance] = []
        let viewModel = makeViewModel(Fixtures.classInstance()) { updates.append($0) }

        await viewModel.book()

        #expect(viewModel.justBooked)
        #expect(viewModel.bookingResponse?.bookingId == "booking_1")
        #expect(viewModel.classInstance == booked)
        #expect(updates == [booked])
        #expect(!viewModel.isProcessing)
        #expect(!viewModel.canBook)
    }

    @Test func joiningTheWaitlistKeepsThePosition() async {
        let waitlisted = Fixtures.classInstance(available: 0, waitlistCount: 4, status: .full, userBookingStatus: .waitlisted)
        store.bookResult = .success(BookingResult(classInstance: waitlisted, response: Fixtures.booking(waitlisted, status: .waitlisted, waitlistPosition: 4)))
        let viewModel = makeViewModel(Fixtures.classInstance(available: 0, waitlistCount: 3, status: .full))

        await viewModel.book()

        #expect(viewModel.classInstance.userBookingStatus == .waitlisted)
        #expect(viewModel.bookingResponse?.waitlistPosition == 4)
    }

    @Test func bookingRecoveredOnRetryStillConfirms() async {
        let booked = Fixtures.classInstance(userBookingStatus: .booked)
        store.bookResult = .success(BookingResult(classInstance: booked, response: nil))
        let viewModel = makeViewModel(Fixtures.classInstance())

        await viewModel.book()

        #expect(viewModel.justBooked)
        #expect(viewModel.bookingResponse == nil)
        #expect(viewModel.classInstance.userBookingStatus == .booked)
    }

    @Test func bookingFailureShowsTheServerMessage() async {
        store.bookResult = .failure(Fixtures.serverError(422, "ClassInPast", message: "This class has already started."))
        let viewModel = makeViewModel(Fixtures.classInstance())

        await viewModel.book()

        #expect(!viewModel.justBooked)
        guard case .userInput(let message) = viewModel.error else {
            Issue.record("Expected userInput error")
            return
        }
        #expect(message == "This class has already started.")
    }

    @Test func bookingFailureNeverOffersRetry() async {
        store.bookResult = .failure(Fixtures.serverError(500, "ChaosFailure"))
        let viewModel = makeViewModel(Fixtures.classInstance())

        await viewModel.book()

        guard case .server(_, nil) = viewModel.error else {
            Issue.record("Booking errors must not offer a blind retry")
            return
        }
    }

    // MARK: - Cancelling

    @Test func cancellingClearsBookingStateAndReminder() async {
        let original = Fixtures.classInstance(userBookingStatus: .booked)
        let cancelled = Fixtures.classInstance(available: 11)
        store.bookResult = .success(BookingResult(classInstance: original, response: Fixtures.booking(original)))
        store.cancelResult = .success(cancelled)
        reminders.scheduledIds = ["class-\(original.classId)"]
        let viewModel = makeViewModel(Fixtures.classInstance())
        await viewModel.book()
        await viewModel.loadReminderState()
        #expect(viewModel.hasReminder)

        await viewModel.cancelBooking()

        #expect(viewModel.classInstance == cancelled)
        #expect(!viewModel.justBooked)
        #expect(viewModel.bookingResponse == nil)
        #expect(!viewModel.hasReminder)
        #expect(reminders.cancelledIds == ["class-\(original.classId)"])
    }

    @Test func cancelFailureKeepsTheBooking() async {
        let booked = Fixtures.classInstance(userBookingStatus: .booked)
        store.cancelResult = .failure(Fixtures.serverError(500, "ChaosFailure"))
        let viewModel = makeViewModel(booked)

        await viewModel.cancelBooking()

        #expect(viewModel.classInstance.userBookingStatus == .booked)
        #expect(reminders.cancelledIds.isEmpty)
        #expect(viewModel.error != nil)
    }

    // MARK: - Reminders

    @Test func reminderIsOnlyOfferedForUpcomingBookings() {
        #expect(!makeViewModel(Fixtures.classInstance()).canSetReminder)
        #expect(makeViewModel(Fixtures.classInstance(userBookingStatus: .booked)).canSetReminder)
        #expect(makeViewModel(Fixtures.classInstance(userBookingStatus: .waitlisted)).canSetReminder)
        #expect(!makeViewModel(Fixtures.classInstance(startsIn: 10 * 60, userBookingStatus: .booked)).canSetReminder)
    }

    @Test func settingAReminderSchedulesThirtyMinutesBefore() async throws {
        let booked = Fixtures.classInstance(userBookingStatus: .booked)
        let viewModel = makeViewModel(booked)

        await viewModel.setReminder()

        let reminder = try #require(reminders.scheduled.first)
        #expect(reminder.id == "class-\(booked.classId)")
        #expect(reminder.title == booked.title)
        #expect(reminder.date == booked.startsAt.date.addingTimeInterval(-30 * 60))
        #expect(viewModel.hasReminder)
        #expect(!viewModel.canSetReminder)
    }

    @Test func deniedNotificationsExplainHowToFixIt() async {
        reminders.authorized = false
        let viewModel = makeViewModel(Fixtures.classInstance(userBookingStatus: .booked))

        await viewModel.setReminder()

        #expect(reminders.scheduled.isEmpty)
        #expect(!viewModel.hasReminder)
        guard case .client(_, let title) = viewModel.error else {
            Issue.record("Expected client error")
            return
        }
        #expect(title == "Notifications are off")
    }

    @Test func removingAReminderWorksEvenWithNotificationsOff() async {
        let booked = Fixtures.classInstance(userBookingStatus: .booked)
        reminders.scheduledIds = ["class-\(booked.classId)"]
        reminders.authorized = false
        let viewModel = makeViewModel(booked)
        await viewModel.loadReminderState()

        await viewModel.removeReminder()

        #expect(!viewModel.hasReminder)
        #expect(reminders.cancelledIds == ["class-\(booked.classId)"])
        #expect(viewModel.error == nil)
    }

    @Test func reminderStateIsRestoredFromTheScheduler() async {
        let booked = Fixtures.classInstance(userBookingStatus: .booked)
        reminders.scheduledIds = ["class-\(booked.classId)"]
        let viewModel = makeViewModel(booked)

        await viewModel.loadReminderState()

        #expect(viewModel.hasReminder)
    }

    // MARK: - Calendar

    @Test func addToCalendarPrefillsTheEditorFromTheClass() throws {
        let spin = Fixtures.classInstance()
        let viewModel = makeViewModel(spin)

        viewModel.addToCalendar()

        let draft = try #require(viewModel.calendarEvent)
        #expect(draft.title == spin.title)
        #expect(draft.start == spin.startsAt.date)
        #expect(draft.end == spin.endsAt.date)
        #expect(draft.timeZone.identifier == "Africa/Johannesburg")
        #expect(draft.notes == "Trainer: \(spin.trainer)")
        #expect(draft.location == nil)
    }

    @Test func calendarEventUsesTheVenueAddressAndPhone() throws {
        let spin = Fixtures.classInstance()
        let viewModel = ClassesDetailsViewModel(classInstance: spin, store: store, venue: Fixtures.venue, reminders: reminders)

        viewModel.addToCalendar()

        let draft = try #require(viewModel.calendarEvent)
        #expect(draft.location == "Virgin Active Sea Point, 96 Beach Rd, Sea Point, Cape Town, 8005")
        #expect(draft.notes == "Trainer: \(spin.trainer)\nClub phone: +27 21 439 1240")
    }

    @Test func calendarEventHandlesAPartialVenue() throws {
        let venue = Venue(name: "Virgin Active Aldersgate", address: nil, phoneNumber: nil)
        let viewModel = ClassesDetailsViewModel(classInstance: Fixtures.classInstance(), store: store, venue: venue, reminders: reminders)

        viewModel.addToCalendar()

        let draft = try #require(viewModel.calendarEvent)
        #expect(draft.location == "Virgin Active Aldersgate")
        #expect(draft.notes == "Trainer: Thabo Ndlovu")
    }

    @Test func finishingTheEditorDismissesIt() {
        let viewModel = makeViewModel(Fixtures.classInstance())
        viewModel.addToCalendar()

        viewModel.finishAddingToCalendar()

        #expect(viewModel.calendarEvent == nil)
    }

    @Test func pastOrCancelledClassesCannotBeAddedToTheCalendar() {
        let started = makeViewModel(Fixtures.classInstance(startsIn: -60))
        let cancelled = makeViewModel(Fixtures.classInstance(status: .cancelled))

        started.addToCalendar()
        cancelled.addToCalendar()

        #expect(!started.canAddToCalendar)
        #expect(started.calendarEvent == nil)
        #expect(cancelled.calendarEvent == nil)
    }

    @Test func calendarDoesNotRequireABooking() {
        #expect(makeViewModel(Fixtures.classInstance()).canAddToCalendar)
    }
}
