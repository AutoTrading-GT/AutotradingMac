//
//  PositionsPnLView.swift
//  AutotradingMac
//

import SwiftUI

struct PositionsPnLView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Positions / PnL")
                    .font(.title3.bold())
                pnlSummaryCards
                openPositionsTable
                closedPositionsTable
            }
            .padding()
        }
        .navigationTitle("Positions / PnL")
    }

    private var pnlSummaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(title: "Open Positions", value: "\(store.pnlSummary.openPositions)", tone: .neutral)
            summaryCard(
                title: "Unrealized PnL",
                value: DisplayFormatters.pnl(store.pnlSummary.unrealizedPnlTotal),
                tone: toneForPnL(store.pnlSummary.unrealizedPnlTotal)
            )
            summaryCard(
                title: "Realized PnL",
                value: DisplayFormatters.pnl(store.pnlSummary.realizedPnlRecentTotal),
                tone: toneForPnL(store.pnlSummary.realizedPnlRecentTotal)
            )
            summaryCard(
                title: "Closed Count",
                value: "\(store.pnlSummary.recentClosedCount)",
                tone: .neutral
            )
        }
    }

    private func summaryCard(title: String, value: String, tone: StatusTone) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Text(value)
                    .font(.headline)
                Spacer()
                StatusBadge(text: value, tone: tone)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var openPositionsTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open Positions")
                .font(.headline)
            if store.currentPositions.isEmpty {
                Text("No open positions.")
                    .foregroundStyle(.secondary)
            } else {
                Table(store.currentPositions) {
                    TableColumn("Code", value: \.code)
                    TableColumn("Symbol") { row in
                        Text(row.symbol ?? "-")
                    }
                    TableColumn("Qty") { row in
                        Text(DisplayFormatters.number(row.qty))
                    }
                    TableColumn("Avg Price") { row in
                        Text(DisplayFormatters.number(row.avgPrice))
                    }
                    TableColumn("Mark Price") { row in
                        Text(DisplayFormatters.number(row.markPrice))
                    }
                    TableColumn("Unrealized") { row in
                        Text(DisplayFormatters.pnl(row.unrealizedPnl))
                            .foregroundStyle(colorForPnL(row.unrealizedPnl))
                    }
                    TableColumn("PnL %") { row in
                        Text(DisplayFormatters.percent(row.unrealizedPnlPct))
                            .foregroundStyle(colorForPnL(row.unrealizedPnl))
                    }
                    TableColumn("Updated") { row in
                        Text(DisplayFormatters.dateTime(row.updatedAt))
                    }
                }
                .frame(minHeight: 200)
            }
        }
    }

    private var closedPositionsTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Closed Positions")
                .font(.headline)
            if store.recentClosedPositions.isEmpty {
                Text("No closed positions.")
                    .foregroundStyle(.secondary)
            } else {
                Table(store.recentClosedPositions) {
                    TableColumn("Time") { row in
                        Text(DisplayFormatters.dateTime(row.createdAt))
                    }
                    TableColumn("Code") { row in
                        Text(row.code ?? "-")
                    }
                    TableColumn("Qty") { row in
                        Text(DisplayFormatters.number(row.closedQty))
                    }
                    TableColumn("Entry") { row in
                        Text(DisplayFormatters.number(row.avgEntryPrice))
                    }
                    TableColumn("Exit") { row in
                        Text(DisplayFormatters.number(row.exitPrice))
                    }
                    TableColumn("Realized") { row in
                        Text(DisplayFormatters.pnl(row.realizedPnl))
                            .foregroundStyle(colorForPnL(row.realizedPnl))
                    }
                    TableColumn("Reason") { row in
                        Text(row.reason ?? "-")
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    private func toneForPnL(_ value: Double?) -> StatusTone {
        guard let value else { return .neutral }
        if value > 0 { return .success }
        if value < 0 { return .danger }
        return .neutral
    }

    private func colorForPnL(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }
}
