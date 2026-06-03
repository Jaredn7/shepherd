//
//  OnboardingView.swift
//  Shepherd
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject private var identityBridge = DeviceIdentityBridge.shared

    @State private var inviteCode = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showElderBootstrap = false
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ShepherdNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if showElderBootstrap {
                        elderBootstrapSection
                    } else {
                        publisherSection
                    }

                    if let message = errorMessage ?? identityBridge.inviteJoinError {
                        Text(message)
                            .font(ShepherdFont.caption())
                            .foregroundStyle(ShepherdColors.accent)
                    }
                }
                .padding(24)
                .padding(.bottom, 40)
            }
            .background { LiquidMeshBackground() }
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to Shepherd")
                .font(ShepherdFont.display(.bold))
                .adaptiveTextPrimary()

            Text("Connect securely to your congregation using the invite link from an elder.")
                .font(ShepherdFont.body())
                .adaptiveTextSecondary()
        }
        .slideUpEntrance()
    }

    private var publisherSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Publisher Setup")
                .font(ShepherdFont.title())
                .adaptiveTextPrimary()

            glassTextField("Invite code (if link already opened)", text: $inviteCode)
                .textInputAutocapitalization(.characters)

            Button(action: joinWithInvite) {
                HStack {
                    if isLoading { ProgressView().tint(.white) }
                    Text(isLoading ? "Joining…" : "Open Shepherd")
                }
            }
            .buttonStyle(LiquidPrimaryButtonStyle())
            .disabled(isLoading)

            Button("First-time elder? Set up congregation") {
                withAnimation(.spring()) { showElderBootstrap = true }
            }
            .font(ShepherdFont.caption())
            .foregroundStyle(ShepherdColors.liquidAccentSoft)
        }
        .glassCard()
        .slideUpEntrance(delay: 0.1)
    }

    private var elderBootstrapSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Elder Bootstrap")
                .font(ShepherdFont.title())
                .adaptiveTextPrimary()

            Text("Pilot mode: create the first elder account for a new congregation.")
                .font(ShepherdFont.caption())
                .adaptiveTextSecondary()

            glassTextField("First name", text: $firstName)
            glassTextField("Last name", text: $lastName)

            Button(action: bootstrapElder) {
                Text("Create Elder Account")
            }
            .buttonStyle(LiquidPrimaryButtonStyle())
            .disabled(firstName.isEmpty || lastName.isEmpty || isLoading)

            Button("Back to publisher setup") {
                withAnimation(.spring()) { showElderBootstrap = false }
            }
            .font(ShepherdFont.caption())
            .foregroundStyle(ShepherdColors.textSecondary)
        }
        .glassCard()
    }

    private func glassTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: ShepherdRadius.medium, style: .continuous)
                    .fill(ShepherdColors.glassFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: ShepherdRadius.medium, style: .continuous)
                            .stroke(ShepherdColors.glassBorder, lineWidth: 0.5)
                    )
            }
            .foregroundStyle(.white)
    }

    private func joinWithInvite() {
        isLoading = true
        errorMessage = nil
        identityBridge.inviteJoinError = nil
        Task {
            do {
                let code = inviteCode.trimmingCharacters(in: .whitespacesAndNewlines)
                try await OnboardingService.shared.joinWithPreApprovedInvite(
                    inviteCode: code.isEmpty ? nil : code
                )
                identityBridge.refresh()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    private func bootstrapElder() {
        isLoading = true
        errorMessage = nil
        do {
            try OnboardingService.shared.bootstrapElderAccount(
                firstName: firstName,
                lastName: lastName,
                congregationId: UUID()
            )
            identityBridge.refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
