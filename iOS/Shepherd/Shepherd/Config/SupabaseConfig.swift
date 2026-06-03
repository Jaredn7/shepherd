//
//  SupabaseConfig.swift
//  Shepherd
//

import Foundation

enum SupabaseConfig {
    static let projectURL: URL = {
        guard let urlString = string(for: "SUPABASE_URL"),
              let url = URL(string: urlString) else {
            fatalError("SUPABASE_URL missing from SupabaseConfig.plist")
        }
        return url
    }()

    static let anonKey: String = {
        guard let key = string(for: "SUPABASE_ANON_KEY"), !key.isEmpty else {
            fatalError("SUPABASE_ANON_KEY missing from SupabaseConfig.plist")
        }
        return key
    }()

    static let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }()

    /// Public invite landing host, e.g. https://join.yourdomain.com
    static var inviteHost: String? {
        guard let host = string(for: "INVITE_HOST"), !host.isEmpty,
              host != "https://join.yourdomain.com" else {
            return nil
        }
        return host
    }

    static func functionsURL(_ name: String) -> URL {
        projectURL.appendingPathComponent("functions/v1/\(name)")
    }

    private static func string(for key: String) -> String? {
        guard let url = Bundle.main.url(forResource: "SupabaseConfig", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return plist[key] as? String
    }
}
