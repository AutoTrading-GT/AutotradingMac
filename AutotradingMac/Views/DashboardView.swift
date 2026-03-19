//
//  DashboardView.swift
//  AutotradingMac
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                runtimeCards
                workerStatusSection
                integrationSection
                errorSection
            }
            .padding()
        }
        .navigationTitle("Dashboard")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Runtime Snapshot")
                .font(.title2.bold())
            Text("Last update: \(DisplayFormatters.dateTime(store.lastUpdatedAt))")
                .foregroundStyle(.secondary)
            if let message = store.lastErrorMessage, !message.isEmpty {
                Text(message)
                    .foregroundStyle(.red)
                    .font(.callout)
            }
        }
    }

    private var runtimeCards: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 180), spacing: 12),
        ], spacing: 12) {
            ForEach(store.dashboardCards) { card in
                VStack(alignment: .leading, spacing: 10) {
                    Text(card.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(card.value)
                            .font(.headline)
                        Spacer()
                        StatusBadge(text: card.value, tone: card.tone)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var workerStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workers")
                .font(.headline)
            if store.workerRows.isEmpty {
                Text("No worker status yet.")
                    .foregroundStyle(.secondary)
            } else {
                Table(store.workerRows) {
                    TableColumn("Worker", value: \.worker)
                    TableColumn("Status") { row in
                        StatusBadge(text: row.status, tone: .fromStatus(row.status))
                    }
                    TableColumn("Message") { row in
                        Text(row.statusMessage ?? "-")
                    }
                    TableColumn("Error") { row in
                        Text(row.error ?? "-")
                            .foregroundStyle((row.error == nil) ? Color.secondary : Color.red)
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    private var integrationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("KIS / Integration")
                .font(.headline)
            let marketData = store.workerRows.first { $0.worker == "market_data" }
            let execution = store.workerRows.first { $0.worker == "execution" }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    Text("Execution Mode")
                        .foregroundStyle(.secondary)
                    Text(store.runtime?.executionMode ?? "-")
                }
                GridRow {
                    Text("Rank Source")
                        .foregroundStyle(.secondary)
                    Text(marketData?.rankSource ?? "-")
                }
                GridRow {
                    Text("Tick Source")
                        .foregroundStyle(.secondary)
                    Text(marketData?.tickSource ?? "-")
                }
                GridRow {
                    Text("Sync Status")
                        .foregroundStyle(.secondary)
                    Text(execution?.syncStatus ?? "-")
                }
            }
            .padding()
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var errorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Degraded / Errors")
                .font(.headline)
            if store.recentErrorItems.isEmpty {
                Text("No degraded/error signal.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(store.recentErrorItems.enumerated()), id: \.offset) { _, item in
                    Text(item)
                        .font(.callout.monospaced())
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
