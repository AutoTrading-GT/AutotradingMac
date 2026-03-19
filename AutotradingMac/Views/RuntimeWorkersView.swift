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
                .foregroundStyle(.secondary)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("App Status").foregroundStyle(.secondary)
                    Text(store.runtime?.appStatus ?? "-")
                }
                GridRow {
                    Text("Readiness").foregroundStyle(.secondary)
                    Text(store.runtime?.readinessStatus ?? "-")
                }
                GridRow {
                    Text("Database").foregroundStyle(.secondary)
                    Text(store.runtime?.databaseStatus ?? "-")
                }
                GridRow {
                    Text("Execution Mode").foregroundStyle(.secondary)
                    Text(store.runtime?.executionMode ?? "-")
                }
            }
            .padding()
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))

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
                            .foregroundStyle((row.error == nil) ? Color.secondary : Color.red)
                    }
                }
            }
        }
        .padding()
    }
}
