//
//  MnemonicService.swift
//  Wpayin_Wallet
//
//  Created by OpenAI Codex on 26.09.2025.
//

import Foundation
import WalletCore

enum MnemonicServiceError: LocalizedError {
    case generationFailed
    case invalidMnemonic
    case derivationFailed
    case invalidPrivateKey
    case addressDerivationFailed

    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate mnemonic phrase."
        case .invalidMnemonic:
            return "The provided mnemonic phrase is invalid."
        case .derivationFailed:
            return "Unable to derive keys from the mnemonic."
        case .invalidPrivateKey:
            return "The provided private key is invalid."
        case .addressDerivationFailed:
            return "Could not derive a wallet address from the supplied credentials."
        }
    }
}

/// Wrapper around Trust Wallet Core helpers required for seed and key derivation.
final class MnemonicService {
    private let passphrase: String = ""

    func generateMnemonic(strength: Int = 128) throws -> String {
        guard let wallet = HDWallet(strength: Int32(strength), passphrase: passphrase) else {
            throw MnemonicServiceError.generationFailed
        }
        return wallet.mnemonic
    }

    func normalizeMnemonic(_ mnemonic: String) -> String {
        mnemonic
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func isValidMnemonic(_ mnemonic: String) -> Bool {
        let normalized = normalizeMnemonic(mnemonic)
        return HDWallet(mnemonic: normalized, passphrase: passphrase) != nil
    }

    func loadWallet(from mnemonic: String) throws -> HDWallet {
        let normalized = normalizeMnemonic(mnemonic)
        guard let wallet = HDWallet(mnemonic: normalized, passphrase: passphrase) else {
            throw MnemonicServiceError.invalidMnemonic
        }
        return wallet
    }

    func address(for coin: CoinType, wallet: HDWallet) -> String {
        wallet.getAddressForCoin(coin: coin)
    }

    // Derive address with custom account index (for multi-account support)
    func address(for coin: CoinType, wallet: HDWallet, accountIndex: Int) -> String {
        // Use wallet's getDerivedKey to get the private key at the specific account index
        let privateKey = wallet.getDerivedKey(coin: coin, account: 0, change: 0, address: UInt32(accountIndex))

        // Use compressed public key for coins that require it (Bitcoin, etc.)
        // Ethereum works with both, but compressed is more standard
        let publicKey = privateKey.getPublicKeySecp256k1(compressed: true)
        let address = AnyAddress(publicKey: publicKey, coin: coin)
        return address.description
    }

    func privateKeyHex(for coin: CoinType, wallet: HDWallet) -> String {
        let key = wallet.getKeyForCoin(coin: coin)
        return "0x" + key.data.hexString
    }

    func normalizePrivateKey(_ privateKey: String) throws -> String {
        var hex = privateKey.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if hex.hasPrefix("0x") {
            hex.removeFirst(2)
        }

        guard let data = Data(hexString: hex), data.count == 32 else {
            throw MnemonicServiceError.invalidPrivateKey
        }

        return "0x" + data.hexString
    }

    func deriveEthereumAddress(fromPrivateKey privateKey: String) throws -> String {
        let normalized = try normalizePrivateKey(privateKey)
        let stripped = String(normalized.dropFirst(2))
        guard let keyData = Data(hexString: stripped) else {
            throw MnemonicServiceError.invalidPrivateKey
        }

        guard let privateKey = PrivateKey(data: keyData) else {
            throw MnemonicServiceError.invalidPrivateKey
        }

        // Use compressed public key for consistency and compatibility
        let publicKey = privateKey.getPublicKeySecp256k1(compressed: true)
        let address = AnyAddress(publicKey: publicKey, coin: .ethereum)
        return address.description.lowercased()
    }
}
