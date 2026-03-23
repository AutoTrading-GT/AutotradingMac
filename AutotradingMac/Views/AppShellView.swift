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
            .listStyle(.sidebar)
            .navigationTitle("Autotrading Console")
            .scrollContentBackground(.hidden)
            .background(AppTheme.sidebarBackground)
            .navigationSplitViewColumnWidth(min: 196, ideal: 208, max: 220)
            .padding(.top, 2)
        } detail: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.x3) {
                GlobalTopBarView()
                if !store.connectionStatusSummary.isHealthy {
                    connectionStatusBanner(store.connectionStatusSummary)
                }

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
            .padding(.horizontal, DesignTokens.Layout.pagePadding)
            .padding(.top, 10)
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

    private func connectionStatusBanner(_ status: AppConnectionStatusSnapshot) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: status.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(status.tone.foreground)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(status.title)
                    .font(DesignTokens.Typography.bodyStrong)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(status.message)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let detail = status.detail, !detail.isEmpty {
                    Text(detail)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(status.tone.background.opacity(0.78))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(status.tone.foreground.opacity(0.22), lineWidth: 0.9)
        )
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

#Preview("App Shell") {
    AppShellView()
        .environmentObject(MonitoringStore())
        .frame(width: 1360, height: 760)
}
