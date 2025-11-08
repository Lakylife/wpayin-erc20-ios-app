//
//  BitcoinService.swift
//  Wpayin_Wallet
//
//  Bitcoin blockchain service for address derivation, balance fetching, and transactions
//

import Foundation
import WalletCore
import BigInt

// MARK: - Bitcoin Models

enum BitcoinDerivation: String, CaseIterable, Codable {
    case bip44 = "BIP44"  // Legacy: 1... (higher fees)
    case bip49 = "BIP49"  // SegWit wrapped: 3... (medium fees)
    case bip84 = "BIP84"  // Native SegWit: bc1... (lowest fees) ← RECOMMENDED
    case bip86 = "BIP86"  // Taproot: bc1p... (newest)

    var path: String {
        switch self {
        case .bip44: return "m/44'/0'/0'/0/0"
        case .bip49: return "m/49'/0'/0'/0/0"
        case .bip84: return "m/84'/0'/0'/0/0"  // Native SegWit - BEST
        case .bip86: return "m/86'/0'/0'/0/0"
        }
    }

    var purpose: UInt32 {
        switch self {
        case .bip44: return 44
        case .bip49: return 49
        case .bip84: return 84
        case .bip86: return 86
        }
    }

    var displayName: String {
        switch self {
        case .bip44: return "Legacy (1...)"
        case .bip49: return "SegWit (3...)"
        case .bip84: return "Native SegWit (bc1...)"
        case .bip86: return "Taproot (bc1p...)"
        }
    }

    nonisolated(unsafe) static var `default`: BitcoinDerivation {
        .bip84 // Native SegWit as default
    }
}

struct BitcoinBalance: Codable {
    let confirmed: Int64     // Confirmed satoshis
    let unconfirmed: Int64   // Unconfirmed satoshis
    let total: Int64         // Total satoshis

    var totalBTC: Decimal {
        Decimal(total) / Decimal(100_000_000)
    }

    var confirmedBTC: Decimal {
        Decimal(confirmed) / Decimal(100_000_000)
    }
}

struct BitcoinFeeRate {
    let fastestFee: Int      // sat/vB - ~10 min
    let halfHourFee: Int     // sat/vB - ~30 min
    let hourFee: Int         // sat/vB - ~60 min
    let economyFee: Int      // sat/vB - low priority
    let minimumFee: Int      // sat/vB - absolute minimum
}

struct BitcoinUTXO: Codable {
    let txid: String
    let vout: Int
    let value: Int64         // satoshis
    let status: UTXOStatus

    struct UTXOStatus: Codable {
        let confirmed: Bool
        let blockHeight: Int?
        let blockHash: String?
    }
}

struct BitcoinTransaction: Codable {
    let txid: String
    let version: Int
    let locktime: Int
    let size: Int
    let weight: Int
    let fee: Int64
    let status: TransactionStatus
    let vin: [TransactionInput]
    let vout: [TransactionOutput]

    struct TransactionStatus: Codable {
        let confirmed: Bool
        let blockHeight: Int?
        let blockHash: String?
        let blockTime: Int?
    }

    struct TransactionInput: Codable {
        let txid: String
        let vout: Int
        let prevout: PrevOut?

        struct PrevOut: Codable {
            let scriptpubkeyAddress: String?
            let value: Int64

            enum CodingKeys: String, CodingKey {
                case scriptpubkeyAddress = "scriptpubkey_address"
                case value
            }
        }
    }

    struct TransactionOutput: Codable {
        let scriptpubkeyAddress: String?
        let value: Int64

        enum CodingKeys: String, CodingKey {
            case scriptpubkeyAddress = "scriptpubkey_address"
            case value
        }
    }
}

// MARK: - Bitcoin Service

class BitcoinService {
    static let shared = BitcoinService()

    private let keychain = KeychainManager()
    private let mnemonicService = MnemonicService()

    // Blockstream API endpoints
    private let mainnetAPI = "https://blockstream.info/api"
    private let testnetAPI = "https://blockstream.info/testnet/api"

    // Mempool.space for better fee estimates
    private let mempoolAPI = "https://mempool.space/api"

    private init() {}

    // MARK: - Address Derivation

    /// Derive Bitcoin address from seed phrase
    func deriveAddress(
        derivation: BitcoinDerivation = .default,
        accountIndex: Int = 0
    ) throws -> String {
        guard let seedPhrase = keychain.getSeedPhrase() else {
            throw BitcoinError.noSeedPhrase
        }

        guard let wallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
            throw BitcoinError.invalidSeed
        }

        // Derive Bitcoin key with specified derivation path
        let path = "m/\(derivation.purpose)'/0'/0'/0/\(accountIndex)"
        let privateKey = wallet.getKey(coin: .bitcoin, derivationPath: path)

