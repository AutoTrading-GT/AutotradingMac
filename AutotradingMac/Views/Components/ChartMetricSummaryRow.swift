//
//  ChartMetricSummaryRow.swift
//  AutotradingMac
//

import SwiftUI

struct ChartMetricSummaryItem: Identifiable {
    let title: String
    let value: String
    let valueColor: Color

    var id: String { title }
}

struct ChartMetricSummaryRow: View {
    let items: [ChartMetricSummaryItem]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                metricItem(item)
                if index < items.count - 1 {
                    Divider()
                        .overlay(DesignTokens.Colors.borderSubtle.opacity(0.8))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func metricItem(_ item: ChartMetricSummaryItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(DesignTokens.Typography.caption2)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Text(item.value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(item.valueColor)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

