//
//  PublisherDetailView.swift
//  Shepherd
//

import SwiftUI
import CoreData

private enum PublisherLinkStatus {
    case unlinked
    case pendingApproval
    case linked

    var label: String {
        switch self {
        case .unlinked: return "Not linked to a device"
        case .pendingApproval: return "Invite sent — awaiting approval"
        case .linked: return "Device linked"
        }
    }

    var icon: String {
        switch self {
        case .unlinked: return "person.crop.circle.badge.plus"
        case .pendingApproval: return "clock.fill"
        case .linked: return "checkmark.circle.fill"
        }
    }
}

struct PublisherDetailView: View {
    @ObservedObject var publisher: Publisher
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "requestedAt", ascending: false)],
        predicate: NSPredicate(format: "statusRaw == %@", AccessRequestStatus.pending.rawValue),
        animation: .default
    )
    private var pendingAccessRequests: FetchedResults<AccessRequest>

    @State private var generatedInviteCode: String?
    @State private var generatedInviteURL: URL?
    @State private var isGeneratingInvite = false
    @State private var showError = false
    @State private var errorMessage: String?

    private var isElder: Bool {
        DeviceIdentityManager.shared.directoryScope == .full
    }

    private var linkStatus: PublisherLinkStatus {
        if CongregationSyncService.shared.isDeviceLinked(publisherId: publisher.id) {
            return .linked
        }
        if pendingAccessRequests.contains(where: { $0.publisherId == publisher.id }) {
            return .pendingApproval
        }
        return .unlinked
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerCard
                statusCard

                if isElder, linkStatus != .linked {
                    inviteSection
                }
            }
            .padding(20)
            .padding(.bottom, 100)
        }
        .background { LiquidMeshBackground() }
        .navigationTitle(publisher.fullName)
        .navigationBarTitleDisplayMode(.inline)
        .modifier(ShepherdNavigationBarStyle())
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(publisher.lastName), \(publisher.firstName)")
                .font(ShepherdFont.title(.bold))
                .adaptiveTextPrimary()

            if let phone = publisher.phoneNumber, !phone.isEmpty {
                Label(phone, systemImage: "phone.fill")
                    .font(ShepherdFont.body())
                    .adaptiveTextSecondary()
            }
            if let email = publisher.email, !email.isEmpty {
                Label(email, systemImage: "envelope.fill")
                    .font(ShepherdFont.body())
                    .adaptiveTextSecondary()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: linkStatus.icon)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(ShepherdColors.liquidAccentSoft)

            VStack(alignment: .leading, spacing: 4) {
                Text("Device status")
                    .font(ShepherdFont.caption(.semibold))
                    .adaptiveTextSecondary()
                Text(linkStatus.label)
                    .font(ShepherdFont.body(.semibold))
                    .adaptiveTextPrimary()
            }
            Spacer()
        }
        .compactGlassCard()
    }

    @ViewBuilder
    private var inviteSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send invite")
                .font(ShepherdFont.headline(.bold))
                .adaptiveTextPrimary()

            Text("Sending this link pre-approves this publisher and uploads their welcome package. The link only works once, on the device that opens it.")
                .font(ShepherdFont.caption())
                .adaptiveTextSecondary()

            Button(action: generateInvite) {
                HStack {
                    if isGeneratingInvite { ProgressView().tint(.white) }
                    Text(isGeneratingInvite ? "Creating…" : "Create invite link")
                }
            }
            .buttonStyle(LiquidPrimaryButtonStyle())
            .disabled(isGeneratingInvite)

            if let generatedInviteCode {
                VStack(alignment: .leading, spacing: 10) {
                    if let generatedInviteURL {
                        Text(generatedInviteURL.absoluteString)
                            .font(ShepherdFont.caption())
                            .foregroundStyle(ShepherdColors.liquidAccentSoft)
                            .textSelection(.enabled)
                    }

                    Text(generatedInviteCode)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(ShepherdColors.liquidAccentSoft)

                    HStack(spacing: 12) {
                        Button("Copy link") {
                            UIPasteboard.general.string = inviteShareMessage
                        }
                        .font(ShepherdFont.caption(.semibold))
                        .foregroundStyle(ShepherdColors.liquidAccentSoft)

                        if #available(iOS 16.0, *) {
                            ShareLink(item: inviteShareMessage) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                            .font(ShepherdFont.caption(.semibold))
                            .foregroundStyle(ShepherdColors.liquidAccentSoft)
                        }
                    }
                }
                .padding(16)
                .compactGlassCard()
            }
        }
        .glassCard()
    }

    private var inviteShareMessage: String {
        guard let generatedInviteCode else { return "" }
        if let generatedInviteURL {
            return "Join our congregation in Shepherd: \(generatedInviteURL.absoluteString)"
        }
        return "Join our congregation in Shepherd. Invite code: \(generatedInviteCode)"
    }

    private func generateInvite() {
        guard let congregationId = DeviceIdentityManager.shared.congregationId else {
            errorMessage = "Congregation is not configured on this device."
            showError = true
            return
        }

        isGeneratingInvite = true
        Task {
            do {
                let code = try await OnboardingService.shared.createInviteSession(
                    publisherId: publisher.id,
                    congregationId: congregationId
                )
                generatedInviteCode = code
                generatedInviteURL = OnboardingService.shared.inviteURL(for: code)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isGeneratingInvite = false
        }
    }
}
