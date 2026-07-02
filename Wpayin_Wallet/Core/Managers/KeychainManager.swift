// Autor Lukas Helebrandt, 2026

//
//  KeychainManager.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation
import Security

class KeychainManager {
    private let service = "WpayinWallet"
    private let privateKeyKey = "PrivateKey"
    private let seedPhraseKey = "SeedPhrase"

    init() {
        // One-time hardening of items stored before accessibility was enforced.
        migrateAccessibilityIfNeeded()
    }

    private func store(_ value: String, account: String) -> Bool {
        let data = Data(value.utf8)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // ThisDeviceOnly: secrets never leave this device via backup/restore
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    private func migrateAccessibilityIfNeeded() {
        let migrationKey = "KeychainAccessibilityMigrated_v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        for account in [privateKeyKey, seedPhraseKey] {
            let query: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            let attributes: [String: Any] = [
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            ]
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        }

        UserDefaults.standard.set(true, forKey: migrationKey)
    }

    func storePrivateKey(_ privateKey: String) -> Bool {
        store(privateKey, account: privateKeyKey)
    }

    func storeSeedPhrase(_ seedPhrase: String) -> Bool {
        store(seedPhrase, account: seedPhraseKey)
    }

    func getPrivateKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let privateKey = String(data: data, encoding: .utf8) else {
            return nil
        }

        return privateKey
    }

    func getSeedPhrase() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: seedPhraseKey,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let seedPhrase = String(data: data, encoding: .utf8) else {
            return nil
        }

        return seedPhrase
    }

    func hasPrivateKey() -> Bool {
        return getPrivateKey() != nil
    }

    func hasSeedPhrase() -> Bool {
        return getSeedPhrase() != nil
    }

    func deletePrivateKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyKey
        ]

        SecItemDelete(query as CFDictionary)
    }

    func deleteSeedPhrase() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: seedPhraseKey
        ]

        SecItemDelete(query as CFDictionary)
    }
}
