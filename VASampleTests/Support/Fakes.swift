//
//  Fakes.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
@testable import VASample

final class FakeAuthAPI: AuthAPIProtocol, @unchecked Sendable {
    var loginResult: Result<UserProfile, Error> = .success(Fixtures.profile)
    private(set) var loginCalls: [(username: String, password: String)] = []
    private(set) var logoutCalls = 0

    func login(username: String, password: String) async throws -> UserProfile {
        loginCalls.append((username, password))
        return try loginResult.get()
    }

    func logout() async {
        logoutCalls += 1
    }

    func restoreSession() async -> Bool {
        false
    }
}

final class FakeProfileAPI: ProfileAPIProtocol, @unchecked Sendable {
    var result: Result<UserProfile, Error> = .success(Fixtures.profile)
    private(set) var calls = 0

    func me() async throws -> UserProfile {
        calls += 1
        return try result.get()
    }
}

final class FakeHomeAPI: HomeAPIProtocol, @unchecked Sendable {
    var results: [Result<HomeManifest, Error>] = []
    private(set) var calls = 0

    func manifest() async throws -> HomeManifest {
        calls += 1
        return try results.removeFirst().get()
    }
}

final class FakeClassesAPI: ClassesAPIProtocol, @unchecked Sendable {
    var timetableResults: [Result<TimetableResponse, Error>] = []
    var bookResults: [Result<BookingResponse, Error>] = []
    var cancelResults: [Result<Void, Error>] = []
    var timetableDelay: Duration?
    private(set) var timetableCalls = 0
    private(set) var bookCalls = 0
    private(set) var cancelCalls = 0

    func timetable(clubId: String, date: String?) async throws -> TimetableResponse {
        timetableCalls += 1
        let result = timetableResults.count > 1 ? timetableResults.removeFirst() : timetableResults[0]
        if let timetableDelay {
            try await Task.sleep(for: timetableDelay)
        }
        return try result.get()
    }

    func book(clubId: String, classId: String) async throws -> BookingResponse {
        bookCalls += 1
        return try bookResults.removeFirst().get()
    }

    func cancelBooking(clubId: String, classId: String) async throws {
        cancelCalls += 1
        try cancelResults.removeFirst().get()
    }
}

final class FakeTimetableStore: TimetableStoreProtocol, @unchecked Sendable {
    var timetableResult: Result<TimetableResponse, Error> = .success(Fixtures.timetable(classes: []))
    var classInstanceResult: Result<ClassInstance?, Error> = .success(nil)
    var bookResult: Result<BookingResult, Error>?
    var cancelResult: Result<ClassInstance, Error>?
    var classInstanceDelay: Duration?
    private(set) var timetableCalls: [(clubId: String, forceRefresh: Bool)] = []
    private(set) var classInstanceCalls = 0
    private(set) var invalidateCalls = 0

    func timetable(clubId: String, forceRefresh: Bool) async throws -> TimetableResponse {
        timetableCalls.append((clubId, forceRefresh))
        return try timetableResult.get()
    }

    func classInstance(clubId: String, classId: String) async throws -> ClassInstance? {
        classInstanceCalls += 1
        if let classInstanceDelay {
            try await Task.sleep(for: classInstanceDelay)
        }
        return try classInstanceResult.get()
    }

    func book(_ classInstance: ClassInstance) async throws -> BookingResult {
        try bookResult!.get()
    }

    func cancelBooking(_ classInstance: ClassInstance) async throws -> ClassInstance {
        try cancelResult!.get()
    }

    func invalidate() async {
        invalidateCalls += 1
    }
}

final class FakeReminderScheduler: ReminderSchedulerProtocol, @unchecked Sendable {
    var authorized = true
    var scheduledIds: Set<String> = []
    private(set) var scheduled: [(id: String, title: String, body: String, date: Date)] = []
    private(set) var cancelledIds: [String] = []

    func requestAuthorization() async throws -> Bool {
        authorized
    }

    func isScheduled(id: String) async -> Bool {
        scheduledIds.contains(id)
    }

    func schedule(id: String, title: String, body: String, at date: Date) async throws {
        scheduled.append((id, title, body, date))
        scheduledIds.insert(id)
    }

    func cancel(id: String) {
        cancelledIds.append(id)
        scheduledIds.remove(id)
    }
}
