//
//  StatusBadge.swift
//  AutotradingMac
//

import SwiftUI

struct StatusBadge: View {
    let text: String
    let tone: StatusTone

    var body: some View {
        Text(text)
            .font(DesignTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tone.background.opacity(0.85))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.65), lineWidth: 0.8)
            )
            .lineLimit(1)
    }
}
