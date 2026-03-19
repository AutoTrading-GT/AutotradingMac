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
            VStack(alignment: .leading, spacing: 12) {
                GlobalTopBarView(currentPageTitle: currentSection.title)

                Group {
                    switch currentSection {
                    case .dashboard:
                        DashboardView()
                    case .scanner:
                        MarketView()
                    case .chart:
                        ChartView()
                    case .logs:
                        LogsView()
                    case .settings:
                        SettingsView()
                    case .dev:
                        DevWorkspaceView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 8)
            .overlay {
                if store.isLoadingSnapshot && !store.snapshotLoaded {
                    ProgressView("Loading snapshot...")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private var currentSection: ConsoleSection {
        selectedSection ?? .dashboard
    }
}

enum ConsoleSection: String, CaseIterable, Identifiable {
    case dashboard
    case scanner
    case chart
    case logs
    case settings
    case dev

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .scanner:
            return "Scanner"
        case .chart:
            return "Chart"
        case .logs:
            return "Logs"
        case .settings:
            return "Settings"
        case .dev:
            return "Dev"
        }
    }

    var icon: String {
        switch self {
        case .dashboard:
            return "speedometer"
        case .scanner:
            return "chart.line.uptrend.xyaxis"
        case .chart:
            return "waveform.path.ecg"
        case .logs:
            return "text.append"
        case .settings:
            return "gearshape"
        case .dev:
            return "hammer"
        }
    }
}
