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
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tone.background, in: Capsule())
            .lineLimit(1)
    }
}
