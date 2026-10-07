//
//  ClassesDetailsView.swift
//  VASample
//
//  Created by Josue M Cizungu on 2026/10/05.
//

import SwiftUI

struct ClassesDetailsView<ViewModel: ClassesDetailsViewModelProtocol>: View {
    private enum Confirmation {
        case book, cancel, removeReminder
    }

    @StateObject private var viewModel: ViewModel
    @State private var confirmation: Confirmation?
    
    init(viewModel: @autoclosure @escaping () -> ViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel())
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.background.ignoresSafeArea()
            
            ScrollView(.vertical) {
                Text(viewModel.classInstance.type == .unknown ? "CLASS" : viewModel.classInstance.type.rawValue.uppercased())
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.deepRed)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom)
                
                Text(viewModel.classInstance.title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 4)
                Text("with \(viewModel.classInstance.trainer)")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(Color.black.opacity(0.5))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("Date")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text(viewModel.classInstance.startsAt.fullDate)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                    }
                    .padding(.bottom)
                    HStack(spacing: 0) {
                        Text("Time")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text("\(viewModel.classInstance.startsAt.time) - \(viewModel.classInstance.endsAt.time)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                    }
                    .padding(.bottom)
                    HStack(spacing: 0) {
                        Text("Availability")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.gray)
                        Spacer()
                        Text(viewModel.classInstance.status != .cancelled ? "\(viewModel.classInstance.available) of \(viewModel.classInstance.spots) spots" : "Cancelled")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                    }
                }
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.15))
                }
                .padding(.bottom)
                
                switch viewModel.classInstance.userBookingStatus {
                case .booked:
                    statusBanner(
                        title: viewModel.justBooked ? "Booking confirmed!" : "You are booked for this class",
                        detail: viewModel.bookingResponse.map { "Booking ID: \($0.bookingId)" },
                        foreground: Color.successText,
                        background: Color.green.opacity(0.2)
                    )
                case .waitlisted:
                    statusBanner(
                        title: viewModel.justBooked ? "You've joined the waitlist" : "You are on the waitlist",
                        detail: viewModel.bookingResponse?.waitlistPosition.map { "Your position: \($0)" }
                            ?? "You'll get a spot if one opens up",
                        foreground: Color.orange,
                        background: Color.orange.opacity(0.15)
                    )
                case .none, .unknown:
                    EmptyView()
                }

                if viewModel.classInstance.userBookingStatus == .booked && viewModel.isWithinCancellationWindow {
                    Text("This class starts within 12 hours. Cancelling may forfeit any associated cost.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(Color.infoText)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.infoText.opacity(0.7))
                                .overlay(alignment: .trailing) {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.info)
                                        .padding(.leading, 4)
                                }
                        }
                        .padding(.bottom)
                }
                
                    
                if viewModel.hasReminder {
                    Text("Reminder set for 30 minutes before the class")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.successText)
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical)
                        .background {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.green.opacity(0.2))
                        }
                        .padding(.bottom)
                        .clipped()
                        .onTapGesture {
                            confirmation = .removeReminder
                        }
                }

                if viewModel.canSetReminder {
                    Button(action: {
                        Task {
                            await viewModel.setReminder()
                        }
                    }, label: {
                        Text("Set Reminder")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .clipped()
                        
                    })
                    .overlay {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.black.opacity(0.8))
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.gray.opacity(0.15))
                            .stroke(Color.black.opacity(0.2), lineWidth: 1)
                    }
                    .padding(.bottom)
                }
                
                if viewModel.canBook {
                    Button(action: {
                        confirmation = .book
                    }, label: {
                        Text(viewModel.isFull ? "Join Waitlist" : "Book")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.green.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .clipped()
                        
                    })
                    .overlay {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.black.opacity(0.8))
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.clear)
                    }
                    .padding(.bottom)
                }
                
                if viewModel.canCancel {
                    Button(action: {
                        confirmation = .cancel
                    }, label: {
                        Text(viewModel.classInstance.userBookingStatus == .waitlisted ? "Leave Waitlist" : "Cancel Booking")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.red)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .clipped()
                        
                    })
                    .overlay {
                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(Color.black.opacity(0.8))
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.clear)
                    }
                    .padding(.bottom)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .alert(
                confirmation.map(title(for:)) ?? "",
                isPresented: Binding(
                    get: { confirmation != nil },
                    set: { if !$0 { confirmation = nil } }
                ),
                presenting: confirmation
            ) { confirmation in
                switch confirmation {
                case .book:
                    Button(viewModel.isFull ? "Join Waitlist" : "Book") {
                        Task { await viewModel.book() }
                    }
                case .cancel:
                    Button(title(for: .cancel), role: .destructive) {
                        Task { await viewModel.cancelBooking() }
                    }
                case .removeReminder:
                    Button("Cancel Reminder") {
                        Task { await viewModel.removeReminder() }
                    }
                }
                Button("Not Now", role: .cancel) {}
            } message: { confirmation in
                Text(message(for: confirmation))
            }
            
            Button(action: {
                viewModel.addToCalendar()
            }, label: {
                Image(systemName: "calendar.badge.plus")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .padding(12)
                    .offset(x: 3, y: 1)
            })
            .background {
                Circle()
                    .fill(Color.info)
                    .stroke(Color.deepRed.opacity(0.2), lineWidth: 1)
            }
            .padding(.trailing, 32)
            .padding(.bottom)
            .disabled(!viewModel.canAddToCalendar)
        }
        .tint(Color.red.opacity(0.9))
        .navigationTitle("Class Details")
        .errorAlert($viewModel.error)
        .sheet(item: $viewModel.calendarEvent) { draft in
            AddToCalendarView(draft: draft) { _ in
                viewModel.finishAddingToCalendar()
            }
            .ignoresSafeArea()
        }
        .task {
            await viewModel.loadReminderState()
        }
    }

    private func statusBanner(title: String, detail: String?, foreground: Color, background: Color) -> some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(foreground)
            if let detail {
                Text(detail)
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(foreground)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(background)
        }
        .padding(.bottom)
    }

    private func title(for confirmation: Confirmation) -> String {
        switch confirmation {
        case .book:
            viewModel.isFull ? "Join the waitlist?" : "Confirm booking"
        case .cancel:
            viewModel.classInstance.userBookingStatus == .waitlisted ? "Leave waitlist?" : "Cancel booking?"
        case .removeReminder:
            "Cancel reminder?"
        }
    }

    private func message(for confirmation: Confirmation) -> String {
        let classInstance = viewModel.classInstance
        let summary = "\(classInstance.title) with \(classInstance.trainer)\n\(classInstance.startsAt.fullDate) at \(classInstance.startsAt.time)"
        switch confirmation {
        case .book:
            let availability = viewModel.isFull
                ? "This class is full. You will join the waitlist at position \(classInstance.waitlistCount + 1)."
                : "\(classInstance.available) of \(classInstance.spots) spots left."
            return "\(summary)\n\n\(availability)"
        case .cancel:
            guard classInstance.userBookingStatus == .booked, viewModel.isWithinCancellationWindow else {
                return summary
            }
            return "\(summary)\n\nThis class starts within 12 hours. Cancelling may forfeit any cost associated with the booking."
        case .removeReminder:
            return "This will cancel the reminder."
        }
    }
}

#Preview("Available") {
    ClassesDetailsView(viewModel: MockClassesDetailsViewModel(classInstance: MockClassesDetailsViewModel.available))
}

#Preview("Booked") {
    ClassesDetailsView(viewModel: MockClassesDetailsViewModel(classInstance: MockClassesDetailsViewModel.booked))
}

#Preview("Waitlisted") {
    ClassesDetailsView(viewModel: MockClassesDetailsViewModel(classInstance: MockClassesDetailsViewModel.waitlisted))
}

#Preview("Full") {
    ClassesDetailsView(viewModel: MockClassesDetailsViewModel(classInstance: MockClassesDetailsViewModel.full))
}

#Preview("Cancelled") {
    ClassesDetailsView(viewModel: MockClassesDetailsViewModel(classInstance: MockClassesDetailsViewModel.cancelled))
}

#Preview("Booking error") {
    ClassesDetailsView(
        viewModel: MockClassesDetailsViewModel(
            classInstance: MockClassesDetailsViewModel.available,
            mockError: .userInput(message: "You are already booked into this class.")
        )
    )
}