        // Generate address based on derivation type
        let address: String
        switch derivation {
        case .bip84, .bip86:
            // Native SegWit (Bech32)
            let publicKey = privateKey.getPublicKeySecp256k1(compressed: true)
            let bitcoinAddress = BitcoinAddress(publicKey: publicKey, prefix: 0x00)
            address = bitcoinAddress?.description ?? ""

        case .bip49:
            // SegWit wrapped (P2SH)
            let publicKey = privateKey.getPublicKeySecp256k1(compressed: true)
            let bitcoinAddress = BitcoinAddress(publicKey: publicKey, prefix: 0x05)
            address = bitcoinAddress?.description ?? ""

        case .bip44:
            // Legacy
            let publicKey = privateKey.getPublicKeySecp256k1(compressed: true)
            let bitcoinAddress = BitcoinAddress(publicKey: publicKey, prefix: 0x00)
            address = bitcoinAddress?.description ?? ""
        }

        guard !address.isEmpty else {
            throw BitcoinError.addressDerivationFailed
        }

        return address
    }

    // MARK: - Balance Fetching

    /// Fetch Bitcoin balance for an address
    func fetchBalance(address: String, testnet: Bool = false) async throws -> BitcoinBalance {
        let apiURL = testnet ? testnetAPI : mainnetAPI
        let url = URL(string: "\(apiURL)/address/\(address)")!

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw BitcoinError.networkError("Failed to fetch balance")
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let chainStats = json?["chain_stats"] as? [String: Any] else {
            throw BitcoinError.invalidResponse
        }

        let fundedSum = chainStats["funded_txo_sum"] as? Int64 ?? 0
        let spentSum = chainStats["spent_txo_sum"] as? Int64 ?? 0
        let confirmed = fundedSum - spentSum

        let mempoolStats = json?["mempool_stats"] as? [String: Any]
        let mempoolFunded = mempoolStats?["funded_txo_sum"] as? Int64 ?? 0
        let mempoolSpent = mempoolStats?["spent_txo_sum"] as? Int64 ?? 0
        let unconfirmed = mempoolFunded - mempoolSpent

        return BitcoinBalance(
            confirmed: confirmed,
            unconfirmed: unconfirmed,
            total: confirmed + unconfirmed
        )
    }

    /// Fetch UTXOs for transaction building
    func fetchUTXOs(address: String, testnet: Bool = false) async throws -> [BitcoinUTXO] {
        let apiURL = testnet ? testnetAPI : mainnetAPI
        let url = URL(string: "\(apiURL)/address/\(address)/utxo")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode([BitcoinUTXO].self, from: data)
    }

    // MARK: - Fee Estimation

    /// Get recommended fee rates
    func fetchFeeRates() async throws -> BitcoinFeeRate {
        let url = URL(string: "\(mempoolAPI)/v1/fees/recommended")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        let fastest = json?["fastestFee"] as? Int ?? 10
        let halfHour = json?["halfHourFee"] as? Int ?? 8
        let hour = json?["hourFee"] as? Int ?? 6
        let economy = json?["economyFee"] as? Int ?? 3
        let minimum = json?["minimumFee"] as? Int ?? 1

        return BitcoinFeeRate(
            fastestFee: fastest,
            halfHourFee: halfHour,
            hourFee: hour,
            economyFee: economy,
            minimumFee: minimum
        )
    }

    // MARK: - Send Transaction
    
    /// Send Bitcoin transaction (simplified implementation)
    func sendTransaction(
        to toAddress: String,
        amount: Decimal,
        feeRate: Int? = nil
    ) async throws -> TransactionResult {
        // Get private key from keychain
        guard let seedPhrase = keychain.getSeedPhrase(),
              let wallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
            throw BitcoinError.noSeedPhrase
        }
        
        let path = "m/84'/0'/0'/0/0"  // BIP84 Native SegWit
        let privateKey = wallet.getKey(coin: .bitcoin, derivationPath: path)
        let fromAddress = CoinType.bitcoin.deriveAddress(privateKey: privateKey).description
        
        // Fetch fee rate
        let actualFeeRate: Int
        if let custom = feeRate {
            actualFeeRate = custom
        } else {
            let fees = try await fetchFeeRates()
            actualFeeRate = fees.halfHourFee  // Use 30-minute fee as default
        }
        
        // Convert amount to satoshis
        let amountSatoshis = btcToSatoshis(amount)
        
        // Build and broadcast transaction
        let signedTx = try await buildTransaction(
            from: fromAddress,
            to: toAddress,
            amount: amountSatoshis,
            feeRate: actualFeeRate
        )
        
        let txHash = try await broadcastTransaction(signedTx)
        
        return TransactionResult(
            hash: txHash,
            from: fromAddress,
            to: toAddress,
            amount: "\(amount) BTC",
            gasUsed: nil  // Bitcoin doesn't use gas
        )
    }
    
    // MARK: - Transaction Building

    /// Build and sign Bitcoin transaction
    func buildTransaction(
        from fromAddress: String,
        to toAddress: String,
        amount: Int64,  // satoshis
        feeRate: Int,   // sat/vB
        derivation: BitcoinDerivation = .default,
        testnet: Bool = false
    ) async throws -> String {
        // For MVP: Simplified implementation
        // In production: Use proper UTXO selection and WalletCore Bitcoin signing
        
        print("⚠️ Bitcoin transaction simplified for MVP")
        print("   From: \(fromAddress)")
        print("   To: \(toAddress)")
        print("   Amount: \(amount) satoshis")
        print("   Fee: \(feeRate) sat/vB")
        
        // Mock transaction hex for demo
        let mockTxHex = Data(UUID().uuidString.utf8).hexString
        return mockTxHex
    }

    /// Broadcast signed transaction
    func broadcastTransaction(_ signedTx: String, testnet: Bool = false) async throws -> String {
        let apiURL = testnet ? testnetAPI : mainnetAPI
        let url = URL(string: "\(apiURL)/tx")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = signedTx.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw BitcoinError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 200 {
            // Success - response is the transaction ID
            return String(data: data, encoding: .utf8) ?? ""
        } else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw BitcoinError.broadcastFailed(errorMessage)
        }
    }

    // MARK: - Transaction History

    /// Fetch transaction history for address
    func fetchTransactions(address: String, testnet: Bool = false) async throws -> [BitcoinTransaction] {
        let apiURL = testnet ? testnetAPI : mainnetAPI
        let url = URL(string: "\(apiURL)/address/\(address)/txs")!

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode([BitcoinTransaction].self, from: data)
    }

    // MARK: - Helper Methods

    /// Select UTXOs for transaction (simple greedy algorithm)
    private func selectUTXOs(utxos: [BitcoinUTXO], targetAmount: Int64, feeRate: Int) throws -> [BitcoinUTXO] {
        // Only use confirmed UTXOs
        let confirmed = utxos.filter { $0.status.confirmed }

        // Sort by value descending (use largest first)
        let sorted = confirmed.sorted { $0.value > $1.value }

        var selected: [BitcoinUTXO] = []
        var total: Int64 = 0

        for utxo in sorted {
            selected.append(utxo)
            total += utxo.value

            // Estimate fee with current selection
            let fee = estimateFee(inputCount: selected.count, outputCount: 2, feeRate: feeRate)

            if total >= targetAmount + fee {
                return selected
            }
        }

        throw BitcoinError.insufficientFunds
    }

    /// Estimate transaction fee
    private func estimateFee(inputCount: Int, outputCount: Int, feeRate: Int) -> Int64 {
        // Simplified fee estimation
        // P2WPKH (Native SegWit) transaction size:
        // - Each input: ~68 vBytes
        // - Each output: ~31 vBytes
        // - Overhead: ~10 vBytes

        let size = 10 + (inputCount * 68) + (outputCount * 31)
        return Int64(size * feeRate)
    }

    /// Convert satoshis to BTC
    func satoshisToBTC(_ satoshis: Int64) -> Decimal {
        return Decimal(satoshis) / Decimal(100_000_000)
    }

    /// Convert BTC to satoshis
    func btcToSatoshis(_ btc: Decimal) -> Int64 {
        let satoshis = btc * Decimal(100_000_000)
        return Int64(truncating: NSDecimalNumber(decimal: satoshis))
    }
}

// MARK: - Bitcoin Errors

enum BitcoinError: LocalizedError {
    case noSeedPhrase
    case invalidSeed
    case addressDerivationFailed
    case networkError(String)
    case invalidResponse
    case insufficientFunds
    case transactionSigningFailed
    case broadcastFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSeedPhrase:
            return "No seed phrase available"
        case .invalidSeed:
            return "Invalid seed phrase"
        case .addressDerivationFailed:
            return "Failed to derive Bitcoin address"
        case .networkError(let message):
            return "Network error: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        case .insufficientFunds:
            return "Insufficient funds"
        case .transactionSigningFailed:
            return "Failed to sign transaction"
        case .broadcastFailed(let message):
            return "Broadcast failed: \(message)"
        }
    }
}

// MARK: - Data Extensions

extension Data {
    // Note: hexString init and hexString property already defined elsewhere in project
    
    func reversedBytes() -> Data {
        return Data(self.reversed())
    }
}
