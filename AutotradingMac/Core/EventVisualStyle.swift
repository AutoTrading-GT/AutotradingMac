//
//  EventVisualStyle.swift
//  AutotradingMac
//

import SwiftUI

struct EventVisualStyle {
    let iconName: String
    let iconColor: Color
    let tone: StatusTone
}

enum EventVisualStyleResolver {
    private static let closeIcon = "flag.checkered.circle.fill"

    static func signal(signalType: String) -> EventVisualStyle {
        let normalized = normalize(signalType)
        if containsAny(normalized, keywords: ["sell", "exit", "매도"]) {
            return style(.sell)
        }
        if containsAny(normalized, keywords: ["watch", "maintained", "hold", "wait", "관망"]) {
            return style(.watch)
        }
        return style(.buy)
    }

    static func risk(decision: String, reason: String, signalType: String?) -> EventVisualStyle {
        let decisionNormalized = normalize(decision)
        let reasonNormalized = normalize(reason)
        let signalNormalized = normalize(signalType)

        if decisionNormalized == "blocked" ||
            containsAny(reasonNormalized, keywords: ["blocked", "보류", "차단", "cooldown", "limit", "already_holding", "position"]) {
            return style(.blocked)
        }
        if containsAny(signalNormalized, keywords: ["watch", "maintained", "hold", "관망"]) {
            return style(.watch)
        }
        if containsAny(signalNormalized, keywords: ["sell", "exit", "매도"]) {
            return style(.sell)
        }
        return style(.buy)
    }

    static func order(side: String, status: String, message: String? = nil) -> EventVisualStyle {
        let sideNormalized = normalize(side)
        let statusNormalized = normalize(status)
        let messageNormalized = normalize(message)

        if containsAny(statusNormalized, keywords: ["rejected", "cancelled", "blocked"]) ||
            containsAny(messageNormalized, keywords: ["보류", "차단", "limit_reached", "hold"]) {
            return style(.blocked)
        }

        if sideNormalized == "sell" || containsAny(messageNormalized, keywords: ["매도"]) {
            return style(.sell)
        }
        if sideNormalized == "buy" || containsAny(messageNormalized, keywords: ["매수"]) {
            return style(.buy)
        }
        return style(.neutral)
    }

    static func fill(side: String) -> EventVisualStyle {
        let normalized = normalize(side)
        if normalized == "sell" || containsAny(normalized, keywords: ["매도"]) {
            return style(.sell)
        }
        if normalized == "buy" || containsAny(normalized, keywords: ["매수"]) {
            return style(.buy)
        }
        return style(.neutral)
    }

    static func close(reason: String?, realizedPnl: Double?) -> EventVisualStyle {
        let normalized = normalize(reason)

        if containsAny(normalized, keywords: ["first_take_profit_partial", "take_profit", "익절"]) {
            return EventVisualStyle(iconName: closeIcon, iconColor: DesignTokens.Colors.profit, tone: .danger)
        }
        if containsAny(normalized, keywords: ["initial_stop", "stop_loss", "손절"]) {
            return EventVisualStyle(iconName: closeIcon, iconColor: DesignTokens.Colors.loss, tone: .info)
        }
        if containsAny(normalized, keywords: ["hard_time_stop", "soft_time_stop", "max_holding", "holding", "timeout", "time", "보유시간"]) {
            return EventVisualStyle(iconName: closeIcon, iconColor: DesignTokens.Colors.info, tone: .info)
        }
        if containsAny(normalized, keywords: ["market_close_exit", "market_close", "장마감"]) {
            return EventVisualStyle(iconName: closeIcon, iconColor: DesignTokens.Colors.info, tone: .info)
        }

        let pnlColor = amountColor(forPnL: realizedPnl)
        let pnlTone: StatusTone = (realizedPnl ?? 0) > 0 ? .danger : ((realizedPnl ?? 0) < 0 ? .info : .neutral)
        return EventVisualStyle(iconName: closeIcon, iconColor: pnlColor, tone: pnlTone)
    }

    static func position(pnl: Double?) -> EventVisualStyle {
        let color = amountColor(forPnL: pnl)
        let tone: StatusTone = (pnl ?? 0) > 0 ? .danger : ((pnl ?? 0) < 0 ? .info : .neutral)
        return EventVisualStyle(
            iconName: "briefcase.fill",
            iconColor: color,
            tone: tone
        )
    }

    static func amountColor(forPnL value: Double?) -> Color {
        guard let value else { return DesignTokens.Colors.textTertiary }
        if value > 0 { return DesignTokens.Colors.profit }   // 한국 관습: 이익=빨강
        if value < 0 { return DesignTokens.Colors.loss }     // 한국 관습: 손실=파랑
        return DesignTokens.Colors.textTertiary
    }

    private static func normalize(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func containsAny(_ source: String, keywords: [String]) -> Bool {
        keywords.contains { source.contains($0) }
    }

    private static func style(_ semantic: Semantic) -> EventVisualStyle {
        switch semantic {
        case .buy:
            return EventVisualStyle(
                iconName: "arrow.up.forward.circle.fill",
                iconColor: DesignTokens.Colors.profit,
                tone: .danger
            )
        case .sell:
            return EventVisualStyle(
                iconName: "arrow.down.forward.circle.fill",
                iconColor: DesignTokens.Colors.loss,
                tone: .info
            )
        case .watch:
            return EventVisualStyle(
                iconName: "pause.circle.fill",
                iconColor: DesignTokens.Colors.textSecondary,
                tone: .neutral
            )
        case .blocked:
            return EventVisualStyle(
                iconName: "exclamationmark.shield.fill",
                iconColor: DesignTokens.Colors.warning,
                tone: .warning
            )
        case .neutral:
            return EventVisualStyle(
                iconName: "circle.fill",
                iconColor: DesignTokens.Colors.textTertiary,
                tone: .neutral
            )
        }
    }

    private enum Semantic {
        case buy
        case sell
        case watch
        case blocked
        case neutral
    }
}
