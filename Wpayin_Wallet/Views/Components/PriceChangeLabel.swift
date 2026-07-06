// Autor Lukas Helebrandt, 2026

//
//  PriceChangeLabel.swift
//  Wpayin_Wallet
//
//  Compact 24h price change indicator shown next to live token prices.
//

import SwiftUI

struct PriceChangeLabel: View {
    /// 24h change in percent (e.g. -2.4); nil renders nothing.
    let change: Double?

    var body: some View {
        if let change, change.isFinite, abs(change) >= 0.005 {
            HStack(spacing: 2) {
                Image(systemName: change >= 0 ? "arrowtriangle.up.fill" : "arrowtriangle.down.fill")
                    .font(.system(size: 7, weight: .bold))

                Text(String(format: "%.1f%%", abs(change)))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundColor(change >= 0 ? WpayinColors.success : WpayinColors.error)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill((change >= 0 ? WpayinColors.success : WpayinColors.error).opacity(0.12))
            )
        }
    }
}
