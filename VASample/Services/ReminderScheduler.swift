//
//  ReminderScheduler.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import UserNotifications

nonisolated protocol ReminderSchedulerProtocol: Sendable {
    func requestAuthorization() async throws -> Bool
    func isScheduled(id: String) async -> Bool
    func schedule(id: String, title: String, body: String, at date: Date) async throws
    func cancel(id: String)
}

nonisolated struct ReminderScheduler: ReminderSchedulerProtocol {
    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
    }

    func isScheduled(id: String) async -> Bool {
        await UNUserNotificationCenter.current()
            .pendingNotificationRequests()
            .contains { $0.identifier == id }
    }

    func schedule(id: String, title: String, body: String, at date: Date) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(date.timeIntervalSinceNow, 1), repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func cancel(id: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
