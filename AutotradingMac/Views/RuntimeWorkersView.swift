//
//  RuntimeWorkersView.swift
//  AutotradingMac
//

import SwiftUI

struct RuntimeWorkersView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Runtime / Workers")
                .font(.title3.bold())
            Text("개발/디버깅용 런타임 상태 페이지")
                .foregroundStyle(DesignTokens.Colors.textSecondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("App Status").foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(store.runtime?.appStatus ?? "-")
                }
                GridRow {
                    Text("Readiness").foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(store.runtime?.readinessStatus ?? "-")
                }
                GridRow {
                    Text("Database").foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(store.runtime?.databaseStatus ?? "-")
                }
                GridRow {
                    Text("Order Mode").foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(store.runtime?.orderMode ?? "-")
                }
                GridRow {
                    Text("Account Mode").foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(store.runtime?.accountMode ?? "-")
                }
            }
            .padding()
            .appPanelStyle()

            if store.workerRows.isEmpty {
                ContentUnavailableView("No worker rows", systemImage: "server.rack")
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
                            .foregroundStyle((row.error == nil) ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.danger)
                    }
                }
            }
        }
        .padding()
    }
}

#Preview("Runtime / Workers") {
    RuntimeWorkersView()
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
