//
//  Transaction.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation

struct Transaction: Identifiable, Codable {
    let id: UUID
    let hash: String
    let from: String
    let to: String
    let amount: Double
    let token: String
    let type: TransactionType
    let status: TransactionStatus
    let timestamp: Date
    let gasUsed: Double
    let gasFee: Double
    let blockNumber: String?
    let explorerUrl: URL?

    enum TransactionType: String, CaseIterable, Codable {
        case send = "send"
        case receive = "receive"
        case swap = "swap"
        case deposit = "deposit"
        case withdraw = "withdraw"

        var displayName: String {
            switch self {
            case .send: return "Send"
            case .receive: return "Receive"
            case .swap: return "Swap"
            case .deposit: return "Deposit"
            case .withdraw: return "Withdraw"
            }
        }
    }

    enum TransactionStatus: String, CaseIterable, Codable {
        case pending = "pending"
        case confirmed = "confirmed"
        case failed = "failed"

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .confirmed: return "Confirmed"
            case .failed: return "Failed"
            }
        }
    }

    init(
        hash: String,
        from: String,
        to: String,
        amount: Double,
        token: String,
        type: TransactionType,
        status: TransactionStatus,
        timestamp: Date,
        gasUsed: Double,
        gasFee: Double,
        blockNumber: String? = nil,
        explorerUrl: URL? = nil,
        id: UUID = UUID()
    ) {
        self.id = id
        self.hash = hash
        self.from = from
        self.to = to
        self.amount = amount
        self.token = token
        self.type = type
        self.status = status
        self.timestamp = timestamp
        self.gasUsed = gasUsed
        self.gasFee = gasFee
        self.blockNumber = blockNumber
        self.explorerUrl = explorerUrl
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case hash
        case from
        case to
        case amount
        case token
        case type
        case status
        case timestamp
        case gasUsed
        case gasFee
        case blockNumber
        case explorerUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hash = try container.decode(String.self, forKey: .hash)
        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        amount = try container.decode(Double.self, forKey: .amount)
        token = try container.decode(String.self, forKey: .token)
        type = try container.decode(TransactionType.self, forKey: .type)
        status = try container.decode(TransactionStatus.self, forKey: .status)
        if let isoDateString = try? container.decode(String.self, forKey: .timestamp) {
            let formatter = ISO8601DateFormatter()
            timestamp = formatter.date(from: isoDateString) ?? Date()
        } else if let timeInterval = try? container.decode(Double.self, forKey: .timestamp) {
            timestamp = Date(timeIntervalSince1970: timeInterval)
        } else {
            timestamp = Date()
        }
        gasUsed = try container.decode(Double.self, forKey: .gasUsed)
        gasFee = try container.decode(Double.self, forKey: .gasFee)
        blockNumber = try container.decodeIfPresent(String.self, forKey: .blockNumber)
        explorerUrl = try container.decodeIfPresent(URL.self, forKey: .explorerUrl)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(hash, forKey: .hash)
        try container.encode(from, forKey: .from)
        try container.encode(to, forKey: .to)
        try container.encode(amount, forKey: .amount)
        try container.encode(token, forKey: .token)
        try container.encode(type, forKey: .type)
        try container.encode(status, forKey: .status)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(gasUsed, forKey: .gasUsed)
        try container.encode(gasFee, forKey: .gasFee)
        try container.encodeIfPresent(blockNumber, forKey: .blockNumber)
        try container.encodeIfPresent(explorerUrl, forKey: .explorerUrl)
    }

    static let mockTransactions: [Transaction] = [
        Transaction(
            hash: "0x1234567890abcdef",
            from: "0x742d35Cc2C4f0532",
            to: "0xd8dA6BF26964aF9D",
            amount: 0.5,
            token: "ETH",
            type: .send,
            status: .confirmed,
            timestamp: Date().addingTimeInterval(-3600),
            gasUsed: 21000,
            gasFee: 0.002,
            blockNumber: "18000000",
            explorerUrl: URL(string: "https://etherscan.io/tx/0x1234567890abcdef")
        ),
        Transaction(
            hash: "0xabcdef1234567890",
            from: "0xd8dA6BF26964aF9D",
            to: "0x742d35Cc2C4f0532",
            amount: 100.0,
            token: "USDT",
            type: .receive,
            status: .confirmed,
            timestamp: Date().addingTimeInterval(-7200),
            gasUsed: 35000,
            gasFee: 0.003,
            blockNumber: "17999990",
            explorerUrl: URL(string: "https://etherscan.io/tx/0xabcdef1234567890")
        ),
        Transaction(
            hash: "0x567890abcdef1234",
            from: "0x742d35Cc2C4f0532",
            to: "0x742d35Cc2C4f0532",
            amount: 50.0,
            token: "USDC",
            type: .swap,
            status: .pending,
            timestamp: Date().addingTimeInterval(-1800),
            gasUsed: 120000,
            gasFee: 0.01,
            blockNumber: "17999995",
            explorerUrl: URL(string: "https://etherscan.io/tx/0x567890abcdef1234")
        )
    ]
}
