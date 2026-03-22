//
//  ClosedIntradayHintIcon.swift
//  AutotradingMac
//

import SwiftUI

struct ClosedIntradayHintIcon: View {
    @State private var showsTooltip = false

    var body: some View {
        Image(systemName: "questionmark.circle")
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary.opacity(0.9))
            .frame(width: 18, height: 18, alignment: .center)
            .contentShape(Rectangle())
            .help(MarketSessionResolver.intradayClosedTooltip)
            .accessibilityLabel("휴장 안내")
            .onHover { hovering in
                showsTooltip = hovering
            }
            .popover(isPresented: $showsTooltip, arrowEdge: .bottom) {
                Text(MarketSessionResolver.intradayClosedTooltip)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .padding(10)
                    .frame(minWidth: 220, alignment: .leading)
            }
    }
}
