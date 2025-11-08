//
//  TransactionService.swift
//  Wpayin_Wallet
//
//  Service for creating and sending blockchain transactions
//

import Foundation
import WalletCore
import BigInt

// Helper extension for Decimal rounding
extension Decimal {
    func rounded(_ scale: Int = 0, _ roundingMode: NSDecimalNumber.RoundingMode = .plain) -> Decimal {
        var result = Decimal()
        var localCopy = self
        NSDecimalRound(&result, &localCopy, scale, roundingMode)
        return result
    }
}

// Helper for pow with Decimal
func pow(_ base: Decimal, _ exponent: Int) -> Decimal {
    return NSDecimalNumber(decimal: base).raising(toPower: exponent).decimalValue
}

enum TransactionError: LocalizedError {
    case invalidAddress
    case invalidAmount
    case insufficientBalance
    case insufficientGas
    case failedToCreateTransaction
    case failedToSignTransaction
    case failedToSendTransaction
    case noPrivateKey
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "Invalid recipient address"
        case .invalidAmount:
            return "Invalid amount"
        case .insufficientBalance:
            return "Insufficient balance"
        case .insufficientGas:
            return "Insufficient gas for transaction"
        case .failedToCreateTransaction:
            return "Failed to create transaction"
        case .failedToSignTransaction:
            return "Failed to sign transaction"
        case .failedToSendTransaction:
            return "Failed to send transaction"
        case .noPrivateKey:
            return "No private key available"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

struct TransactionResult {
    let hash: String
    let from: String
    let to: String
    let amount: String
    let gasUsed: String?
}

class TransactionService {
    static let shared = TransactionService()

    private let keychain = KeychainManager()
    private let mnemonicService = MnemonicService()
    private let networkManager = NetworkManager.shared
    private let gasPriceService = GasPriceService.shared

    private init() {}

    // MARK: - EVM Transaction Methods

    /// Send native EVM token (ETH, BNB, MATIC, etc.)
    func sendEvmNativeToken(
        to recipientAddress: String,
        amount: Decimal,
        blockchain: BlockchainType,
        customGasPrice: GasPrice? = nil,
        gasLimit: Int = 21000
    ) async throws -> TransactionResult {
        // Get private key
        guard let privateKeyData = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }

        // Validate address
        guard recipientAddress.hasPrefix("0x"), recipientAddress.count == 42 else {
            throw TransactionError.invalidAddress
        }

        // Get chain ID and RPC URL from NetworkManager
        let networkConfig = networkManager.configuration(for: blockchain)
        let chainId = networkConfig.chainId
        let rpcUrl = networkConfig.currentRPCUrl

        // Get nonce from network
        let fromAddress = try deriveAddress(from: privateKeyData, blockchain: blockchain)
        let nonce = try await fetchNonce(address: fromAddress, rpcUrl: rpcUrl)

        // Get gas price using GasPriceService (EIP-1559 or Legacy)
        let gasPriceEstimate: GasPrice
        if let custom = customGasPrice {
            gasPriceEstimate = custom
        } else {
            let estimate = try await gasPriceService.getGasPrice(for: blockchain)
            gasPriceEstimate = estimate.recommended
        }

        // Convert amount to wei
        let decimals = blockchain.nativeDecimals
        let amountInWei = (amount * pow(Decimal(10), decimals)).rounded()
        let valueInWei = BigUInt(amountInWei.description) ?? BigUInt(0)

        // Extract gas price in Wei (use maxFee for EIP-1559)
        let gasPriceInWei: BigUInt
        switch gasPriceEstimate {
        case .legacy(let price):
            gasPriceInWei = BigUInt(price)
        case .eip1559(let maxFee, _):
            gasPriceInWei = BigUInt(maxFee)
        }

        // Sign transaction using simple ECDSA
        let signedTransaction = try signTransaction(
            from: fromAddress,
            to: recipientAddress,
            value: valueInWei,
            gasPrice: gasPriceInWei,
            gasLimit: BigUInt(gasLimit),
            nonce: BigUInt(nonce),
            data: Data(),
            chainId: chainId,
            privateKey: privateKeyData
        )

