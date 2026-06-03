//
//  InviteDeepLinkHandler.swift
//  Shepherd
//

import Foundation

/// Handles `shepherd://invite?code=…` from the Web-Public landing page (no Universal Links required).
@MainActor
final class InviteDeepLinkHandler {
    static let shared = InviteDeepLinkHandler()

    private(set) var pendingInviteCode: String?
    private var didAttemptAutoJoinThisSession = false

    private init() {}

    func handleIncoming(url: URL) {
        guard url.scheme?.lowercased() == "shepherd" else { return }

        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let isInviteRoute = host == "invite" || path == "invite"
        guard isInviteRoute else { return }

        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let code = components.queryItems?.first(where: { $0.name == "code" })?.value,
           !code.isEmpty {
            pendingInviteCode = code.uppercased()
            didAttemptAutoJoinThisSession = false
            Task { await attemptAutomaticJoin(identity: DeviceIdentityBridge.shared) }
        }
    }

    /// After the landing-page fingerprint and/or a deep link, join without tapping the button.
    func attemptAutomaticJoinIfNeeded(identity: DeviceIdentityBridge) async {
        guard !didAttemptAutoJoinThisSession else { return }
        didAttemptAutoJoinThisSession = true
        await attemptAutomaticJoin(identity: identity)
    }

    private func attemptAutomaticJoin(identity: DeviceIdentityBridge) async {
        guard identity.onboardingState == .fresh else { return }

        let explicitCode = pendingInviteCode
        pendingInviteCode = nil

        do {
            try await OnboardingService.shared.joinWithPreApprovedInvite(
                inviteCode: explicitCode
            )
            identity.inviteJoinError = nil
            identity.refresh()
        } catch {
            if explicitCode != nil {
                identity.inviteJoinError = error.localizedDescription
            }
        }
    }
}
