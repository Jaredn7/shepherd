//
//  ElderAccessRequestsView.swift
//  Shepherd
//

import SwiftUI
import CoreData

struct ElderAccessRequestsView: View {
    @Environment(\.managedObjectContext) private var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "requestedAt", ascending: false)],
        predicate: NSPredicate(format: "statusRaw == %@", AccessRequestStatus.pending.rawValue),
        animation: .default
    )
    private var pendingRequests: FetchedResults<AccessRequest>

    @State private var processingId: UUID?
    @State private var showError = false
    @State private var errorMessage: String?

    var body: some View {
        ShepherdNavigationStack {
            List {
                if pendingRequests.isEmpty {
                    Text("No pending access requests.")
                        .font(ShepherdFont.body())
                        .foregroundStyle(ShepherdColors.textSecondary)
                        .listRowBackground(Color.clear)
                } else {
                    ForEach(pendingRequests, id: \.id) { request in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(publisherTitle(for: request))
                                .font(ShepherdFont.headline())

                            Text("Device: \(request.requesterDeviceId.uuidString.prefix(8))…")
                                .font(ShepherdFont.caption())
                                .foregroundStyle(ShepherdColors.textSecondary)

                            Button("Approve & Send Welcome Package") {
                                approve(request)
                            }
                            .disabled(processingId == request.id)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(ShepherdColors.surfaceElevated)
                    }
                }

                Section {
                    Text("Invite links are pre-approved. Publishers join automatically after opening their link and installing Shepherd.")
                        .font(ShepherdFont.caption())
                        .foregroundStyle(ShepherdColors.textSecondary)
                        .listRowBackground(Color.clear)
                }
            }
            .modifier(HiddenScrollBackground())
            .background { LiquidMeshBackground() }
            .navigationTitle("Access Requests")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func publisherTitle(for request: AccessRequest) -> String {
        guard let publisherId = request.publisherId else {
            return "Publisher access request"
        }
        let fetch = NSFetchRequest<Publisher>(entityName: "Publisher")
        fetch.predicate = NSPredicate(format: "id == %@", publisherId as CVarArg)
        fetch.fetchLimit = 1
        guard let publisher = try? context.fetch(fetch).first else {
            return "Publisher access request"
        }
        return "\(publisher.lastName), \(publisher.firstName)"
    }

    private func approve(_ request: AccessRequest) {
        processingId = request.id
        Task {
            do {
                try await OnboardingService.shared.approveAccessRequest(request)
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            processingId = nil
        }
    }
}
