//
//  HomeView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI
import Combine

struct HomeView<ViewModel: HomeViewModelProtocol>: View {
    @EnvironmentObject private var router: AppRouter
    @StateObject private var viewModel: ViewModel

    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(viewModel.blocks.enumerated()), id: \.offset) { _, block in
                        HomeBlockView(
                            block: block,
                            openingClassId: viewModel.openingClassId,
                            onAction: handle
                        )
                        .padding(.bottom)
                    }
                }
                .padding(.horizontal)
                
                if !viewModel.isLoading {
                    Button(action: {
                        Task {
                            await viewModel.logout()
                            router.signOut()
                        }
                    }, label: {
                        Text("Logout")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                            .clipped()
                        
                    })
                    .overlay {
                        if viewModel.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.black.opacity(0.8))
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.red.opacity(0.9))
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                    .padding(.bottom, 24)
                }
            }
            
            if viewModel.isLoading {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task {
            await viewModel.load()
        }
        .tint(Color.red.opacity(0.9))
        .errorAlert($viewModel.error)
        .navigationDestination(item: $viewModel.selectedClass) { classInstance in
            ClassesDetailsView(
                viewModel: viewModel.makeDetailsViewModelFor(classInstance)
            )
        }
    }

    private func handle(_ action: HomeAction) {
        switch action {
        case .openClass(let clubId, let classId):
            Task {
                await viewModel.openClass(clubId: clubId, classId: classId)
            }
        case .openTimetable:
            router.selectedTab = .classes
        case .unsupported:
            break
        }
    }
}

#Preview {
    NavigationStack {
        HomeView(viewModel: MockHomeViewModel(mockError: nil))
    }
    .environmentObject(AppRouter())
}
