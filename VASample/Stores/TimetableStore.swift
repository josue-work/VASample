//
//  TimetableStore.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation

nonisolated struct BookingResult: Sendable {
    let classInstance: ClassInstance
    let response: BookingResponse?
}

nonisolated protocol TimetableStoreProtocol: Sendable {
    func timetable(clubId: String, forceRefresh: Bool) async throws -> TimetableResponse
    func classInstance(clubId: String, classId: String) async throws -> ClassInstance?
    func book(_ classInstance: ClassInstance) async throws -> BookingResult
    func cancelBooking(_ classInstance: ClassInstance) async throws -> ClassInstance
    func invalidate() async
}

actor TimetableStore: TimetableStoreProtocol {
    private let service: ClassesAPIProtocol
    private let maxRetries: Int
    private var timetables: [String: TimetableResponse] = [:]
    private var inFlight: [String: Task<TimetableResponse, Error>] = [:]
    private var generation = 0

    init(service: ClassesAPIProtocol, maxRetries: Int = 2) {
        self.service = service
        self.maxRetries = maxRetries
    }

    func timetable(clubId: String, forceRefresh: Bool) async throws -> TimetableResponse {
        if !forceRefresh, let cached = timetables[clubId] {
            return cached
        }
        let generation = self.generation
        let task = inFlight[clubId] ?? fetch(clubId: clubId)
        defer {
            if inFlight[clubId] == task { inFlight[clubId] = nil }
        }

        let timetable = try await task.value
        // Invalidated while in flight: the result belongs to the previous session, so don't cache it.
        guard generation == self.generation else { throw CancellationError() }
        timetables[clubId] = timetable
        return timetable
    }

    private func fetch(clubId: String) -> Task<TimetableResponse, Error> {
        let task = Task { [service] in
            try await service.timetable(clubId: clubId, date: nil)
        }
        inFlight[clubId] = task
        return task
    }

    func classInstance(clubId: String, classId: String) async throws -> ClassInstance? {
        if let cached = timetables[clubId]?.classInstance(withId: classId) {
            return cached
        }
        return try await timetable(clubId: clubId, forceRefresh: true).classInstance(withId: classId)
    }

    func book(_ classInstance: ClassInstance) async throws -> BookingResult {
        var attempt = 0
        while true {
            do {
                let response = try await service.book(clubId: classInstance.clubId, classId: classInstance.classId)
                apply(response.classInstance)
                return BookingResult(classInstance: response.classInstance, response: response)
            } catch let error as APIError where attempt > 0
                        && (error.hasServerCode("AlreadyBooked") || error.hasServerCode("AlreadyWaitlisted")) {
                let current = try await timetable(clubId: classInstance.clubId, forceRefresh: true)
                    .classInstance(withId: classInstance.classId) ?? classInstance
                return BookingResult(classInstance: current, response: nil)
            } catch let error as APIError where error.isTransient && attempt < maxRetries {
                attempt += 1
                try await Task.sleep(for: backoff(attempt))
            }
        }
    }

    func cancelBooking(_ classInstance: ClassInstance) async throws -> ClassInstance {
        var attempt = 0
        while true {
            do {
                try await service.cancelBooking(clubId: classInstance.clubId, classId: classInstance.classId)
                break
            } catch let error as APIError where attempt > 0 && error.hasServerCode("BookingNotFound") {
                break
            } catch let error as APIError where error.isTransient && attempt < maxRetries {
                attempt += 1
                try await Task.sleep(for: backoff(attempt))
            }
        }

        if let refreshed = try? await timetable(clubId: classInstance.clubId, forceRefresh: true)
            .classInstance(withId: classInstance.classId) {
            return refreshed
        }

        let cancelled = classInstance.cancellingUserBooking()
        apply(cancelled)
        return cancelled
    }

    func invalidate() {
        generation += 1
        inFlight.values.forEach { $0.cancel() }
        inFlight.removeAll()
        timetables.removeAll()
    }

    private func backoff(_ attempt: Int) -> Duration {
        .milliseconds(300 * (1 << (attempt - 1)))
    }

    private func apply(_ updated: ClassInstance) {
        guard let cached = timetables[updated.clubId] else { return }
        timetables[updated.clubId] = TimetableResponse(
            clubId: cached.clubId,
            weekStart: cached.weekStart,
            weekEnd: cached.weekEnd,
            selectedDate: cached.selectedDate,
            days: cached.days.map { day in
                TimetableDay(
                    date: day.date,
                    classes: day.classes.map { $0.classId == updated.classId ? updated : $0 }
                )
            }
        )
    }
}

nonisolated extension TimetableResponse {
    func classInstance(withId classId: String) -> ClassInstance? {
        days.lazy.flatMap(\.classes).first { $0.classId == classId }
    }
}

nonisolated private extension ClassInstance {
    func cancellingUserBooking() -> ClassInstance {
        let wasBooked = userBookingStatus == .booked
        return ClassInstance(
            classId: classId,
            clubId: clubId,
            title: title,
            trainer: trainer,
            type: type,
            startsAt: startsAt,
            endsAt: endsAt,
            timezone: timezone,
            spots: spots,
            available: wasBooked ? available + 1 : available,
            waitlistCount: wasBooked ? waitlistCount : max(waitlistCount - 1, 0),
            status: wasBooked && status == .full ? .available : status,
            userBookingStatus: .none
        )
    }
}
