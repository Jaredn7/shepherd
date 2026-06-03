//
//  DeviceIdentityManager.swift
//  Shepherd
//
//  Manages the anonymous device UUID and onboarding profile stored locally.
//

import Foundation
import Security
import UIKit

enum OnboardingState: String, Codable {
    case fresh
    case pendingApproval
    case linked
}

enum DirectoryScope: String, Codable {
    case lite
    case full
}

enum DeviceIdentityError: LocalizedError {
    case keychainFailure(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychainFailure(let status):
            return "Keychain error (OSStatus: \(status))"
        }
    }
}

/// Stores the device's anonymous identity and onboarding progress.
final class DeviceIdentityManager {
    static let shared = DeviceIdentityManager()

    private static let keychainService = "com.shepherd.device"
    private static let keychainAccount = "anonymous-device-id"

    private enum DefaultsKey {
        static let onboardingState = "shepherd.onboardingState"
        static let congregationId = "shepherd.congregationId"
        static let linkedPublisherId = "shepherd.linkedPublisherId"
        static let directoryScope = "shepherd.directoryScope"
        static let elderDeviceId = "shepherd.elderDeviceId"
        static let lastSuccessfulSync = "shepherd.lastSuccessfulSync"
    }

    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Device ID

    var deviceId: UUID {
        if let existing = loadDeviceIdFromKeychain() {
            return existing
        }
        let newId = UUID()
        try? saveDeviceIdToKeychain(newId)
        return newId
    }

    // MARK: - Profile

    var onboardingState: OnboardingState {
        get {
            guard let raw = defaults.string(forKey: DefaultsKey.onboardingState),
                  let state = OnboardingState(rawValue: raw) else {
                return .fresh
            }
            return state
        }
        set {
            defaults.set(newValue.rawValue, forKey: DefaultsKey.onboardingState)
        }
    }

    var congregationId: UUID? {
        get {
            guard let raw = defaults.string(forKey: DefaultsKey.congregationId) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: DefaultsKey.congregationId)
        }
    }

    var linkedPublisherId: UUID? {
        get {
            guard let raw = defaults.string(forKey: DefaultsKey.linkedPublisherId) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: DefaultsKey.linkedPublisherId)
        }
    }

    var directoryScope: DirectoryScope {
        get {
            guard let raw = defaults.string(forKey: DefaultsKey.directoryScope),
                  let scope = DirectoryScope(rawValue: raw) else {
                return .lite
            }
            return scope
        }
        set {
            defaults.set(newValue.rawValue, forKey: DefaultsKey.directoryScope)
        }
    }

    var elderDeviceId: UUID? {
        get {
            guard let raw = defaults.string(forKey: DefaultsKey.elderDeviceId) else { return nil }
            return UUID(uuidString: raw)
        }
        set {
            defaults.set(newValue?.uuidString, forKey: DefaultsKey.elderDeviceId)
        }
    }

    var lastSuccessfulSync: Date? {
        get { defaults.object(forKey: DefaultsKey.lastSuccessfulSync) as? Date }
        set { defaults.set(newValue, forKey: DefaultsKey.lastSuccessfulSync) }
    }

    var isLinked: Bool {
        onboardingState == .linked && linkedPublisherId != nil
    }

    // MARK: - Fingerprint

    func deviceFingerprint() -> [String: String] {
        let screen = UIScreen.main.bounds
        return [
            "os": "iOS",
            "os_version": UIDevice.current.systemVersion,
            "screen_width": String(format: "%.0f", screen.width),
            "screen_height": String(format: "%.0f", screen.height),
        ]
    }

    // MARK: - Mutations

    func markPendingApproval(congregationId: UUID, elderDeviceId: UUID) {
        self.congregationId = congregationId
        self.elderDeviceId = elderDeviceId
        onboardingState = .pendingApproval
    }

    func markLinked(publisherId: UUID, scope: DirectoryScope) {
        linkedPublisherId = publisherId
        directoryScope = scope
        onboardingState = .linked
    }

    func bootstrapAsElder(publisherId: UUID, congregationId: UUID) {
        self.congregationId = congregationId
        markLinked(publisherId: publisherId, scope: .full)
    }

    func resetOnboarding() {
        congregationId = nil
        linkedPublisherId = nil
        elderDeviceId = nil
        directoryScope = .lite
        onboardingState = .fresh
    }

    // MARK: - Keychain

    private func saveDeviceIdToKeychain(_ id: UUID) throws {
        let data = id.uuidString.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw DeviceIdentityError.keychainFailure(status)
        }
    }

    private func loadDeviceIdFromKeychain() -> UUID? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: Self.keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: string) else {
            return nil
        }
        return uuid
    }
}
