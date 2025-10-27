//
//  WpayinLogoView.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//

import SwiftUI

struct WpayinLogoView: View {
    let size: CGFloat
    let colors: [Color]

    init(size: CGFloat = 100, colors: [Color] = [WpayinColors.primary, WpayinColors.primaryDark]) {
        self.size = size
        self.colors = colors
    }

    var body: some View {
        // Use the logo image from Assets Catalog
        Image("WpayinLogo")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .clipShape(Circle())
    }
}

#Preview {
    VStack(spacing: 20) {
        WpayinLogoView(size: 120)
        WpayinLogoView(size: 80, colors: [.green, .blue])
        WpayinLogoView(size: 60, colors: [.orange, .red])
    }
    .padding()
    .background(Color.black)
}