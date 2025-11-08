//
//  GasPriceService.swift
//  Wpayin_Wallet
//
//  Gas price management with EIP-1559 and Legacy support
//

import Foundation
import BigInt

// MARK: - Gas Price Models

enum GasPrice {
    case legacy(gasPrice: Int)  // Wei
    case eip1559(maxFeePerGas: Int, maxPriorityFeePerGas: Int)  // Wei

    var isEIP1559: Bool {
        if case .eip1559 = self {
            return true
        }
        return false
    }
}

enum GasPriceWarning {
    case tooLow       // Risk of transaction getting stuck
    case tooHigh      // Overpaying for gas
    case optimal      // Within safe range
}

struct GasPriceEstimate {
    let recommended: GasPrice
    let warning: GasPriceWarning
    let estimatedWaitTime: String  // e.g., "~30 seconds", "~2 minutes"

    // For UI display
    var formattedGasPrice: String {
        switch recommended {
        case .legacy(let gasPrice):
            let gwei = Decimal(gasPrice) / pow(10, 9)
            return String(format: "%.2f Gwei", NSDecimalNumber(decimal: gwei).doubleValue)

        case .eip1559(let maxFee, let priorityFee):
            let maxFeeGwei = Decimal(maxFee) / pow(10, 9)
            let priorityGwei = Decimal(priorityFee) / pow(10, 9)
            return String(format: "%.2f Gwei (%.2f priority)",
                          NSDecimalNumber(decimal: maxFeeGwei).doubleValue,
                          NSDecimalNumber(decimal: priorityGwei).doubleValue)
        }
    }
}

// MARK: - Gas Price Service

class GasPriceService {
    static let shared = GasPriceService()

    private let networkManager = NetworkManager.shared

    // Safety range bounds (90% - 150% of recommended)
    private let safeRangeLowerBound: Double = 0.9
    private let safeRangeUpperBound: Double = 1.5

    private init() {}

    // MARK: - Public Methods

    /// Get gas price for a blockchain
    func getGasPrice(for blockchain: BlockchainType) async throws -> GasPriceEstimate {
        let networkConfig = networkManager.configuration(for: blockchain)

        if networkConfig.supportsEIP1559 {
            return try await getEIP1559GasPrice(blockchain: blockchain, rpcUrl: networkConfig.currentRPCUrl)
        } else {
            return try await getLegacyGasPrice(blockchain: blockchain, rpcUrl: networkConfig.currentRPCUrl)
        }
    }

    /// Calculate total fee for a transaction
    func calculateTotalFee(gasLimit: Int, gasPrice: GasPrice) -> Decimal {
        switch gasPrice {
        case .legacy(let price):
            return Decimal(gasLimit) * Decimal(price)

        case .eip1559(let maxFee, _):
            return Decimal(gasLimit) * Decimal(maxFee)
        }
    }

    /// Convert Wei to Gwei
    func weiToGwei(_ wei: Int) -> Decimal {
        return Decimal(wei) / pow(10, 9)
    }

    /// Convert Gwei to Wei
    func gweiToWei(_ gwei: Decimal) -> Int {
        let wei = gwei * pow(10, 9)
        return NSDecimalNumber(decimal: wei).intValue
    }

    // MARK: - EIP-1559 Gas Price

    private func getEIP1559GasPrice(blockchain: BlockchainType, rpcUrl: String) async throws -> GasPriceEstimate {
        // Fetch base fee and priority fee from network
        let baseFee = try await fetchBaseFee(rpcUrl: rpcUrl)
        let priorityFee = try await fetchPriorityFee(rpcUrl: rpcUrl)

        // Calculate recommended max fee (base fee + priority fee with buffer)
        let maxFeePerGas = Int(Double(baseFee) * 2.0) + priorityFee

        // Apply minimum recommendations for safety
        let minPriorityFee = gweiToWei(1.5) // Minimum 1.5 Gwei priority fee
        let recommendedPriorityFee = max(priorityFee, minPriorityFee)
        let recommendedMaxFee = max(maxFeePerGas, baseFee + recommendedPriorityFee)

        let gasPrice = GasPrice.eip1559(
            maxFeePerGas: recommendedMaxFee,
            maxPriorityFeePerGas: recommendedPriorityFee
        )

        // Determine warning level
        let warning = determineWarning(
            actual: recommendedPriorityFee,
            recommended: priorityFee,
            isEIP1559: true
        )

        let waitTime = estimateWaitTime(priorityFee: recommendedPriorityFee)

        return GasPriceEstimate(
            recommended: gasPrice,
            warning: warning,
            estimatedWaitTime: waitTime
        )
    }

    // MARK: - Legacy Gas Price

