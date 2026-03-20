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
            return DesignTokens.Colors.textSecondary
        case .info:
            return DesignTokens.Colors.info
        case .success:
            return DesignTokens.Colors.success
        case .warning:
            return DesignTokens.Colors.warning
        case .danger:
            return DesignTokens.Colors.danger
        }
    }

    var background: Color {
        switch self {
        case .neutral:
            return DesignTokens.Colors.surface2
        case .info:
            return DesignTokens.Colors.infoBackground
        case .success:
            return DesignTokens.Colors.successBackground
        case .warning:
            return DesignTokens.Colors.warningBackground
        case .danger:
            return DesignTokens.Colors.dangerBackground
        }
    }

    static func fromStatus(_ raw: String?) -> StatusTone {
        let value = raw?.lowercased() ?? ""
        if ["ready", "running", "connected", "up", "filled", "approved", "healthy"].contains(value) {
            return .success
        }
        if ["starting", "stopping", "submitted", "partially_filled", "degraded", "paused"].contains(value) {
            return .warning
        }
        if ["error", "down", "rejected", "blocked", "not_ready", "disconnected"].contains(value) {
            return .danger
        }
        return .neutral
    }
}
