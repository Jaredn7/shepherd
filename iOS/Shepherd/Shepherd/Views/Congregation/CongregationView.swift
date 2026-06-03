//
//  CongregationView.swift
//  Shepherd
//

import SwiftUI
import CoreData

private enum DirectorySegment: String, CaseIterable {
    case allAZ = "All (A-Z)"
    case serviceGroups = "Service Groups"
}

struct CongregationView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var animation
    @State private var selectedSegment: DirectorySegment = .allAZ
    @State private var searchText = ""
    @State private var showAddPublisher = false

    private var isElder: Bool {
        DeviceIdentityManager.shared.directoryScope == .full
    }

    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(key: "lastName", ascending: true),
            NSSortDescriptor(key: "firstName", ascending: true),
        ],
        predicate: NSPredicate(format: "isActive == YES"),
        animation: .default
    )
    private var publishers: FetchedResults<Publisher>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(key: "name", ascending: true)],
        animation: .default
    )
    private var serviceGroups: FetchedResults<ServiceGroup>

    private var filteredPublishers: [Publisher] {
        let sorted = Array(publishers)
        guard !searchText.isEmpty else { return sorted }
        return sorted.filter {
            $0.fullName.localizedCaseInsensitiveContains(searchText)
                || $0.lastName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ShepherdNavigationStack {
            VStack(spacing: 0) {
                segmentedPicker
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 10) {
                        if selectedSegment == .allAZ {
                            allPublishersList
                        } else {
                            serviceGroupsList
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 120)
                }
            }
            .background { LiquidMeshBackground() }
            .navigationTitle("Congregation")
            .navigationBarTitleDisplayMode(.inline)
            .modifier(ShepherdNavigationBarStyle())
            .searchable(text: $searchText, prompt: "Search publishers")
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: selectedSegment)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isElder {
                        Button {
                            showAddPublisher = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        .accessibilityLabel("Add publisher")
                    }
                }
            }
            .sheet(isPresented: $showAddPublisher) {
                AddPublisherSheet()
            }
        }
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(DirectorySegment.allCases, id: \.self) { segment in
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        selectedSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(ShepherdFont.caption(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(
                            selectedSegment == segment
                                ? Color.white
                                : (colorScheme == .dark ? ShepherdColors.textSecondary : ShepherdColors.textSecondaryLight)
                        )
                        .background {
                            if selectedSegment == segment {
                                Capsule(style: .continuous)
                                    .fill(ShepherdColors.liquidAccent)
                                    .matchedGeometryEffect(id: "segmentBackground", in: animation)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background {
            LiquidGlassSurface(shape: Capsule(style: .continuous))
        }
    }

    // MARK: - All Publishers

    @ViewBuilder
    private var allPublishersList: some View {
        if filteredPublishers.isEmpty {
            ShepherdEmptyState(
                icon: "person.3.fill",
                title: searchText.isEmpty ? "No publishers yet" : "No matches",
                message: searchText.isEmpty
                    ? (isElder
                        ? "Tap + to add a publisher. Their record syncs to connected devices before you send an invite."
                        : "Publishers in your congregation will appear here.")
                    : "Try a different name."
            )
        } else {
            ForEach(Array(filteredPublishers.enumerated()), id: \.element.id) { index, publisher in
                publisherRow(publisher)
                    .slideUpEntrance(delay: Double(index) * 0.03)
            }
        }
    }

    private func publisherRow(_ publisher: Publisher) -> some View {
        NavigationLink(destination: PublisherDetailView(publisher: publisher)) {
            publisherRowContent(publisher)
        }
        .buttonStyle(.plain)
    }

    private func publisherRowContent(_ publisher: Publisher) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(ShepherdColors.liquidAccent.opacity(0.15))
                    .frame(width: 44, height: 44)

                Text(String(publisher.firstName.prefix(1)))
                    .font(ShepherdFont.headline(.bold))
                    .foregroundStyle(ShepherdColors.liquidAccentSoft)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(publisher.lastName), \(publisher.firstName)")
                    .font(ShepherdFont.body(.bold))
                    .adaptiveTextPrimary()

                if publisher.privilege != .publisher || publisher.pioneerStatus != .none {
                    HStack(spacing: 4) {
                        Image(systemName: badgeIcon(for: publisher))
                            .font(.system(size: 10, weight: .semibold))
                        Text(badgeLabel(for: publisher))
                            .font(ShepherdFont.caption(.medium))
                    }
                    .foregroundStyle(badgeColor(for: publisher))
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .adaptiveTextSecondary()
        }
        .compactGlassCard()
        .tapScale()
    }

    // MARK: - Service Groups

    @ViewBuilder
    private var serviceGroupsList: some View {
        if serviceGroups.isEmpty {
            ShepherdEmptyState(
                icon: "person.3.sequence.fill",
                title: "No service groups yet",
                message: "Field service groups will appear here once they are set up in the congregation."
            )
        } else {
            ForEach(Array(serviceGroups.enumerated()), id: \.element.id) { index, group in
                serviceGroupCard(group)
                    .slideUpEntrance(delay: Double(index) * 0.06)
            }
        }
    }

    private func serviceGroupCard(_ group: ServiceGroup) -> some View {
        let members = publishers.filter { $0.serviceGroupId == group.id }

        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(ShepherdColors.liquidAccentSoft)

                Text(group.name)
                    .font(ShepherdFont.headline(.bold))
                    .adaptiveTextPrimary()

                Spacer()

                Text("\(members.count)")
                    .font(ShepherdFont.caption(.bold))
                    .foregroundStyle(ShepherdColors.liquidAccentSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ShepherdColors.liquidAccent.opacity(0.15))
                    )
            }

            if members.isEmpty {
                Text("No publishers assigned to this group yet.")
                    .font(ShepherdFont.caption())
                    .adaptiveTextSecondary()
            } else {
                ForEach(members, id: \.id) { member in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Text(String(member.firstName.prefix(1)))
                                    .font(ShepherdFont.caption(.bold))
                                    .foregroundStyle(ShepherdColors.textSecondary)
                            )

                        Text("\(member.lastName), \(member.firstName)")
                            .font(ShepherdFont.body(.regular))
                            .adaptiveTextPrimary()

                        Spacer()
                    }
                }
            }
        }
        .glassCard()
        .tapScale()
    }

    // MARK: - Badges

    private func badgeLabel(for publisher: Publisher) -> String {
        switch publisher.privilege {
        case .elder: return "Elder"
        case .ministerialServant: return "MS"
        case .publisher:
            switch publisher.pioneerStatus {
            case .regularPioneer: return "Pioneer"
            case .auxiliaryPioneer: return "Aux. Pioneer"
            case .specialPioneer: return "Special Pioneer"
            case .none: return "Publisher"
            }
        }
    }

    private func badgeIcon(for publisher: Publisher) -> String {
        switch publisher.privilege {
        case .elder: return "shield.fill"
        case .ministerialServant: return "hands.sparkles.fill"
        case .publisher:
            return publisher.pioneerStatus != .none ? "star.fill" : "person.fill"
        }
    }

    private func badgeColor(for publisher: Publisher) -> Color {
        switch publisher.privilege {
        case .elder: return ShepherdColors.elderBadge
        case .ministerialServant: return ShepherdColors.secondary
        case .publisher:
            return publisher.pioneerStatus != .none ? ShepherdColors.pioneerBadge : ShepherdColors.textSecondary
        }
    }
}

#Preview {
    CongregationView()
        .preferredColorScheme(.dark)
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
