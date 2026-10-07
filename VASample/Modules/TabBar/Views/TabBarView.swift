//
//  TabBarView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI

struct TabBarView: View {
    @EnvironmentObject private var router: AppRouter
    private let services: APIServices

    init(services: APIServices) {
        self.services = services
    }

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house", value: .home) {
                NavigationStack {
                    HomeView(viewModel: HomeViewModel(
                        service: services.home,
                        store: services.timetableStore,
                        venueStore: services.venueStore,
                        authService: services.auth
                    ))
                }
            }
            Tab("Classes", systemImage: "calendar.day", value: .classes) {
                NavigationStack {
                    ClassesView(
                        viewModel: ClassesViewModel(
                            store: services.timetableStore,
                            venueStore: services.venueStore,
                            profileService: services.profile
                        )
                    )
                }
            }
        }
        .tint(Color.red.opacity(0.9))
    }
}

#Preview {
    TabBarView(services: APIServices.live())
        .environmentObject(AppRouter())
}
