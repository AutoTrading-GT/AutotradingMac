//
//  AppShellView.swift
//  AutotradingMac
//

import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var store: MonitoringStore
    @State private var selectedSection: ConsoleSection? = .dashboard

    var body: some View {
        NavigationSplitView {
            List(ConsoleSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationTitle("Autotrading Console")
        } detail: {
            Group {
                switch selectedSection ?? .dashboard {
                case .dashboard:
                    DashboardView()
                case .market:
                    MarketView()
                case .signalsRisk:
                    SignalsRiskView()
                case .ordersFills:
                    OrdersFillsView()
                case .positionsPnl:
                    PositionsPnlView()
                }
            }
            .overlay {
                if store.isLoadingSnapshot && !store.snapshotLoaded {
                    ProgressView("Loading snapshot...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .automatic) {
                    StatusBadge(
                        text: store.connectionState.rawValue,
                        tone: .fromStatus(store.connectionState.rawValue)
                    )
                    Button("Reload Snapshot") {
                        Task { await store.reloadSnapshot() }
                    }
                    Button("Reconnect WS") {
                        store.reconnectWebSocket()
                    }
                }
            }
        }
    }
}

enum ConsoleSection: String, CaseIterable, Identifiable {
    case dashboard
    case market
    case signalsRisk
    case ordersFills
    case positionsPnl

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .market:
            return "Market"
        case .signalsRisk:
            return "Signals / Risk"
        case .ordersFills:
            return "Orders / Fills"
        case .positionsPnl:
            return "Positions / PnL"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "speedometer"
        case .market:
            return "chart.line.uptrend.xyaxis"
        case .signalsRisk:
            return "shield.lefthalf.filled"
        case .ordersFills:
            return "list.bullet.rectangle.portrait"
        case .positionsPnl:
            return "briefcase"
        }
    }
}
