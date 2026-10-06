//
//  APIServices.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation

nonisolated struct APIServices: Sendable {
    let auth: AuthAPIProtocol
    let profile: ProfileAPIProtocol
    let classes: ClassesAPIProtocol
    let home: HomeAPIProtocol
    let timetableStore: TimetableStoreProtocol
    let venueStore: VenueStoreProtocol
    let sessionExpirations: AsyncStream<Void>

    static func live(tokenStore: TokenStore = TokenStore(storage: KeychainTokenStorage())) -> APIServices {
        let client = APIClient(tokenStore: tokenStore)
        let classes = ClassesAPI(client: client)
        return APIServices(
            auth: AuthAPI(client: client, tokenStore: tokenStore),
            profile: ProfileAPI(client: client),
            classes: classes,
            home: HomeAPI(client: client),
            timetableStore: TimetableStore(service: classes),
            venueStore: VenueStore(),
            sessionExpirations: tokenStore.sessionExpirations
        )
    }
}
