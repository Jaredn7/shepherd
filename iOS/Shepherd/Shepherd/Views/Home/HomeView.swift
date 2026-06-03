//
//  HomeView.swift
//  Shepherd
//

import SwiftUI
import CoreData

struct HomeView: View {
    var showElderTools: Bool = false
    var onElderTools: (() -> Void)? = nil

    @Environment(\.managedObjectContext) private var context
    @State private var displayName = ""
    @State private var showLogoutConfirmation = false
    @State private var logoutErrorMessage: String?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12: return "Good Morning"
        case 12..<17: return "Good Afternoon"
        default: return "Good Evening"
        }
    }

    var body: some View {
        ShepherdNavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    greetingHeader.slideUpEntrance(delay: 0.05)
                    upNextSection.slideUpEntrance(delay: 0.12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 120)
            }
            .background { LiquidMeshBackground() }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 10) {
                        if showElderTools, let onElderTools {
                            glassToolbarButton(icon: "person.badge.key.fill", action: onElderTools)
                        }
                        glassToolbarButton(icon: "bell.fill", action: {})
                        glassToolbarButton(icon: "rectangle.portrait.and.arrow.right", action: {
                            showLogoutConfirmation = true
                        })
                    }
                }
            }
            .onAppear(perform: loadLinkedPublisher)
            .confirmationDialog(
                "Log out of Shepherd?",
                isPresented: $showLogoutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Log Out", role: .destructive, action: performLogout)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes congregation data from this iPhone. You can join again with an invite link.")
            }
            .alert(
                "Could Not Log Out",
                isPresented: Binding(
                    get: { logoutErrorMessage != nil },
                    set: { if !$0 { logoutErrorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(logoutErrorMessage ?? "")
            }
        }
    }

    private func performLogout() {
        do {
            try SessionService.logout()
        } catch {
            logoutErrorMessage = error.localizedDescription
        }
    }

    private func loadLinkedPublisher() {
        guard let publisherId = DeviceIdentityManager.shared.linkedPublisherId else {
            displayName = ""
            return
        }
        let request = NSFetchRequest<Publisher>(entityName: "Publisher")
        request.predicate = NSPredicate(format: "id == %@", publisherId as CVarArg)
        request.fetchLimit = 1
        displayName = (try? context.fetch(request).first?.firstName) ?? ""
    }

    private func glassToolbarButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background {
                    LiquidGlassSurface(shape: Circle(), interactive: true)
                }
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(greeting)
                .font(ShepherdFont.caption(.medium))
                .foregroundStyle(ShepherdColors.textSecondary)

            if displayName.isEmpty {
                Text("Welcome")
                    .font(ShepherdFont.display(.bold))
                    .foregroundStyle(.white)
            } else {
                Text(displayName)
                    .font(ShepherdFont.display(.bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Up Next")
                .font(ShepherdFont.title())
                .adaptiveTextPrimary()

            ShepherdEmptyState(
                icon: "calendar.badge.clock",
                title: "Nothing scheduled yet",
                message: "Your upcoming meeting parts and reminders will appear here once schedules are published."
            )
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
