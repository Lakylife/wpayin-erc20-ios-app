//
//  NotificationManager.swift
//  Wpayin_Wallet
//
//  Created by Lukas Helebrandt on 19.10.2025.
//

import SwiftUI
import Combine
import UserNotifications

enum NotificationType {
    case transactionReceived(amount: String, token: String)
    case transactionSent(amount: String, token: String)
    case swapCompleted(from: String, to: String)
    case tokenAdded(name: String)

    var title: String {
        switch self {
        case .transactionReceived: return "✅ Received"
        case .transactionSent: return "📤 Sent"
        case .swapCompleted: return "🔄 Swap Complete"
        case .tokenAdded: return "➕ Token Added"
        }
    }

    var body: String {
        switch self {
        case .transactionReceived(let amount, let token):
            return "Received \(amount) \(token)"
        case .transactionSent(let amount, let token):
            return "Sent \(amount) \(token)"
        case .swapCompleted(let from, let to):
            return "Swapped \(from) to \(to)"
        case .tokenAdded(let name):
            return "\(name) added to your wallet"
        }
    }

    var icon: String {
        switch self {
        case .transactionReceived: return "arrow.down.circle.fill"
        case .transactionSent: return "arrow.up.circle.fill"
        case .swapCompleted: return "arrow.triangle.2.circlepath"
        case .tokenAdded: return "plus.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .transactionReceived: return WpayinColors.success
        case .transactionSent: return WpayinColors.primary
        case .swapCompleted: return WpayinColors.primary
        case .tokenAdded: return WpayinColors.success
        }
    }
}

final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    @Published var currentNotification: NotificationType?
    @Published var showNotification = false

    private init() {
        requestPermission()
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permission granted")
            } else if let error = error {
                print("❌ Notification permission error: \(error.localizedDescription)")
            }
        }
    }

    /// Show in-app banner notification
    func showBanner(_ type: NotificationType) {
        Task { @MainActor in
            currentNotification = type
            showNotification = true

            // Auto-hide after 3 seconds
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            showNotification = false
        }
    }

    /// Send push notification (when app is in background)
    func sendPushNotification(_ type: NotificationType) {
        let content = UNMutableNotificationContent()
        content.title = type.title
        content.body = type.body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Failed to send push notification: \(error.localizedDescription)")
            }
        }
    }

    /// Notify for transaction received
    func notifyTransactionReceived(amount: String, token: String) {
        let notification = NotificationType.transactionReceived(amount: amount, token: token)
        showBanner(notification)
        sendPushNotification(notification)
    }

    /// Notify for transaction sent
    func notifyTransactionSent(amount: String, token: String) {
        let notification = NotificationType.transactionSent(amount: amount, token: token)
        showBanner(notification)
        sendPushNotification(notification)
    }

    /// Notify for swap completed
    func notifySwapCompleted(from: String, to: String) {
        let notification = NotificationType.swapCompleted(from: from, to: to)
        showBanner(notification)
        sendPushNotification(notification)
    }

    /// Notify for token added
    func notifyTokenAdded(name: String) {
        let notification = NotificationType.tokenAdded(name: name)
        showBanner(notification)
        sendPushNotification(notification)
    }
}

// MARK: - Notification Banner View
struct NotificationBanner: View {
    let notification: NotificationType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: notification.icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(notification.color)

            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(WpayinColors.text)

                Text(notification.body)
                    .font(.system(size: 12))
                    .foregroundColor(WpayinColors.textSecondary)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(WpayinColors.surface)
                .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
        )
        .padding(.horizontal, 20)
    }
}
