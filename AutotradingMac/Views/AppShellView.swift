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
                    .font(DesignTokens.Typography.bodyStrong)
                    .tag(section)
                    .listRowBackground(Color.clear)
            }
            .navigationTitle("Autotrading Console")
            .scrollContentBackground(.hidden)
            .background(AppTheme.sidebarBackground)
            .navigationSplitViewColumnWidth(min: 196, ideal: 208, max: 220)
        } detail: {
            VStack(alignment: .leading, spacing: 12) {
                GlobalTopBarView()

                Group {
                    switch currentSection {
                    case .dashboard:
                        DashboardView()
                    case .scanner:
                        MarketView()
                    case .chart:
                        ChartView()
                    case .stategy:
                        SettingsView(mode: .stategy)
                    case .logs:
                        LogsView()
                    case .settings:
                        SettingsView(mode: .settings)
                    case .dev:
                        DevWorkspaceView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .padding([.top, .horizontal], 12)
            .padding(.bottom, 10)
            .background(AppTheme.contentBackground)
            .overlay {
                if store.isLoadingSnapshot && !store.snapshotLoaded {
                    ProgressView("Loading snapshot...")
                        .padding()
                        .appPanelStyle()
                }
            }
        }
        .background(AppTheme.windowBackground)
    }

    private var currentSection: ConsoleSection {
        selectedSection ?? .dashboard
    }
}

enum ConsoleSection: String, CaseIterable, Identifiable {
    case dashboard
    case scanner
    case chart
    case stategy
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
        case .stategy:
            return "Stategy"
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
        case .stategy:
            return "slider.horizontal.3"
        case .logs:
            return "text.append"
        case .settings:
            return "gearshape"
        case .dev:
            return "hammer"
        }
    }
}
