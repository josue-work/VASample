//
//  VASampleApp.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI

@main
struct VASampleApp: App {
    @StateObject private var router = AppRouter()
    private let services = APIServices.live()
    var body: some Scene {
        WindowGroup {
            Group {
                switch router.route {
                case .launch:
                    ZStack {
                        Color.background.ignoresSafeArea()
                        ProgressView()
                            .progressViewStyle(.circular)
                    }
                case .auth:
                    SignInView(viewModel: SignInViewModel(service: services.auth))
                case .tabBar:
                    TabBarView(services: services)
                }
            }
            .environmentObject(router)
            .task {
                if await services.auth.restoreSession() {
                    router.signIn()
                } else {
                    router.signOut()
                }
                for await _ in services.sessionExpirations {
                    await services.timetableStore.invalidate()
                    services.venueStore.clear()
                    router.signOut(sessionExpired: true)
                }
            }
        }
    }
}
