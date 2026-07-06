// Autor Lukas Helebrandt, 2026

//
//  AppToast.swift
//  Wpayin_Wallet
//
//  Lightweight in-app confirmation toasts (copy to clipboard, settings toggles…).
//  Rendered in a dedicated passthrough UIWindow so they appear above sheets too.
//

import SwiftUI
import UIKit
import Combine

final class AppToast {
    static let shared = AppToast()

    private let state = ToastState()
    private var window: UIWindow?
    private var hideWorkItem: DispatchWorkItem?

    private init() {}

    /// Show a short confirmation toast at the top of the screen.
    static func show(_ message: String, icon: String = "checkmark.circle.fill") {
        DispatchQueue.main.async {
            shared.present(message: message, icon: icon)
        }
    }

    /// Copy a value to the clipboard with haptic + toast confirmation.
    static func copyToClipboard(_ value: String, message: String? = nil) {
        UIPasteboard.general.string = value
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        show(message ?? "Copied to clipboard".localized, icon: "doc.on.doc.fill")
    }

    // MARK: - Private

    private func present(message: String, icon: String) {
        ensureWindow()
        state.message = message
        state.icon = icon
        state.isVisible = true

        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2, execute: work)
    }

    private func dismiss() {
        state.isVisible = false

        // Tear the window down after the hide animation finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            guard let self, self.state.isVisible == false else { return }
            self.window?.isHidden = true
            self.window = nil
        }
    }

    private func ensureWindow() {
        guard window == nil else { return }

        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        guard let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first else {
            return
        }

        let host = UIHostingController(rootView: ToastOverlayView(state: state))
        host.view.backgroundColor = .clear

        let win = PassthroughWindow(windowScene: scene)
        win.rootViewController = host
        win.windowLevel = .alert + 1
        win.isHidden = false
        window = win
    }
}

private final class ToastState: ObservableObject {
    @Published var message: String = ""
    @Published var icon: String = "checkmark.circle.fill"
    @Published var isVisible = false
}

/// Window that never intercepts touches — everything passes through to the app.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

private struct ToastOverlayView: View {
    @ObservedObject var state: ToastState

    var body: some View {
        VStack {
            if state.isVisible {
                HStack(spacing: 10) {
                    Image(systemName: state.icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(WpayinColors.primary)

                    Text(state.message)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(WpayinColors.text)
                        .lineLimit(2)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color.wpayinMediumGray)
                        .overlay(
                            Capsule()
                                .stroke(WpayinColors.surfaceBorder, lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 6)
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()
        }
        .padding(.top, 10)
        .padding(.horizontal, 20)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.isVisible)
    }
}
