//
//  StatusTone.swift
//  AutotradingMac
//

import SwiftUI

enum StatusTone {
    case neutral
    case info
    case success
    case warning
    case danger

    var foreground: Color {
        switch self {
        case .neutral:
            return .primary
        case .info:
            return .blue
        case .success:
            return .green
        case .warning:
            return .orange
        case .danger:
            return .red
        }
    }

    var background: Color {
        switch self {
        case .neutral:
            return Color.secondary.opacity(0.15)
        case .info:
            return Color.blue.opacity(0.18)
        case .success:
            return Color.green.opacity(0.18)
        case .warning:
            return Color.orange.opacity(0.18)
        case .danger:
            return Color.red.opacity(0.18)
        }
    }

    static func fromStatus(_ raw: String?) -> StatusTone {
        let value = raw?.lowercased() ?? ""
        if ["ready", "running", "connected", "up", "filled", "approved", "healthy"].contains(value) {
            return .success
        }
        if ["starting", "stopping", "submitted", "partially_filled", "degraded"].contains(value) {
            return .warning
        }
        if ["error", "down", "rejected", "blocked", "not_ready", "disconnected"].contains(value) {
            return .danger
        }
        return .neutral
    }
}
