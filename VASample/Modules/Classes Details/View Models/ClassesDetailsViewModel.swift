//
//  ClassesDetailsViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//


import Foundation
import Combine

protocol ClassesDetailsViewModelProtocol: ObservableObject {
    var classInstance: ClassInstance { get }
    var venue: Venue? { get }
    var bookingResponse: BookingResponse? { get }
    var justBooked: Bool { get }
    var isProcessing: Bool { get }
    var canBook: Bool { get }
    var canCancel: Bool { get }
    var canSetReminder: Bool { get }
    var hasReminder: Bool { get }
    var calendarEvent: CalendarEventDraft? { get set }
    var error: UIError? { get set }

    func book() async
    func cancelBooking() async
    func setReminder() async
    func removeReminder() async
    func loadReminderState() async
    func addToCalendar()
    func finishAddingToCalendar()
}

extension ClassesDetailsViewModelProtocol {
    var isFull: Bool {
        classInstance.status == .full || classInstance.available == 0
    }

    var hasStarted: Bool {
        classInstance.startsAt.date <= .now
    }

    var isWithinCancellationWindow: Bool {
        let remaining = classInstance.startsAt.date.timeIntervalSinceNow
        return remaining > 0 && remaining < 12 * 60 * 60
    }

    var reminderDate: Date {
        classInstance.startsAt.date.addingTimeInterval(-30 * 60)
    }

    var reminderId: String {
        "class-\(classInstance.classId)"
    }

    var canAddToCalendar: Bool {
        classInstance.status != .cancelled && !hasStarted
    }

    var calendarEventDraft: CalendarEventDraft {
        CalendarEventDraft(
            id: classInstance.classId,
            title: classInstance.title,
            start: classInstance.startsAt.date,
            end: classInstance.endsAt.date,
            timeZone: TimeZone(identifier: classInstance.timezone) ?? classInstance.startsAt.timeZone,
            location: venue.map { [$0.name, $0.address].compactMap { $0 }.joined(separator: ", ") },
            notes: ["Trainer: \(classInstance.trainer)", venue?.phoneNumber.map { "Club phone: \($0)" }]
                .compactMap { $0 }
                .joined(separator: "\n")
        )
    }
}

final class ClassesDetailsViewModel: ClassesDetailsViewModelProtocol {
    @Published private(set) var classInstance: ClassInstance
    @Published private(set) var bookingResponse: BookingResponse?
    @Published private(set) var justBooked: Bool = false
    @Published private(set) var isProcessing: Bool = false
    @Published private(set) var hasReminder: Bool = false
    @Published var calendarEvent: CalendarEventDraft?
    @Published var error: UIError?
    let venue: Venue?
    private let store: TimetableStoreProtocol
    private let reminders: ReminderSchedulerProtocol
    private let onUpdate: (ClassInstance) -> Void
    
    init(
        classInstance: ClassInstance,
        store: TimetableStoreProtocol,
        venue: Venue? = nil,
        reminders: ReminderSchedulerProtocol = ReminderScheduler(),
        onUpdate: @escaping (ClassInstance) -> Void = { _ in }
    ) {
        self.classInstance = classInstance
        self.store = store
        self.venue = venue
        self.reminders = reminders
        self.onUpdate = onUpdate
    }

    var canBook: Bool {
        classInstance.userBookingStatus == .none
            && classInstance.status != .cancelled
            && !hasStarted
            && !isProcessing
    }

    var canCancel: Bool {
        classInstance.userBookingStatus.holdsPlace && !hasStarted && !isProcessing
    }

    var canSetReminder: Bool {
        classInstance.userBookingStatus.holdsPlace && !hasReminder && reminderDate > .now && !isProcessing
    }

    func book() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let result = try await store.book(classInstance)
            self.bookingResponse = result.response
            justBooked = true
            update(result.classInstance)
        } catch {
            self.error = UIError(error)
        }
    }

    func cancelBooking() async {
        isProcessing = true
        defer { isProcessing = false }
        do {
            let updated = try await store.cancelBooking(classInstance)
            reminders.cancel(id: reminderId)
            hasReminder = false
            self.bookingResponse = nil
            justBooked = false
            update(updated)
        } catch {
            self.error = UIError(error)
        }
    }
    
    func setReminder() async {
        do {
            guard try await reminders.requestAuthorization() else {
                error = .client(
                    message: "Turn on notifications for VASample in Settings to get class reminders.",
                    title: "Notifications are off"
                )
                return
            }
            try await reminders.schedule(
                id: reminderId,
                title: classInstance.title,
                body: "Starts at \(classInstance.startsAt.time) with \(classInstance.trainer)",
                at: reminderDate
            )
            hasReminder = true
        } catch {
            self.error = .client(message: error.localizedDescription, title: "Unable to add reminder")
        }
    }
    
    func removeReminder() async {
        reminders.cancel(id: reminderId)
        hasReminder = false
    }
    
    func loadReminderState() async {
        hasReminder = await reminders.isScheduled(id: reminderId)
    }

    func addToCalendar() {
        guard canAddToCalendar else { return }
        calendarEvent = calendarEventDraft
    }

    func finishAddingToCalendar() {
        calendarEvent = nil
    }

    private func update(_ updated: ClassInstance) {
        classInstance = updated
        onUpdate(updated)
    }
}
