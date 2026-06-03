//
//  WaitingForApprovalView.swift
//  Shepherd
//

import SwiftUI

struct WaitingForApprovalView: View {
    @ObservedObject private var identityBridge = DeviceIdentityBridge.shared
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @State private var isRefreshing = false

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

                Spacer()
            }
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
}