    private func getLegacyGasPrice(blockchain: BlockchainType, rpcUrl: String) async throws -> GasPriceEstimate {
        // Fetch gas price from network
        let networkGasPrice = try await fetchLegacyGasPrice(rpcUrl: rpcUrl)

        // Apply minimum recommendation
        let minGasPrice = gweiToWei(1.0) // Minimum 1 Gwei
        let recommendedGasPrice = max(networkGasPrice, minGasPrice)

        // Add 10% buffer for safety
        let bufferedGasPrice = Int(Double(recommendedGasPrice) * 1.1)

        let gasPrice = GasPrice.legacy(gasPrice: bufferedGasPrice)

        // Determine warning level
        let warning = determineWarning(
            actual: bufferedGasPrice,
            recommended: networkGasPrice,
            isEIP1559: false
        )

        let waitTime = estimateWaitTime(gasPrice: bufferedGasPrice)

        return GasPriceEstimate(
            recommended: gasPrice,
            warning: warning,
            estimatedWaitTime: waitTime
        )
    }

    // MARK: - Network Fetching

    private func fetchBaseFee(rpcUrl: String) async throws -> Int {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_getBlockByNumber",
            "params": ["latest", false],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let result = json?["result"] as? [String: Any],
              let baseFeeHex = result["baseFeePerGas"] as? String else {
            // Fallback to legacy if EIP-1559 not available
            return gweiToWei(20) // 20 Gwei default
        }

        let hexString = baseFeeHex.hasPrefix("0x") ? String(baseFeeHex.dropFirst(2)) : baseFeeHex
        return Int(hexString, radix: 16) ?? gweiToWei(20)
    }

    private func fetchPriorityFee(rpcUrl: String) async throws -> Int {
        let url = URL(string: rpcUrl)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "method": "eth_maxPriorityFeePerGas",
            "params": [],
            "id": 1
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        guard let resultHex = json?["result"] as? String else {
            return gweiToWei(2) // 2 Gwei default priority
        }

        let hexString = resultHex.hasPrefix("0x") ? String(resultHex.dropFirst(2)) : resultHex
        return Int(hexString, radix: 16) ?? gweiToWei(2)
    }

    private func fetchLegacyGasPrice(rpcUrl: String) async throws -> Int {
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

        guard let resultHex = json?["result"] as? String else {
            return gweiToWei(20) // 20 Gwei default
        }

        let hexString = resultHex.hasPrefix("0x") ? String(resultHex.dropFirst(2)) : resultHex
        return Int(hexString, radix: 16) ?? gweiToWei(20)
    }

    // MARK: - Helper Methods

    private func determineWarning(actual: Int, recommended: Int, isEIP1559: Bool) -> GasPriceWarning {
        let lowerBound = Double(recommended) * safeRangeLowerBound
        let upperBound = Double(recommended) * safeRangeUpperBound

        if Double(actual) < lowerBound {
            return .tooLow
        } else if Double(actual) > upperBound {
            return .tooHigh
        } else {
            return .optimal
        }
    }

    private func estimateWaitTime(priorityFee: Int) -> String {
        let gweiValue = weiToGwei(priorityFee)
        let gwei = NSDecimalNumber(decimal: gweiValue).doubleValue

        if gwei >= 3.0 {
            return "~30 seconds"
        } else if gwei >= 2.0 {
            return "~1 minute"
        } else if gwei >= 1.0 {
            return "~2 minutes"
        } else {
            return "~5+ minutes"
        }
    }

    private func estimateWaitTime(gasPrice: Int) -> String {
        let gweiValue = weiToGwei(gasPrice)
        let gwei = NSDecimalNumber(decimal: gweiValue).doubleValue

        if gwei >= 20.0 {
            return "~30 seconds"
        } else if gwei >= 10.0 {
            return "~1 minute"
        } else if gwei >= 5.0 {
            return "~2 minutes"
        } else {
            return "~5+ minutes"
        }
    }
}

// MARK: - Gas Price Tiers (for UI)

extension GasPriceService {
    enum GasPriceTier {
        case slow
        case standard
        case fast

        var displayName: String {
            switch self {
            case .slow: return "Slow"
            case .standard: return "Standard"
            case .fast: return "Fast"
            }
        }

        var multiplier: Double {
            switch self {
            case .slow: return 0.9      // 90% of recommended
            case .standard: return 1.0  // 100% recommended
            case .fast: return 1.2      // 120% of recommended
            }
        }
    }

    func getGasPrice(for blockchain: BlockchainType, tier: GasPriceTier) async throws -> GasPriceEstimate {
        let baseEstimate = try await getGasPrice(for: blockchain)

        let adjustedGasPrice: GasPrice
        switch baseEstimate.recommended {
        case .legacy(let price):
            let adjusted = Int(Double(price) * tier.multiplier)
            adjustedGasPrice = .legacy(gasPrice: adjusted)

        case .eip1559(let maxFee, let priorityFee):
            let adjustedMaxFee = Int(Double(maxFee) * tier.multiplier)
            let adjustedPriority = Int(Double(priorityFee) * tier.multiplier)
            adjustedGasPrice = .eip1559(maxFeePerGas: adjustedMaxFee, maxPriorityFeePerGas: adjustedPriority)
        }

        return GasPriceEstimate(
            recommended: adjustedGasPrice,
            warning: tier == .slow ? .tooLow : (tier == .fast ? .tooHigh : .optimal),
            estimatedWaitTime: tier == .fast ? "~15 seconds" : (tier == .slow ? "~5 minutes" : "~1 minute")
        )
    }
}
