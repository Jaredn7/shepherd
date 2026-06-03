//
//  AppDelegate.swift
//  Shepherd
//
//  UIKit handlers for Universal Links and custom URL schemes (more reliable than SwiftUI-only).
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            return false
        }

        Task { @MainActor in
            InviteDeepLinkHandler.shared.handleIncoming(url: url)
        }
        return true
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        Task { @MainActor in
            InviteDeepLinkHandler.shared.handleIncoming(url: url)
        }
        return true
    }
}
