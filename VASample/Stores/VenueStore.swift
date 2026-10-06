//
//  VenueStore.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation

nonisolated struct Venue: Sendable, Equatable {
    let name: String
    let address: String?
    let phoneNumber: String?

    init(name: String, address: String?, phoneNumber: String?) {
        self.name = name
        self.address = address
        self.phoneNumber = phoneNumber
    }

    init(_ block: MyClubBlock) {
        self.init(name: block.name, address: block.addressLine, phoneNumber: block.phoneNumber)
    }
}

@MainActor protocol VenueStoreProtocol: AnyObject, Sendable {
    var venue: Venue? { get }

    func update(_ venue: Venue)
    func clear()
}

@MainActor final class VenueStore: VenueStoreProtocol {
    private(set) var venue: Venue?

    nonisolated init() {}

    func update(_ venue: Venue) {
        self.venue = venue
    }

    func clear() {
        venue = nil
    }
}
