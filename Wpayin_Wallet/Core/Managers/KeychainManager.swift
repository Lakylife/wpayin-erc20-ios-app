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

    private func seedPhraseAccount(for identifier: String) -> String {
        "SeedPhrase.\(identifier)"
    }

    private func privateKeyAccount(for identifier: String) -> String {
        "PrivateKey.\(identifier)"
    }

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

    private func value(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
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

    /// Wallet-scoped secrets allow multiple independent wallets to coexist.
    /// The legacy unscoped slots remain the active signing identity so the
    /// transaction services do not need to know about the wallet list.
    func storeSeedPhrase(_ seedPhrase: String, identifier: String) -> Bool {
        store(seedPhrase, account: seedPhraseAccount(for: identifier))
    }

    func storePrivateKey(_ privateKey: String, identifier: String) -> Bool {
        store(privateKey, account: privateKeyAccount(for: identifier))
    }

    func getSeedPhrase(identifier: String) -> String? {
        value(account: seedPhraseAccount(for: identifier))
    }

    func getPrivateKey(identifier: String) -> String? {
        value(account: privateKeyAccount(for: identifier))
    }

    func deleteSeedPhrase(identifier: String) {
        delete(account: seedPhraseAccount(for: identifier))
    }

    func deletePrivateKey(identifier: String) {
        delete(account: privateKeyAccount(for: identifier))
    }

    func getPrivateKey() -> String? {
        value(account: privateKeyKey)
    }

    func getSeedPhrase() -> String? {
        value(account: seedPhraseKey)
    }

    func hasPrivateKey() -> Bool {
        return getPrivateKey() != nil
    }

    func hasSeedPhrase() -> Bool {
        return getSeedPhrase() != nil
    }

    func deletePrivateKey() {
        delete(account: privateKeyKey)
    }

    func deleteSeedPhrase() {
        delete(account: seedPhraseKey)
    }
}
