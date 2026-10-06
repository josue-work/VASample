//
//  HomeViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//


import Foundation
import Combine

@MainActor protocol HomeViewModelProtocol: ObservableObject {
    associatedtype DetailsViewModel: ClassesDetailsViewModelProtocol

    var blocks: [HomeBlock] { get }
    var isLoading: Bool { get }
    var openingClassId: String? { get }
    var selectedClass: ClassInstance? { get set }
    var error: UIError? { get set }

    func load() async
    func openClass(clubId: String, classId: String) async
    func makeDetailsViewModelFor(_ classInstance: ClassInstance) -> DetailsViewModel
    func logout() async
}

@MainActor final class HomeViewModel: HomeViewModelProtocol {
    @Published private(set) var blocks: [HomeBlock] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var openingClassId: String?
    @Published var selectedClass: ClassInstance?
    @Published var error: UIError?
    private let service: HomeAPIProtocol
    private let store: TimetableStoreProtocol
    private let venueStore: VenueStoreProtocol
    private let authService: AuthAPIProtocol

    init(
        service: HomeAPIProtocol,
        store: TimetableStoreProtocol,
        venueStore: VenueStoreProtocol,
        authService: AuthAPIProtocol
    ) {
        self.service = service
        self.store = store
        self.venueStore = venueStore
        self.authService = authService
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            blocks = try await service.manifest().blocks
            for case .myClub(let club) in blocks {
                venueStore.update(Venue(club))
                break
            }
#if DEBUG
            debugPrint("Home: Data loaded successfully")
#endif
        } catch {
            self.error = UIError(error) { [weak self] in
                Task { await self?.load() }
            }
        }
    }

    func openClass(clubId: String, classId: String) async {
        guard openingClassId == nil else { return }
        openingClassId = classId
        defer { openingClassId = nil }
        do {
            guard let classInstance = try await store.classInstance(clubId: clubId, classId: classId) else {
                error = .client(message: "This class is no longer on the timetable.", title: "Class unavailable")
                return
            }
            selectedClass = classInstance
        } catch {
            self.error = UIError(error) { [weak self] in
                Task { await self?.openClass(clubId: clubId, classId: classId) }
            }
        }
    }

    func makeDetailsViewModelFor(_ classInstance: ClassInstance) -> ClassesDetailsViewModel {
        ClassesDetailsViewModel(classInstance: classInstance, store: store, venue: venueStore.venue)
    }
    
    func logout() async {
        await authService.logout()
        await store.invalidate()
        venueStore.clear()
        blocks = []
    }
}
