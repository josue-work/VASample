//
//  UserProfile.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated struct UserProfile: Decodable, Sendable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let membershipTier: MembershipTier
    let homeClub: ClubSummary
}

nonisolated enum MembershipTier: String, Sendable, UnknownCaseDecodable {
    case essential, premium, club, unknown
}

nonisolated struct ClubSummary: Decodable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
}
