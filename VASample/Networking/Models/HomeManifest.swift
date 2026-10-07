//
//  HomeManifest.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated enum HomeBlockType: String, Decodable, Sendable, CaseIterable {
    case greeting
    case hero
    case myClub
    case classCarousel
    case myRewards
    case myGoals
    case promotion
}

nonisolated struct HomeManifest: Decodable, Sendable {
    let blocks: [HomeBlock]

    private enum CodingKeys: String, CodingKey {
        case blocks
    }

    init(blocks: [HomeBlock]) {
        self.blocks = blocks
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        blocks = try container.decode([Lossy<HomeBlock>].self, forKey: .blocks).compactMap(\.value)
    }
}

nonisolated enum HomeBlock: Decodable, Sendable, Equatable, Hashable {
    case greeting(GreetingBlock)
    case hero(HeroBlock)
    case myClub(MyClubBlock)
    case classCarousel(ClassCarouselBlock)
    case myRewards(CardListBlock)
    case myGoals(CardListBlock)
    case promotion(PromotionBlock)

    private enum CodingKeys: String, CodingKey {
        case type
    }

    init(from decoder: Decoder) throws {
        let type = try decoder.container(keyedBy: CodingKeys.self).decode(HomeBlockType.self, forKey: .type)
        switch type {
        case .greeting: self = .greeting(try GreetingBlock(from: decoder))
        case .hero: self = .hero(try HeroBlock(from: decoder))
        case .myClub: self = .myClub(try MyClubBlock(from: decoder))
        case .classCarousel: self = .classCarousel(try ClassCarouselBlock(from: decoder))
        case .myRewards: self = .myRewards(try CardListBlock(from: decoder))
        case .myGoals: self = .myGoals(try CardListBlock(from: decoder))
        case .promotion: self = .promotion(try PromotionBlock(from: decoder))
        }
    }

    var type: HomeBlockType {
        switch self {
        case .greeting: .greeting
        case .hero: .hero
        case .myClub: .myClub
        case .classCarousel: .classCarousel
        case .myRewards: .myRewards
        case .myGoals: .myGoals
        case .promotion: .promotion
        }
    }
}

nonisolated struct GreetingBlock: Decodable, Sendable, Equatable, Hashable {
    let title: String
}

nonisolated struct HeroBlock: Decodable, Sendable, Equatable, Hashable {
    let title: String
    let subtitle: String?
}

nonisolated struct MyClubBlock: Decodable, Sendable, Equatable, Hashable {
    let name: String
    let addressLine: String?
    let openingHoursToday: String?
    let phoneNumber: String?
}

nonisolated struct ClassCarouselBlock: Decodable, Sendable, Equatable, Hashable {
    let title: String
    let viewAllAction: HomeAction?
    let items: [ClassCarouselItem]
}

nonisolated struct ClassCarouselItem: Decodable, Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let imageRef: String?
    let badge: String?
    let startsAt: VenueDate
    let actionLabel: String?
    let actionRef: HomeAction?
}

nonisolated struct CardListBlock: Decodable, Sendable, Equatable, Hashable {
    let title: String?
    let items: [CardItem]
}

nonisolated struct CardItem: Decodable, Sendable, Equatable, Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String?
    let imageRef: String?
    let badge: String?
}

nonisolated struct PromotionBlock: Decodable, Sendable, Equatable, Hashable {
    let title: String
    let subtitle: String?
    let imageRef: String?
}

nonisolated enum HomeAction: Decodable, Sendable, Equatable, Hashable {
    case openTimetable(clubId: String)
    case openClass(clubId: String, classId: String)
    case unsupported(String)

    private enum CodingKeys: String, CodingKey {
        case type, clubId, classId
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "openTimetable":
            self = .openTimetable(clubId: try container.decode(String.self, forKey: .clubId))
        case "openClass":
            self = .openClass(
                clubId: try container.decode(String.self, forKey: .clubId),
                classId: try container.decode(String.self, forKey: .classId)
            )
        default:
            self = .unsupported(type)
        }
    }
}
