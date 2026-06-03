//
//  RootView.swift
//  Shepherd
//

import SwiftUI

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared
    @ObservedObject private var identity = DeviceIdentityBridge.shared

    var body: some View {
        Group {
            switch identity.onboardingState {
            case .fresh:
                OnboardingView()
            case .pendingApproval:
                WaitingForApprovalView()
            case .linked:
                MainTabView()
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
        .task {
            await syncCoordinator.syncIfNeeded()
            await InviteDeepLinkHandler.shared.attemptDeferredFingerprintJoinIfNeeded(identity: identity)
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                Task { await syncCoordinator.syncIfNeeded() }
                if identity.onboardingState == .fresh {
                    Task {
                        await InviteDeepLinkHandler.shared.attemptDeferredFingerprintJoinIfNeeded(identity: identity)
                    }
                }
            }
        }
    }
}
