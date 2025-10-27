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

    func storePrivateKey(_ privateKey: String) -> Bool {
        let data = Data(privateKey.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: privateKeyKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    func storeSeedPhrase(_ seedPhrase: String) -> Bool {
        let data = Data(seedPhrase.utf8)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: seedPhraseKey,
            kSecValueData as String: data
        ]

        SecItemDelete(query as CFDictionary)

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
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
