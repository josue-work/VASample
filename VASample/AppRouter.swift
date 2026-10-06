//
//  AppRouter.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import Foundation
import Combine
import SwiftUI

enum AppRoute: Hashable {
    case launch
    case auth
    case tabBar
}

enum TabBarRoutes: Hashable {
    case home
    case classes
}

enum ClassesRoutes: Hashable {
    case details(classInstance: ClassInstance)
}

@MainActor
final class AppRouter: ObservableObject {
    @Published private(set) var route: AppRoute = .launch
    @Published var selectedTab: TabBarRoutes = .home
    @Published var sessionExpired: Bool = false

    func signIn() {
        selectedTab = .home
        route = .tabBar
    }

    func signOut(sessionExpired: Bool = false) {
        self.sessionExpired = sessionExpired
        route = .auth
    }
}
