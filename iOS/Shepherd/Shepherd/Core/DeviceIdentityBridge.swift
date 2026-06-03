//
//  DeviceIdentityBridge.swift
//  Shepherd
//
//  Bridges UserDefaults-backed onboarding state into SwiftUI.
//

import Combine

@MainActor
final class DeviceIdentityBridge: ObservableObject {
    static let shared = DeviceIdentityBridge()

    @Published var onboardingState: OnboardingState
    @Published var inviteJoinError: String?

    private init() {
        onboardingState = DeviceIdentityManager.shared.onboardingState
    }

    func refresh() {
        onboardingState = DeviceIdentityManager.shared.onboardingState
    }
}
