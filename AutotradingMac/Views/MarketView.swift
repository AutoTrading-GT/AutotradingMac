//
//  MarketView.swift
//  AutotradingMac
//

import SwiftUI

struct MarketView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scanner")
                .font(.title3.bold())
            Text("Top ranks와 최신 tick을 기반으로 종목 스캔 정보를 표시합니다.")
                .foregroundStyle(.secondary)
            Text("Last update: \(DisplayFormatters.dateTime(store.lastUpdatedAt))")
                .foregroundStyle(.secondary)

            if store.marketRows.isEmpty {
                ContentUnavailableView("No market data", systemImage: "chart.line.uptrend.xyaxis")
            } else {
                Table(store.marketRows) {
                    TableColumn("Code", value: \.code)
                    TableColumn("Symbol", value: \.symbol)
                    TableColumn("Rank") { row in
                        Text(DisplayFormatters.integer(row.rank))
                    }
                    TableColumn("Price") { row in
                        Text(DisplayFormatters.number(row.price))
                    }
                    TableColumn("Change %") { row in
                        Text(DisplayFormatters.percent(row.changePct))
                            .foregroundStyle(colorForChange(row.changePct))
                    }
                    TableColumn("Metric") { row in
                        Text(DisplayFormatters.metric(row.metric))
                    }
                    TableColumn("Source") { row in
                        Text(row.source ?? "-")
                    }
                    TableColumn("Updated") { row in
                        Text(DisplayFormatters.dateTime(row.updatedAt))
                    }
                }
            }
        }
        .padding()
        .navigationTitle("Scanner")
    }

    private func colorForChange(_ value: Double?) -> Color {
        guard let value else { return .primary }
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}
