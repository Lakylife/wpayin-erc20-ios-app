// Autor Lukas Helebrandt, 2026

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
        if accountIndex == 0 {
            // Default derivation per coin (BIP84 bech32 for Bitcoin, ed25519 for
            // Solana, BIP44 for EVM) — matches what signing services use to spend.
            return wallet.getAddressForCoin(coin: coin)
        }

        let privateKey = wallet.getKey(coin: coin, derivationPath: derivationPath(for: coin, accountIndex: accountIndex))
        // getPublicKey(coinType:) picks the correct curve for the coin
        // (ed25519 for Solana, secp256k1 for Bitcoin/EVM).
        let publicKey = privateKey.getPublicKey(coinType: coin)
        return AnyAddress(publicKey: publicKey, coin: coin).description
    }

    /// Derivation path for a given account index, consistent with spending paths.
    func derivationPath(for coin: CoinType, accountIndex: Int) -> String {
        switch coin {
        case .bitcoin:
            return "m/84'/0'/0'/0/\(accountIndex)" // Native SegWit (BIP84)
        case .litecoin:
            return "m/84'/2'/0'/0/\(accountIndex)"
        case .solana:
            return "m/44'/501'/\(accountIndex)'/0'"
        default:
            return "m/44'/\(coin.slip44Id)'/0'/0/\(accountIndex)"
        }
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
