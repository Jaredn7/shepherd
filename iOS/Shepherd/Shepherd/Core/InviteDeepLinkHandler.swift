//
//  InviteDeepLinkHandler.swift
//  Shepherd
//

import Foundation

/// Handles Universal Links (`https://…/i/CODE`) and `shepherd://` invite URLs.
///
/// - **App installed:** WhatsApp tap → iOS opens app with URL → `recordInviteClick` + welcome package (no Safari).
/// - **App not installed:** Safari landing saves fingerprint → App Store → first launch matches fingerprint.
@MainActor
final class InviteDeepLinkHandler {
    static let shared = InviteDeepLinkHandler()

    private(set) var pendingInviteCode: String?
    private var didAttemptDeferredFingerprintJoin = false

    private init() {}

    func resetForLogout() {
        pendingInviteCode = nil
        didAttemptDeferredFingerprintJoin = false
    }

    func handleIncoming(url: URL) {
        guard let code = parseInviteCode(from: url) else { return }

        pendingInviteCode = code
        Task { await processInviteLink(identity: DeviceIdentityBridge.shared) }
    }

    /// After install without opening the app from the link (Safari fingerprint only).
    func attemptDeferredFingerprintJoinIfNeeded(identity: DeviceIdentityBridge) async {
        guard pendingInviteCode == nil else { return }
        guard !didAttemptDeferredFingerprintJoin else { return }
        guard identity.onboardingState == .fresh else { return }

        didAttemptDeferredFingerprintJoin = true
        await attemptJoin(identity: identity, inviteCode: nil)
    }

    private func processInviteLink(identity: DeviceIdentityBridge) async {
        guard identity.onboardingState == .fresh, let code = pendingInviteCode else { return }

        didAttemptDeferredFingerprintJoin = true
        try? await OnboardingService.shared.recordInviteClick(inviteCode: code)
        await attemptJoin(identity: identity, inviteCode: code)
    }

    private func attemptJoin(identity: DeviceIdentityBridge, inviteCode: String?) async {
        guard identity.onboardingState == .fresh else { return }

        let code = inviteCode ?? pendingInviteCode
        pendingInviteCode = nil

        do {
            try await OnboardingService.shared.joinWithPreApprovedInvite(inviteCode: code)
            identity.inviteJoinError = nil
            identity.refresh()
        } catch {
            if code != nil {
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
