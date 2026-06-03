//
//  MainTabView.swift
//  Shepherd
//

import SwiftUI

private enum ShepherdTab: Int, Hashable {
    case home = 0
    case meetings = 1
    case ministry = 2
    case congregation = 3
}

struct MainTabView: View {
    @State private var selectedTab: ShepherdTab = .home
    @State private var showElderTools = false
    @ObservedObject private var syncCoordinator = SyncCoordinator.shared

    private var isElder: Bool {
        DeviceIdentityManager.shared.directoryScope == .full
    }

    private let legacyTabItems: [(title: String, icon: String)] = [
        ("Home", "house.fill"),
        ("Meetings", "calendar"),
        ("Ministry", "book.fill"),
        ("Cong.", "person.3.fill"),
    ]

    var body: some View {
        Group {
            if #available(iOS 18.0, *) {
                nativeTabView
            } else {
                legacyTabView
            }
        }
        .tint(ShepherdColors.liquidAccent)
        .sheet(isPresented: $showElderTools) {
            ElderAccessRequestsView()
        }
    }

    // MARK: - iOS 18+ native floating Liquid Glass tab bar

    @available(iOS 18.0, *)
    private var nativeTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: ShepherdTab.home) {
                HomeView(showElderTools: isElder, onElderTools: { showElderTools = true })
            }

            Tab("Meetings", systemImage: "calendar", value: ShepherdTab.meetings) {
                MeetingsView()
            }

            Tab("Ministry", systemImage: "book.fill", value: ShepherdTab.ministry) {
                MinistryView()
            }

            Tab("Cong.", systemImage: "person.3.fill", value: ShepherdTab.congregation) {
                CongregationView()
            }
        }
        .shepherdTabBarMinimize()
        .refreshable {
            await syncCoordinator.performSync()
        }
    }

    // MARK: - iOS 15–17 custom floating glass tab bar

    private var legacyTabView: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: Binding(
                get: { selectedTab.rawValue },
                set: { selectedTab = ShepherdTab(rawValue: $0) ?? .home }
            )) {
                HomeView(showElderTools: isElder, onElderTools: { showElderTools = true })
                    .tag(ShepherdTab.home.rawValue)

                MeetingsView().tag(ShepherdTab.meetings.rawValue)
                MinistryView().tag(ShepherdTab.ministry.rawValue)
                CongregationView().tag(ShepherdTab.congregation.rawValue)
            }
            .onAppear { UITabBar.appearance().isHidden = true }

            FloatingLiquidTabBar(
                selection: Binding(
                    get: { selectedTab.rawValue },
                    set: { selectedTab = ShepherdTab(rawValue: $0) ?? .home }
                ),
                items: legacyTabItems
            )
        }
        .refreshable {
            await syncCoordinator.performSync()
        }
    }
}

#Preview {
    MainTabView()
        .preferredColorScheme(.dark)
}
