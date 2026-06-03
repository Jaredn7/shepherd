//
//  ShepherdApp.swift
//  Shepherd
//

import SwiftUI

@main
struct ShepherdApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    InviteDeepLinkHandler.shared.handleIncoming(url: url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        InviteDeepLinkHandler.shared.handleIncoming(url: url)
                    }
                }
        }
    }
}
