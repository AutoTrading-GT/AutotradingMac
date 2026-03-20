//
//  DevWorkspaceView.swift
//  AutotradingMac
//

import SwiftUI

struct DevWorkspaceView: View {
    @EnvironmentObject private var store: MonitoringStore
    @State private var selected: DevSubsection? = .signalsRisk

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            devConnectionTools

            HStack(spacing: 0) {
                List(DevSubsection.allCases, selection: $selected) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
                .frame(minWidth: 220, maxWidth: 260)

                Divider()

                Group {
                    switch selected ?? .signalsRisk {
                    case .signalsRisk:
                        SignalsRiskView()
                    case .ordersFills:
                        OrdersFillsView()
                    case .positionsPnl:
                        PositionsPnLView()
                    case .runtimeWorkers:
                        RuntimeWorkersView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var devConnectionTools: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Dev 연결 도구")
                    .font(.headline)
                Spacer()
                StatusBadge(
                    text: store.connectionState.rawValue,
                    tone: .fromStatus(store.connectionState.rawValue)
                )
            }

            HStack(spacing: 8) {
                Button("Reload Snapshot") {
                    Task { await store.reloadSnapshot() }
                }
                Button("Reconnect WS") {
                    store.reconnectWebSocket()
                }
                Text("마지막 갱신: \(DisplayFormatters.dateTime(store.lastUpdatedAt))")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
        }
        .padding()
        .appPanelStyle()
    }
}

enum DevSubsection: String, CaseIterable, Identifiable {
    case signalsRisk
    case ordersFills
    case positionsPnl
    case runtimeWorkers

    var id: String { rawValue }

    var title: String {
        switch self {
        case .signalsRisk:
            return "Signals / Risk"
        case .ordersFills:
            return "Orders / Fills"
        case .positionsPnl:
            return "Positions / PnL"
        case .runtimeWorkers:
            return "Runtime / Workers"
        }
    }

    var icon: String {
        switch self {
        case .signalsRisk:
            return "shield.lefthalf.filled"
        case .ordersFills:
            return "list.bullet.rectangle.portrait"
        case .positionsPnl:
            return "briefcase"
        case .runtimeWorkers:
            return "server.rack"
        }
    }
}