        // Send transaction to network
        let txHash = try await broadcastTransaction(signedTx: signedTransaction, rpcUrl: rpcUrl)

        return TransactionResult(
            hash: txHash,
            from: fromAddress,
            to: recipientAddress,
            amount: String(describing: amount),
            gasUsed: String(gasLimit)
        )
    }

    /// Send ERC-20 token
    func sendErc20Token(
        tokenAddress: String,
        to recipientAddress: String,
        amount: Decimal,
        decimals: Int,
        blockchain: BlockchainType,
        customGasPrice: GasPrice? = nil,
        gasLimit: Int = 65000
    ) async throws -> TransactionResult {
        // Get private key
        guard let privateKeyData = try getPrivateKey(for: blockchain) else {
            throw TransactionError.noPrivateKey
        }

        // Validate addresses
        guard recipientAddress.hasPrefix("0x"), recipientAddress.count == 42 else {
            throw TransactionError.invalidAddress
        }
        guard tokenAddress.hasPrefix("0x"), tokenAddress.count == 42 else {
            throw TransactionError.invalidAddress
        }

        // Get chain ID and RPC URL from NetworkManager
        let networkConfig = networkManager.configuration(for: blockchain)
        let chainId = networkConfig.chainId
        let rpcUrl = networkConfig.currentRPCUrl

        // Get nonce from network
        let fromAddress = try deriveAddress(from: privateKeyData, blockchain: blockchain)
        let nonce = try await fetchNonce(address: fromAddress, rpcUrl: rpcUrl)

        // Get gas price using GasPriceService
        let gasPriceEstimate: GasPrice
        if let custom = customGasPrice {
            gasPriceEstimate = custom
        } else {
            let estimate = try await gasPriceService.getGasPrice(for: blockchain)
            gasPriceEstimate = estimate.recommended
        }

        // Convert amount to token's smallest unit
        let amountInSmallestUnit = (amount * pow(Decimal(10), decimals)).rounded()
        let amountBigUInt = BigUInt(amountInSmallestUnit.description) ?? BigUInt(0)

        // Create ERC-20 transfer data
        let transferData = createERC20TransferData(to: recipientAddress, amount: amountBigUInt)

        // Extract gas price in Wei
        let gasPriceInWei: BigUInt
        switch gasPriceEstimate {
        case .legacy(let price):
            gasPriceInWei = BigUInt(price)
        case .eip1559(let maxFee, _):
            gasPriceInWei = BigUInt(maxFee)
        }

        // Sign transaction
        let signedTransaction = try signTransaction(
            from: fromAddress,
            to: tokenAddress, // Send to token contract
            value: BigUInt(0), // 0 ETH for ERC-20 transfer
            gasPrice: gasPriceInWei,
            gasLimit: BigUInt(gasLimit),
            nonce: BigUInt(nonce),
            data: transferData,
            chainId: chainId,
            privateKey: privateKeyData
        )

        // Send transaction to network
        let txHash = try await broadcastTransaction(signedTx: signedTransaction, rpcUrl: rpcUrl)

        return TransactionResult(
            hash: txHash,
            from: fromAddress,
            to: recipientAddress,
            amount: String(describing: amount),
            gasUsed: String(gasLimit)
        )
    }

    /// Estimate gas for a transaction
    func estimateGas(
        to recipientAddress: String,
        amount: Decimal,
        blockchain: BlockchainType,
        tokenAddress: String? = nil,
        decimals: Int = 18
    ) async throws -> (gasLimit: Int, gasPrice: Decimal) {
        let rpcUrl = blockchain.rpcUrl

        // Fetch current gas price
        let gasPrice = try await fetchGasPrice(rpcUrl: rpcUrl)

        // Estimate gas limit based on transaction type
        let gasLimit: Int
        if tokenAddress != nil {
            gasLimit = 65000 // ERC-20 transfer
        } else {
            gasLimit = 21000 // Native token transfer
        }

        return (gasLimit: gasLimit, gasPrice: gasPrice)
    }

