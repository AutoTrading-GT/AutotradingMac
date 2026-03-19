//
//  DevWorkspaceView.swift
//  AutotradingMac
//

import SwiftUI

struct DevWorkspaceView: View {
    @State private var selected: DevSubsection? = .signalsRisk

    var body: some View {
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
        .navigationTitle("Dev")
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
