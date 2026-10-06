//
//  AppRouterTests.swift
//  VASampleTests
//
//  Created by Josue M Cizungu on 2026/10/06.
//

import Foundation
import Testing
@testable import VASample

@MainActor
struct AppRouterTests {
    @Test func startsOnTheLaunchScreenWhileTheSessionIsChecked() {
        #expect(AppRouter().route == .launch)
    }

    @Test func signInLandsOnHome() {
        let router = AppRouter()
        router.selectedTab = .classes

        router.signIn()

        #expect(router.route == .tabBar)
        #expect(router.selectedTab == .home)
    }

    @Test func expiredSessionReturnsToSignInWithAFlag() {
        let router = AppRouter()
        router.signIn()

        router.signOut(sessionExpired: true)

        #expect(router.route == .auth)
        #expect(router.sessionExpired)
    }

    @Test func manualSignOutDoesNotFlagExpiry() {
        let router = AppRouter()
        router.signIn()
        router.signOut()
        #expect(!router.sessionExpired)
    }
}