    // MARK: - Private Helper Methods

    private func getPrivateKey(for blockchain: BlockchainType) throws -> Data? {
        if let seedPhrase = keychain.getSeedPhrase() {
            // Derive private key from seed phrase
            guard let wallet = try? mnemonicService.loadWallet(from: seedPhrase) else {
                return nil
            }

            guard let coinType = blockchain.coinType else {
                return nil
            }

            let privateKey = wallet.getKey(coin: coinType, derivationPath: blockchain.derivationPath)
            return privateKey.data
        } else if let privateKeyHex = keychain.getPrivateKey() {
            // Use existing private key
            return Data(hexString: privateKeyHex)
        }

        return nil
    }

    private func deriveAddress(from privateKeyData: Data, blockchain: BlockchainType) throws -> String {
        guard let coinType = blockchain.coinType else {
            throw TransactionError.failedToCreateTransaction
        }

        let privateKey = PrivateKey(data: privateKeyData)!
        let address = coinType.deriveAddress(privateKey: privateKey)

        return address.description
    }

    private func signTransaction(
        from: String,
        to: String,
        value: BigUInt,
        gasPrice: BigUInt,
        gasLimit: BigUInt,
        nonce: BigUInt,
        data: Data,
        chainId: Int,
        privateKey: Data
    ) throws -> String {
        // Create transaction fields for RLP encoding
        var rlpItems: [Any] = []

        // Add nonce
        rlpItems.append(nonce.serialize())

        // Add gas price
        rlpItems.append(gasPrice.serialize())

        // Add gas limit
        rlpItems.append(gasLimit.serialize())

        // Add to address
        let toData = Data(hexString: String(to.dropFirst(2)))!
        rlpItems.append(toData)

        // Add value
        rlpItems.append(value.serialize())

        // Add data
        rlpItems.append(data)

        // Add chain ID for EIP-155
        rlpItems.append(BigUInt(chainId).serialize())
        rlpItems.append(Data())
        rlpItems.append(Data())

        // RLP encode (simplified - in production use proper RLP library)
        let txHash = keccak256(rlpEncode(rlpItems))

        // Sign with private key
        guard let privKey = PrivateKey(data: privateKey) else {
            throw TransactionError.noPrivateKey
        }

        let signature = privKey.sign(digest: txHash, curve: .secp256k1)!

        // Extract r, s, v from signature
        let r = signature.dropLast(1).prefix(32)
        let s = signature.dropLast(1).suffix(32)
        let v = BigUInt(chainId * 2 + 35 + Int(signature.last ?? 0))

        // Re-encode with signature
        var signedItems: [Any] = []
        signedItems.append(nonce.serialize())
        signedItems.append(gasPrice.serialize())
        signedItems.append(gasLimit.serialize())
        signedItems.append(toData)
        signedItems.append(value.serialize())
        signedItems.append(data)
        signedItems.append(v.serialize())
        signedItems.append(r)
        signedItems.append(s)

        let signedTx = rlpEncode(signedItems)
        return signedTx.hexString
    }

    private func keccak256(_ data: Data) -> Data {
        // Use WalletCore's Hash.keccak256
        return Hash.keccak256(data: data)
    }

    private func rlpEncode(_ items: [Any]) -> Data {
        // Simplified RLP encoding - in production use proper library
        var result = Data()

        for item in items {
            if let data = item as? Data {
                if data.count == 1 && data[0] < 0x80 {
                    result.append(data)
                } else if data.count < 56 {
                    result.append(UInt8(0x80 + data.count))
                    result.append(data)
                } else {
                    let lengthData = BigUInt(data.count).serialize()
                    result.append(UInt8(0xb7 + lengthData.count))
                    result.append(lengthData)
                    result.append(data)
                }
            }
        }

        // Wrap in list prefix
        if result.count < 56 {
            var final = Data([UInt8(0xc0 + result.count)])
            final.append(result)
            return final
        } else {
            let lengthData = BigUInt(result.count).serialize()
            var final = Data([UInt8(0xf7 + lengthData.count)])
            final.append(lengthData)
            final.append(result)
            return final
        }
    }

