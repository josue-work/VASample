//
//  AddToCalendarView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import EventKit
import EventKitUI
import SwiftUI

struct CalendarEventDraft: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let timeZone: TimeZone
    let location: String?
    let notes: String?
}

struct AddToCalendarView: UIViewControllerRepresentable {
    let draft: CalendarEventDraft
    let onComplete: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIViewController(context: Context) -> EKEventEditViewController {
        let eventStore = EKEventStore()
        let event = EKEvent(eventStore: eventStore)
        event.title = draft.title
        event.startDate = draft.start
        event.endDate = draft.end
        event.timeZone = draft.timeZone
        event.location = draft.location
        event.notes = draft.notes
        event.addAlarm(EKAlarm(relativeOffset: -30 * 60))

        let controller = EKEventEditViewController()
        controller.eventStore = eventStore
        controller.event = event
        controller.editViewDelegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: EKEventEditViewController, context: Context) {
        context.coordinator.onComplete = onComplete
    }

    final class Coordinator: NSObject, EKEventEditViewDelegate {
        var onComplete: (Bool) -> Void

        init(onComplete: @escaping (Bool) -> Void) {
            self.onComplete = onComplete
        }

        func eventEditViewController(_ controller: EKEventEditViewController, didCompleteWith action: EKEventEditViewAction) {
            onComplete(action == .saved)
        }
    }
}
