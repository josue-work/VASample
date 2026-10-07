//
//  ClassesView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI

struct ClassesView<ViewModel: ClassesViewModelProtocol>: View {
    private struct StatusChip {
        let text: String
        let foreground: Color
        let background: Color
    }

    @StateObject private var viewModel: ViewModel
    
    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack {
            Color.background.ignoresSafeArea()
            List {
                ForEach(viewModel.days, id: \.id) { day in
                    if day.classes.count > 0 { // Don't show days with no classes
                        Section(DayFormatter.header(for: day.date)) {
                            ForEach(day.classes, id: \.id) { myClass in
                                NavigationLink(value: ClassesRoutes.details(classInstance: myClass)) {
                                    createCell(myClass)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.grouped)
            .listSectionSpacing(0)
            
            if viewModel.isLoading {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task {
            await viewModel.loadClasses()
        }
        .tint(Color.red.opacity(0.9))
        .errorAlert($viewModel.error)
        .navigationDestination(for: ClassesRoutes.self) { route in
            switch route {
            case .details(let classInstance):
                ClassesDetailsView(
                    viewModel: viewModel.makeDetailsViewModelFor(classInstance)
                )
            }
        }
    }
    
    @ViewBuilder private func createCell(_ myClass: ClassInstance) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(myClass.startsAt.time)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))
                Text(myClass.endsAt.time)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.gray)
            }
            .padding(.trailing)
            VStack(alignment: .leading) {
                Text(myClass.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(myClass.trainer)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(Color.gray)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer()
            let chip = statusChip(for: myClass)
            Text(chip.text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(chip.foreground)
                .padding(7)
                .background {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(chip.background)
                }
        }
        .opacity(isInactive(myClass) ? 0.5 : 1)
        .padding(.horizontal, 16) // keep the content inset visually
        .padding(.vertical, 8)
        .listRowInsets(EdgeInsets()) // let the row span the full width
        .alignmentGuide(.listRowSeparatorLeading) { _ in 0 } // divider starts at the left edge
        .alignmentGuide(.listRowSeparatorTrailing) { d in d.width }
    }
    
    private func isInactive(_ myClass: ClassInstance) -> Bool {
        myClass.status == .cancelled || myClass.startsAt.date <= .now
    }

    private func statusChip(for myClass: ClassInstance) -> StatusChip {
        if myClass.status == .cancelled {
            return StatusChip(text: "Cancelled", foreground: .white, background: .gray)
        }
        switch myClass.userBookingStatus {
        case .booked:
            return StatusChip(text: "Booked", foreground: .white, background: .green)
        case .waitlisted:
            return StatusChip(text: "Waitlisted", foreground: .white, background: .orange)
        case .none, .unknown:
            break
        }
        if myClass.endsAt.date <= .now {
            return StatusChip(text: "Finished", foreground: .gray, background: .clear)
        }
        if myClass.startsAt.date <= .now {
            return StatusChip(text: "In progress", foreground: .gray, background: .clear)
        }
        if myClass.status == .full || myClass.available == 0 {
            return StatusChip(text: "Full · Waitlist", foreground: .white, background: Color.deepRed)
        }
        return StatusChip(text: "\(myClass.available) of \(myClass.spots) left", foreground: .gray, background: .clear)
    }
}

#Preview {
    NavigationStack {
        ClassesView(viewModel: MockClassesViewModel(mockError: nil))
    }
}

#Preview("Error") {
    ClassesView(viewModel: MockClassesViewModel(mockError: .server(message: nil, retryable: {})))
}
