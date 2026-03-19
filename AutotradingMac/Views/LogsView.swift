//
//  LogsView.swift
//  AutotradingMac
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.title3.bold())
            Text("Signals / Risk / Orders / Fills를 운영 관점에서 한 화면에 요약합니다.")
                .foregroundStyle(.secondary)

            if recentEventRows.isEmpty {
                ContentUnavailableView("No recent events", systemImage: "tray")
            } else {
                Table(recentEventRows) {
                    TableColumn("Time") { row in
                        Text(DisplayFormatters.dateTime(row.timestamp))
                    }
                    TableColumn("Type", value: \.category)
                    TableColumn("Code", value: \.code)
                    TableColumn("Status") { row in
                        if let status = row.status {
                            StatusBadge(text: status, tone: .fromStatus(status))
                        } else {
                            Text("-")
                        }
                    }
                    TableColumn("Detail", value: \.message)
                }
            }
        }
        .padding()
        .navigationTitle("Logs")
    }

    private var recentEventRows: [RecentEventRow] {
        var rows: [RecentEventRow] = []

        rows.append(
            contentsOf: store.recentSignals.map { signal in
                RecentEventRow(
                    id: "signal-\(signal.id)",
                    timestamp: signal.createdAt,
                    category: "signal.generated",
                    code: signal.code,
                    status: signal.signalType,
                    message: "confidence=\(DisplayFormatters.number(signal.confidence))"
                )
            }
        )

        rows.append(
            contentsOf: store.recentRiskDecisions.map { risk in
                RecentEventRow(
                    id: "risk-\(risk.id)",
                    timestamp: risk.createdAt,
                    category: "risk.\(risk.decision)",
                    code: risk.code ?? "-",
                    status: risk.decision,
                    message: risk.reason
                )
            }
        )

        rows.append(
            contentsOf: store.recentOrders.map { order in
                RecentEventRow(
                    id: "order-\(order.orderId)-\(order.updatedAt.timeIntervalSince1970)",
                    timestamp: order.updatedAt,
                    category: "order.updated",
                    code: order.code,
                    status: order.status,
                    message: "\(order.side) qty=\(DisplayFormatters.number(order.orderQty))"
                )
            }
        )

        rows.append(
            contentsOf: store.recentFills.map { fill in
                RecentEventRow(
                    id: "fill-\(fill.fillId)",
                    timestamp: fill.filledAt,
                    category: "fill.received",
                    code: fill.code,
                    status: fill.side,
                    message: "qty=\(DisplayFormatters.number(fill.filledQty)) @ \(DisplayFormatters.number(fill.filledPrice))"
                )
            }
        )

        return rows
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(120)
            .map { $0 }
    }
}

private struct RecentEventRow: Identifiable {
    let id: String
    let timestamp: Date
    let category: String
    let code: String
    let status: String?
    let message: String
}
