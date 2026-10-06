//
//  ClassesViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//


import Foundation
import Combine

protocol ClassesViewModelProtocol: ObservableObject {
    associatedtype DetailsViewModel: ClassesDetailsViewModelProtocol

    var days: [TimetableDay] { get }
    var selectedDate: String? { get set }
    var selectedClasses: [ClassInstance] { get }
    var isLoading: Bool { get }
    var error: UIError? { get set }

    func loadClasses() async
    func makeDetailsViewModelFor(_ classInstance: ClassInstance) -> DetailsViewModel
}

final class ClassesViewModel: ClassesViewModelProtocol {
    
    @Published private(set) var days: [TimetableDay] = []
    @Published var selectedDate: String?
    @Published private(set) var isLoading: Bool = false
    @Published var error: UIError?
    private var clubId: String?
    private let store: TimetableStoreProtocol
    private let venueStore: VenueStoreProtocol
    private let profileService: ProfileAPIProtocol

    init(
        store: TimetableStoreProtocol,
        venueStore: VenueStoreProtocol,
        profileService: ProfileAPIProtocol
    ) {
        self.store = store
        self.venueStore = venueStore
        self.profileService = profileService
    }

    var selectedClasses: [ClassInstance] {
        days.first { $0.date == selectedDate }?.classes ?? []
    }

    func loadClasses() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let timetable = try await store.timetable(clubId: try await resolveClubId(), forceRefresh: true)
            days = timetable.days
            if !days.contains(where: { $0.date == selectedDate }) {
                selectedDate = timetable.selectedDate
            }
        } catch {
            self.error = UIError(error) { [weak self] in
                Task { await self?.loadClasses() }
            }
        }
    }

    func makeDetailsViewModelFor(_ classInstance: ClassInstance) -> ClassesDetailsViewModel {
        ClassesDetailsViewModel(classInstance: classInstance, store: store, venue: venueStore.venue) { [weak self] updated in
            self?.replace(updated)
        }
    }
    
    private func resolveClubId() async throws -> String {
        if let clubId { return clubId }
        let id = try await profileService.me().homeClub.id
        clubId = id
        return id
    }

    private func replace(_ updated: ClassInstance) {
        days = days.map { day in
            TimetableDay(
                date: day.date,
                classes: day.classes.map { $0.classId == updated.classId ? updated : $0 }
            )
        }
    }
}
