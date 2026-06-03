//
//  InviteDeepLinkHandler.swift
//  Shepherd
//

import Foundation

/// Handles `shepherd://` and Universal Link (`https://…/i/…`) invite URLs.
@MainActor
final class InviteDeepLinkHandler {
    static let shared = InviteDeepLinkHandler()

    private(set) var pendingInviteCode: String?
    private var didAttemptAutoJoinThisSession = false

    private init() {}

    func resetForLogout() {
        pendingInviteCode = nil
        didAttemptAutoJoinThisSession = false
    }

    func handleIncoming(url: URL) {
        guard let code = parseInviteCode(from: url) else { return }

        pendingInviteCode = code
        didAttemptAutoJoinThisSession = false
        Task { await processInviteLink(identity: DeviceIdentityBridge.shared) }
    }

    /// After the landing-page fingerprint and/or a deep link, join without tapping the button.
    func attemptAutomaticJoinIfNeeded(identity: DeviceIdentityBridge) async {
        guard !didAttemptAutoJoinThisSession else { return }
        didAttemptAutoJoinThisSession = true
        await attemptAutomaticJoin(identity: identity)
    }

    private func processInviteLink(identity: DeviceIdentityBridge) async {
        guard identity.onboardingState == .fresh, let code = pendingInviteCode else { return }

        try? await OnboardingService.shared.recordInviteClick(inviteCode: code)
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

    private func parseInviteCode(from url: URL) -> String? {
        if url.scheme?.lowercased() == "shepherd" {
            let host = (url.host ?? "").lowercased()
            let path = url.path.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            guard host == "invite" || path == "invite" else { return nil }
            return queryInviteCode(from: url)
        }

        guard let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http" else {
            return nil
        }
        guard isInviteHost(url) else { return nil }

        if let code = queryInviteCode(from: url) {
            return code
        }

        let parts = url.path.split(separator: "/").map(String.init)
        guard let iIndex = parts.firstIndex(where: { $0.lowercased() == "i" }),
              iIndex + 1 < parts.count else {
            return nil
        }
        let segment = parts[iIndex + 1]
        guard segment != "index.html" else { return nil }
        return segment.uppercased()
    }

    private func queryInviteCode(from url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" || $0.name == "c" })?.value,
              !code.isEmpty else {
            return nil
        }
        return code.uppercased()
    }

    private func isInviteHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        guard let inviteHost = SupabaseConfig.inviteHost,
              let configured = URL(string: inviteHost),
              let configuredHost = configured.host?.lowercased() else {
            return false
        }
        return host == configuredHost
    }
}
