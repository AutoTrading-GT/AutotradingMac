//
//  SignalsRiskView.swift
//  AutotradingMac
//

import SwiftUI

struct SignalsRiskView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Signals / Risk")
                    .font(.title3.bold())
                signalTable
                riskTable
            }
            .padding()
        }
    }

    private var signalTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Signals")
                .font(.headline)
            if store.recentSignals.isEmpty {
                Text("No signal.generated events yet.")
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            } else {
                Table(store.recentSignals) {
                    TableColumn("Time") { row in
                        Text(DisplayFormatters.dateTime(row.createdAt))
                    }
                    TableColumn("Code", value: \.code)
                    TableColumn("Type", value: \.signalType)
                    TableColumn("Confidence") { row in
                        Text(DisplayFormatters.number(row.confidence))
                    }
                    TableColumn("Snapshot Ref") { row in
                        Text(row.sourceSnapshotId.map(String.init) ?? "-")
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }

    private var riskTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Risk Decisions")
                .font(.headline)
            if store.recentRiskDecisions.isEmpty {
                Text("No risk decisions yet.")
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            } else {
                Table(store.recentRiskDecisions) {
                    TableColumn("Time") { row in
                        Text(DisplayFormatters.dateTime(row.createdAt))
                    }
                    TableColumn("Decision") { row in
                        StatusBadge(
                            text: row.decision,
                            tone: .fromStatus(row.decision)
                        )
                    }
                    TableColumn("Code") { row in
                        Text(row.code ?? "-")
                    }
                    TableColumn("Signal Type") { row in
                        Text(row.signalType ?? "-")
                    }
                    TableColumn("Reason") { row in
                        Text(row.reason)
                    }
                }
                .frame(minHeight: 180)
            }
        }
    }
}

#Preview("Signals / Risk") {
    SignalsRiskView()
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
