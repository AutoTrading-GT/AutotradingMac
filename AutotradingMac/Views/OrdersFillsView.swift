//
//  OrdersFillsView.swift
//  AutotradingMac
//

import SwiftUI

struct OrdersFillsView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Orders / Fills")
                    .font(.title3.bold())
                ordersTable
                fillsTable
            }
            .padding()
        }
        .navigationTitle("Orders / Fills")
    }

    private var ordersTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Orders")
                .font(.headline)
            if store.recentOrders.isEmpty {
                Text("No orders yet.")
                    .foregroundStyle(.secondary)
            } else {
                Table(store.recentOrders) {
                    TableColumn("ID") { row in
                        Text(String(row.orderId))
                    }
                    TableColumn("Code", value: \.code)
                    TableColumn("Side", value: \.side)
                    TableColumn("Qty") { row in
                        Text(DisplayFormatters.number(row.orderQty))
                    }
                    TableColumn("Status") { row in
                        StatusBadge(
                            text: row.status,
                            tone: .fromStatus(row.status)
                        )
                    }
                    TableColumn("Mode") { row in
                        Text(row.executionMode ?? "-")
                    }
                    TableColumn("Updated") { row in
                        Text(DisplayFormatters.dateTime(row.updatedAt))
                    }
                }
                .frame(minHeight: 200)
            }
        }
    }

    private var fillsTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Fills")
                .font(.headline)
            if store.recentFills.isEmpty {
                Text("No fills yet.")
                    .foregroundStyle(.secondary)
            } else {
                Table(store.recentFills) {
                    TableColumn("Fill ID") { row in
                        Text(String(row.fillId))
                    }
                    TableColumn("Order ID") { row in
                        Text(String(row.orderId))
                    }
                    TableColumn("Code", value: \.code)
                    TableColumn("Side", value: \.side)
                    TableColumn("Qty") { row in
                        Text(DisplayFormatters.number(row.filledQty))
                    }
                    TableColumn("Price") { row in
                        Text(DisplayFormatters.number(row.filledPrice))
                    }
                    TableColumn("Filled At") { row in
                        Text(DisplayFormatters.dateTime(row.filledAt))
                    }
                }
                .frame(minHeight: 200)
            }
        }
    }
}
