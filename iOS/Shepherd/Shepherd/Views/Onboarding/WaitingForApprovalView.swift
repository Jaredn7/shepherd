//
//  WaitingForApprovalView.swift
//  Shepherd
//

import SwiftUI

struct WaitingForApprovalView: View {
    @ObservedObject private var identityBridge = DeviceIdentityBridge.shared
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @State private var isRefreshing = false
    @State private var showLogoutConfirmation = false
    @State private var logoutErrorMessage: String?

    var body: some View {
        ZStack {
            LiquidMeshBackground()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(ShepherdColors.liquidAccent.opacity(0.15))
                        .frame(width: 100, height: 100)

                    Image(systemName: "hourglass")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(ShepherdColors.liquidAccentSoft)
                        .opacity(isRefreshing ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isRefreshing)
                }

                VStack(spacing: 10) {
                    Text("Waiting for Elders")
                        .font(ShepherdFont.display(.bold))
                        .adaptiveTextPrimary()

                    Text("Your access request was sent securely. An elder will approve you soon.")
                        .font(ShepherdFont.body())
                        .adaptiveTextSecondary()
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Button(action: refresh) {
                    HStack {
                        if isRefreshing { ProgressView().tint(.white) }
                        Text(isRefreshing ? "Checking…" : "Check for Approval")
                    }
                }
                .buttonStyle(LiquidPrimaryButtonStyle())
                .padding(.horizontal, 40)
                .disabled(isRefreshing)

                if let error = syncCoordinator.lastSyncError {
                    Text(error)
                        .font(ShepherdFont.caption())
                        .foregroundStyle(ShepherdColors.accent)
                        .padding(.horizontal, 24)
                }

                Button("Log Out") {
                    showLogoutConfirmation = true
                }
                .font(ShepherdFont.caption())
                .foregroundStyle(ShepherdColors.textSecondary)
                .padding(.bottom, 24)

                Spacer()
            }
        }
        .confirmationDialog(
            "Log out of Shepherd?",
            isPresented: $showLogoutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Log Out", role: .destructive, action: performLogout)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your access request will be cleared from this device.")
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
        .onAppear {
            isRefreshing = true
            identityBridge.refresh()
        }
        .onChange(of: syncCoordinator.isSyncing) { syncing in
            if !syncing {
                identityBridge.refresh()
            }
        }
    }

    private func refresh() {
        isRefreshing = true
        Task {
            await syncCoordinator.performSync()
            identityBridge.refresh()
            isRefreshing = false
        }
    }

    private func performLogout() {
        do {
            try SessionService.logout()
        } catch {
            logoutErrorMessage = error.localizedDescription
        }
    }
}
