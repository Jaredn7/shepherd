//
//  AddPublisherSheet.swift
//  Shepherd
//

import SwiftUI

struct AddPublisherSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var privilege: PublisherPrivilege = .publisher
    @State private var pioneerStatus: PioneerStatus = .none
    @State private var phoneNumber = ""
    @State private var email = ""
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        ShepherdNavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Add a publisher to the congregation directory. Other connected devices will receive this record before you send an invite.")
                        .font(ShepherdFont.caption())
                        .adaptiveTextSecondary()

                    glassTextField("First name", text: $firstName)
                    glassTextField("Last name", text: $lastName)

                    Picker("Privilege", selection: $privilege) {
                        ForEach(PublisherPrivilege.allCases, id: \.self) { value in
                            Text(privilegeLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.menu)

                    if privilege == .publisher {
                        Picker("Pioneer status", selection: $pioneerStatus) {
                            ForEach(PioneerStatus.allCases, id: \.self) { value in
                                Text(pioneerLabel(value)).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    glassTextField("Phone (optional)", text: $phoneNumber)
                        .keyboardType(.phonePad)
                    glassTextField("Email (optional)", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(ShepherdFont.caption())
                            .foregroundStyle(ShepherdColors.accent)
                    }

                    Button(action: save) {
                        HStack {
                            if isSaving { ProgressView().tint(.white) }
                            Text(isSaving ? "Saving…" : "Add to Congregation")
                        }
                    }
                    .buttonStyle(LiquidPrimaryButtonStyle())
                    .disabled(isSaving || firstName.trimmingCharacters(in: .whitespaces).isEmpty || lastName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(24)
            }
            .background { LiquidMeshBackground() }
            .navigationTitle("Add Publisher")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
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
            .foregroundStyle(.primary)
    }

    private func save() {
        isSaving = true
        errorMessage = nil
        Task {
            do {
                _ = try await CongregationSyncService.shared.addPublisher(
                    firstName: firstName,
                    lastName: lastName,
                    privilege: privilege,
                    pioneerStatus: privilege == .publisher ? pioneerStatus : .none,
                    phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
                    email: email.isEmpty ? nil : email
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    private func privilegeLabel(_ value: PublisherPrivilege) -> String {
        switch value {
        case .publisher: return "Publisher"
        case .ministerialServant: return "Ministerial Servant"
        case .elder: return "Elder"
        }
    }

    private func pioneerLabel(_ value: PioneerStatus) -> String {
        switch value {
        case .none: return "None"
        case .auxiliaryPioneer: return "Auxiliary Pioneer"
        case .regularPioneer: return "Regular Pioneer"
        case .specialPioneer: return "Special Pioneer"
        }
    }
}
