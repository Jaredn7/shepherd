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
        }
    }
}
