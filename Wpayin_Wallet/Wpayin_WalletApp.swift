// Autor Lukas Helebrandt, 2026

//
//  Wpayin_WalletApp.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 25.09.2025.
//
//  ╦ ╦┌─┐┬  ┬  ┌─┐┌┬┐╔═╗┌─┐┬ ┬┬┌┐┌
//  ║║║├─┤│  │  ├┤  │ ╠═╝├─┤└┬┘││││
//  ╚╩╝┴ ┴┴─┘┴─┘└─┘ ┴ ╩  ┴ ┴ ┴ ┴┘└┘
//

import SwiftUI

@main
struct Wpayin_WalletApp: App {
    init() {
        // Plain http stays limited to the user's own Quintium node.
        PlainHTTPGuard.install()
        // Register the notification-center delegate before any notification
        // can arrive (needed for foreground banner presentation).
        _ = NotificationManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
