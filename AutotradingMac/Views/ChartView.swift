//
//  ChartView.swift
//  AutotradingMac
//

import SwiftUI

struct ChartView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("종목 선택 후 차트/상세 정보가 들어올 자리입니다.")
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            RoundedRectangle(cornerRadius: 12)
                .fill(DesignTokens.Colors.surface1)
                .frame(minHeight: 320)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.largeTitle)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                        Text("Chart Placeholder")
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                )
        }
        .padding()
    }
}
