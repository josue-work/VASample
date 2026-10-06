//
//  HomeBlockView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import SwiftUI

enum ImageResolver {
    static func name(for ref: String?, fallback: String = "placeholderImage") -> String {
        guard let refKey = ref?.trimmingCharacters(in: .whitespaces).lowercased(),
              !refKey.isEmpty,
              UIImage(named: refKey) != nil else {
                  return fallback
              }
        return refKey
    }
}

struct HomeBlockView: View {
    let block: HomeBlock
    var openingClassId: String? = nil
    var onAction: (HomeAction) -> Void = { _ in }

    var body: some View {
        switch block.type {
        case .greeting:      GreetingBlockView(block: block)
        case .hero:          HeroBlockView(block: block)
        case .myClub:        MyClubBlockView(block: block)
        case .classCarousel: ClassCarouselBlockView(block: block, openingClassId: openingClassId, onAction: onAction)
        case .myRewards, .myGoals:     CardListBlockView(block: block)
        case .promotion:     PromotionBlockView(block: block)
        }
    }
}

struct GreetingBlockView: View {
    let block: HomeBlock
    
    var body: some View {
        switch block {
        case .greeting(let greetingBlock):
            Text("\(greetingBlock.title)")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.9))
                .padding(.vertical, 12)
        default:
            EmptyView()
        }
    }
}

struct HeroBlockView: View {
    let block: HomeBlock
    
    var body: some View {
        switch block {
        case .hero(let heroBlock):
            VStack(alignment: .leading, spacing: 0) {
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    topTrailingRadius: 8
                )
                .fill(Color.red)
                .frame(height: 40)
                VStack(alignment: .leading, spacing: 0) {
                    Text(heroBlock.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.bottom, heroBlock.subtitle != nil ? 8 : 16)
                        .padding(.top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle = heroBlock.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white)
                            .padding(.bottom)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                }
                .padding(.horizontal)
                .background {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8
                    )
                    .fill(Color.deepRed)
                }
            }
        default:
            EmptyView()
        }
    }
}

struct MyClubBlockView: View {
    let block: HomeBlock
    
    var body: some View {
        switch block {
        case .myClub(let myClubBlock):
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Home Club")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        Text(myClubBlock.name)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(Color.black.opacity(0.9))
                        if let addressLine = myClubBlock.addressLine {
                            Text(addressLine)
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.gray.opacity(0.9))
                        }
                        if let openingHoursToday = myClubBlock.openingHoursToday {
                            Text(openingHoursToday)
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.gray.opacity(0.9))
                        }
                        if let phoneNumber = myClubBlock.phoneNumber {
                            Text(phoneNumber)
                                .font(.system(size: 14, weight: .light))
                                .foregroundStyle(Color.gray.opacity(0.9))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                    .padding(.horizontal)
                }
                .clipped()
                .padding(.vertical)
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                }
            }
        default:
            EmptyView()
        }
    }
}

struct ClassCarouselBlockView: View {
    let block: HomeBlock
    var openingClassId: String? = nil
    var onAction: (HomeAction) -> Void = { _ in }
    
    var body: some View {
        switch block {
        case .classCarousel(let classCarouselBlock):
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 0) {
                    Text(classCarouselBlock.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.9))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let viewAllAction = classCarouselBlock.viewAllAction {
                        Button("View all") {
                            onAction(viewAllAction)
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                }
                .padding(.bottom, 8)
                ScrollView(.horizontal){
                    LazyHStack(alignment: .center, spacing: 0) {
                        ForEach(classCarouselBlock.items) { item in
                            Button {
                                if let actionRef = item.actionRef {
                                    onAction(actionRef)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 0) {
                                    Group {
                                        Text(item.startsAt.dayAndTime)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.red)
                                            .lineLimit(2, reservesSpace: true)
                                            .frame(maxWidth: .infinity)
                                            .padding(.top)
                                        Text(item.title)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(Color.black.opacity(0.9))
                                            .lineLimit(2, reservesSpace: false)
                                            .frame(maxWidth: .infinity)
                                        if let subtitle = item.subtitle {
                                            Text(subtitle)
                                                .font(.system(size: 13, weight: .light))
                                                .foregroundStyle(Color.gray.opacity(0.9))
                                                .lineLimit(2, reservesSpace: false)
                                                .frame(maxWidth: .infinity)
                                        }
                                    }
                                    .padding(.bottom, 8)
                                    .padding(.horizontal, 8)
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.15))
                                }
                                .overlay {
                                    if openingClassId == item.id {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                    }
                                }
                                .padding(.trailing)
                                .frame(width: 130)
                                .clipped()
                            }
                            .buttonStyle(.plain)
                            .disabled(item.actionRef == nil || openingClassId != nil)
                        }
                    }
                }
            }
            .frame(maxHeight: 150)
        default:
            EmptyView()
        }
    }
}

struct CardListBlockView: View {
    let block: HomeBlock
    
    var body: some View {
        switch block {
        case .myRewards(let cardListBlock), .myGoals(let cardListBlock):
            VStack(alignment: .leading, spacing: 0) {
                Text(cardListBlock.title ?? (block.type == .myGoals ? "Your goals" : "Your rewards"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ScrollView(.horizontal){
                    LazyHStack(alignment: .center, spacing: 0) {
                        ForEach(cardListBlock.items) { item in
                            VStack(alignment: .center, spacing: 0) {
                                Group {
                                    Image(ImageResolver.name(for: item.imageRef))
                                        .resizable()
                                        .frame(width: 130, height: 80)
                                        .padding(.horizontal, 4)
                                        .padding(.top, 4)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    Text(item.title)
                                        .lineLimit(2, reservesSpace: true)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Color.black.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                        
                                    Text(item.subtitle ?? "")
                                        .lineLimit(2, reservesSpace: true)
                                        .font(.system(size: 12, weight: .light))
                                        .foregroundStyle(Color.gray.opacity(0.9))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(width: 130)
                                .padding(.bottom, 8)
                                .padding(.horizontal, 8)
                            }
                            .background {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.15))
                            }
                            .padding(.trailing)
                        }
                    }
                }
            }
            .frame(maxHeight: 200)
        default:
            EmptyView()
        }
    }
}

struct PromotionBlockView: View {
    let block: HomeBlock
    
    var body: some View {
        switch block {
        case .promotion(let promotionBlock):
            VStack(alignment: .leading, spacing: 0) {
                Text("Your Promotions")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(alignment: .center, spacing: 0) {
                    Image(ImageResolver.name(for: promotionBlock.imageRef))
                        .resizable()
                        .frame(width: 130, height: 80)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .frame(maxWidth: .infinity)
                    .background {
                        UnevenRoundedRectangle(
                            topLeadingRadius: 8,
                            topTrailingRadius: 8
                        )
                        .fill(Color.red)
                    }
                VStack(alignment: .leading, spacing: 0) {
                    Text(promotionBlock.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Color.white)
                        .padding(.bottom, promotionBlock.subtitle != nil ? 8 : 16)
                        .padding(.top)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle = promotionBlock.subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white)
                            .padding(.bottom)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                }
                .padding(.horizontal)
                .background {
                    UnevenRoundedRectangle(
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8
                    )
                    .fill(Color.deepRed)
                }
            }
        default:
            EmptyView()
        }
    }
}

#Preview {
    HomeBlockView(block: .classCarousel(ClassCarouselBlock(
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
    )))
}
