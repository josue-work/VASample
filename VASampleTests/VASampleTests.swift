//
//  VASampleTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Testing
@testable import VASample

struct VASampleTests {
    @Test func liveServicesShareOneTokenStore() async {
        let tokenStore = TokenStore()
        let services = APIServices.live(tokenStore: tokenStore)
        await services.auth.logout()
        #expect(await tokenStore.accessToken == nil)
    }
}
