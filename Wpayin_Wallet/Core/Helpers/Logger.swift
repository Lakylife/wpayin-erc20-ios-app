// Autor Lukas Helebrandt, 2026
//
//  Logger.swift
//  Wpayin_Wallet
//

import Foundation

/// Utility for debug-only logging to prevent sensitive data exposure in production
struct Logger {
    /// Logs a message only in DEBUG builds
    static func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
        #if DEBUG
        let output = items.map { "\($0)" }.joined(separator: separator)
        Swift.print(output, terminator: terminator)
        #endif
    }
}