    private func createERC20TransferData(to address: String, amount: BigUInt) -> Data {
        // ERC-20 transfer function selector: 0xa9059cbb
        var data = Data(hexString: "a9059cbb")!

        // Recipient address (32 bytes, left-padded)
        let addressData = Data(hexString: String(address.dropFirst(2)))! // Remove "0x"
        var paddedAddress = Data(repeating: 0, count: 12)
        paddedAddress.append(addressData)
        data.append(paddedAddress)

        // Amount (32 bytes, left-padded)
        let amountData = amount.serialize()
        var paddedAmount = Data(repeating: 0, count: max(0, 32 - amountData.count))
        paddedAmount.append(amountData)
        data.append(paddedAmount)

        return data
    }

    // MARK: - Network Methods

    private func fetchNonce(address: String, rpcUrl: String) async throws -> Int {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getTransactionCount",
            "params": [address, "latest"],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? String else {
            throw TransactionError.networkError("Failed to fetch nonce")
        }

        // Convert hex to int
        let hexString = result.hasPrefix("0x") ? String(result.dropFirst(2)) : result
        return Int(hexString, radix: 16) ?? 0
    }

    private func fetchGasPrice(rpcUrl: String) async throws -> Decimal {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_gasPrice",
            "params": [],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? String else {
            throw TransactionError.networkError("Failed to fetch gas price")
        }

        // Convert hex to decimal (result is in Wei, convert to Gwei)
        let hexString = result.hasPrefix("0x") ? String(result.dropFirst(2)) : result
        guard let weiValue = Int(hexString, radix: 16) else {
            return 20 // Default 20 Gwei
        }

        return Decimal(weiValue) / pow(10, 9) // Convert Wei to Gwei
    }

    private func broadcastTransaction(signedTx: String, rpcUrl: String) async throws -> String {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_sendRawTransaction",
            "params": ["0x" + signedTx],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        if let error = json?["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw TransactionError.networkError(message)
        }

        guard let txHash = json?["result"] as? String else {
            throw TransactionError.failedToSendTransaction
        }

        return txHash
    }
}

// MARK: - Blockchain Extensions

extension BlockchainType {
    var chainId: Int? {
        switch self {
        case .ethereum:
            return 1
        case .bsc:
            return 56
        case .polygon:
            return 137
        case .avalanche:
            return 43114
        case .arbitrum:
            return 42161
        case .optimism:
            return 10
        case .base:
            return 8453
        default:
            return nil
        }
    }

    var rpcUrl: String {
        switch self {
        case .ethereum:
            return "https://eth.llamarpc.com"
        case .bsc:
            return "https://bsc-dataseed.binance.org"
        case .polygon:
            return "https://polygon-rpc.com"
        case .avalanche:
            return "https://api.avax.network/ext/bc/C/rpc"
        case .arbitrum:
            return "https://arb1.arbitrum.io/rpc"
        case .optimism:
            return "https://mainnet.optimism.io"
        case .base:
            return "https://mainnet.base.org"
        default:
            return "https://eth.llamarpc.com"
        }
    }

    var derivationPath: String {
        guard let coinType = self.coinType else {
            return "m/44'/60'/0'/0/0" // Default Ethereum path
        }
        return "m/44'/\(coinType.slip44Id)'/0'/0/0"
    }
}

// MARK: - Data Extensions

extension Data {
    init?(hexString: String) {
        let string = hexString.hasPrefix("0x") ? String(hexString.dropFirst(2)) : hexString
        let length = string.count / 2
        var data = Data(capacity: length)

        for i in 0..<length {
            let start = string.index(string.startIndex, offsetBy: i * 2)
            let end = string.index(start, offsetBy: 2)
            let substring = string[start..<end]

            if let byte = UInt8(substring, radix: 16) {
                data.append(byte)
            } else {
                return nil
            }
        }

        self = data
    }

    var hexString: String {
        return self.map { String(format: "%02x", $0) }.joined()
    }
}
