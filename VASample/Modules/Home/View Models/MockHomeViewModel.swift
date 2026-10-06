//
//  MockHomeViewModel.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Combine

@MainActor final class MockHomeViewModel: HomeViewModelProtocol {
    @Published private(set) var blocks: [HomeBlock] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var openingClassId: String?
    @Published var selectedClass: ClassInstance?
    @Published var error: UIError?
    private let mockError: UIError?
    
    init(mockError: UIError?) {
        self.mockError = mockError
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        if let mockError {
            self.error = mockError
        } else {
            blocks = Self.allBlocks
        }
    }

    func openClass(clubId: String, classId: String) async {
        selectedClass = MockClassesViewModel.allClasses
            .flatMap(\.classes)
            .first { $0.classId == classId } ?? MockClassesDetailsViewModel.available
    }

    func makeDetailsViewModelFor(_ classInstance: ClassInstance) -> MockClassesDetailsViewModel {
        MockClassesDetailsViewModel(classInstance: classInstance, mockError: mockError)
    }
    
    func logout() async {
        blocks = []
    }
}

extension MockHomeViewModel {
    static let allBlocks: [HomeBlock] = [
        .greeting(GreetingBlock(title: "Good evening, Avid")),
        .hero(HeroBlock(
            title: "Crush your goals this week",
            subtitle: "You've attended 3 classes — 1 more to hit your weekly target."
        )),
        .myClub(MyClubBlock(
            name: "Virgin Active Sea Point",
            addressLine: "96 Beach Rd, Sea Point, Cape Town, 8005",
            openingHoursToday: "05:00 – 22:00",
            phoneNumber: "+27 21 439 1240"
        )),
        .classCarousel(ClassCarouselBlock(
            title: "Your week",
            viewAllAction: .openTimetable(clubId: "club_sea_point"),
            items: [
                ClassCarouselItem(
                    id: "sp-power-spin::2026-10-05",
                    title: "Power Spin",
                    subtitle: "Thabo Ndlovu",
                    imageRef: "spin",
                    badge: "Booked",
                    startsAt: VenueDate(date: .now.addingTimeInterval(60 * 60)),
                    actionLabel: "View",
                    actionRef: .openClass(clubId: "club_sea_point", classId: "sp-power-spin::2026-10-05")
                ),
                ClassCarouselItem(
                    id: "sp-hiit-lab::2026-10-05",
                    title: "HIIT Lab",
                    subtitle: "Sipho Dlamini",
                    imageRef: "hiit",
                    badge: "Waitlisted",
                    startsAt: VenueDate(date: .now.addingTimeInterval(5 * 60 * 60)),
                    actionLabel: "View",
                    actionRef: .openClass(clubId: "club_sea_point", classId: "sp-hiit-lab::2026-10-05")
                ),
                ClassCarouselItem(
                    id: "sp-aqua-lanes::2026-10-06",
                    title: "Aqua Lanes",
                    subtitle: "Naledi Botha",
                    imageRef: "swimming",
                    badge: nil,
                    startsAt: VenueDate(date: .now.addingTimeInterval(24 * 60 * 60)),
                    actionLabel: "View",
                    actionRef: .openClass(clubId: "club_sea_point", classId: "sp-aqua-lanes::2026-10-06")
                )
            ]
        )),
        .myRewards(CardListBlock(
            title: "Your rewards",
            items: [
                CardItem(
                    id: "reward_001",
                    title: "Free smoothie at the juice bar",
                    subtitle: "Show this at any Virgin Active café",
                    imageRef: "reward_smoothie",
                    badge: "Expires Sunday"
                ),
                CardItem(
                    id: "reward_002",
                    title: "20% off retail at any club",
                    subtitle: "Valid on apparel and accessories",
                    imageRef: "reward_retail",
                    badge: nil
                )
            ]
        )),
        .myGoals(CardListBlock(
            title: "Your goals",
            items: [
                CardItem(
                    id: "goal_001",
                    title: "Attend 4 classes per week",
                    subtitle: "3 of 4 this week",
                    imageRef: "goal_classes",
                    badge: nil
                ),
                CardItem(
                    id: "goal_get_started",
                    title: "Set your first goal",
                    subtitle: nil,
                    imageRef: nil,
                    badge: nil
                )
            ]
        )),
        .promotion(PromotionBlock(
            title: "Summer Shape-Up Challenge",
            subtitle: "Join 12 classes in 4 weeks and earn bonus rewards. Starts 1 June.",
            imageRef: "promo_summer_challenge"
        ))
    ]
}
