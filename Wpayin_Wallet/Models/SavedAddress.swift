//
//  SavedAddress.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import Foundation

struct SavedAddress: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let address: String
    let createdAt: Date

    init(id: UUID = UUID(), name: String, address: String, createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.address = address
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        let name = try container.decode(String.self, forKey: .name)
        let address = try container.decode(String.self, forKey: .address)
        let createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        self.init(id: id, name: name, address: address, createdAt: createdAt)
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case address
        case createdAt
    }
}

// Mock data for preview
extension SavedAddress {
    static let mockAddresses = [
        SavedAddress(name: "My Other Wallet", address: "0x742d35Cc6D06b73494d45e5d2b0542f2f25b3f66"),
        SavedAddress(name: "Friends Wallet", address: "0x8ba1f109551bD432803012645Hac136c22C"),
        SavedAddress(name: "Exchange Wallet", address: "0x9f8cc3C47aF014a21f109551bD432803012645A7")
    ]
}
