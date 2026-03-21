//
//  DevWorkspaceView.swift
//  AutotradingMac
//

import SwiftUI

struct DevWorkspaceView: View {
    @EnvironmentObject private var store: MonitoringStore
    @State private var selected: DevSubsection? = .signalsRisk
    @State private var showOrderLiveConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            devConnectionTools
            modeControls

            HStack(spacing: 0) {
                List(DevSubsection.allCases, selection: $selected) { section in
                    Label(section.title, systemImage: section.icon)
                        .tag(section)
                }
                .listStyle(.sidebar)
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
        .confirmationDialog(
            "주문 모드를 LIVE로 전환할까요?",
            isPresented: $showOrderLiveConfirmation,
            titleVisibility: .visible
        ) {
            Button("LIVE 전환", role: .destructive) {
                Task {
                    await store.updateOrderMode("live", confirmLive: true)
                }
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("실주문 경로가 활성화됩니다. 위험을 이해한 경우에만 전환하세요.")
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
                .buttonStyle(AppToolButtonStyle())

                Button("Reconnect WS") {
                    store.reconnectWebSocket()
                }
                .buttonStyle(AppToolButtonStyle())

                Text("마지막 갱신: \(DisplayFormatters.dateTime(store.lastUpdatedAt))")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            if let orderError = store.lastOrderModeErrorMessage, !orderError.isEmpty {
                diagnosticErrorLine(
                    title: "주문 모드 전환 실패",
                    message: orderError
                )
            }

            if let accountError = store.lastAccountSummaryErrorMessage, !accountError.isEmpty {
                diagnosticErrorLine(
                    title: "계좌정보 조회 실패",
                    message: accountError
                )
            }

            if let genericError = store.lastErrorMessage,
               !genericError.isEmpty,
               genericError != store.lastOrderModeErrorMessage,
               genericError != store.lastAccountSummaryErrorMessage {
                diagnosticErrorLine(
                    title: "일반 오류",
                    message: genericError
                )
            }
        }
        .padding()
        .appPanelStyle()
    }

    private var modeControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("운용 모드")
                .font(.headline)

            HStack(spacing: 10) {
                Text("주문 모드")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 84, alignment: .leading)
                modeChip("PAPER", selected: currentOrderMode == "paper") {
                    Task { await store.updateOrderMode("paper", confirmLive: false) }
                }
                modeChip("LIVE", selected: currentOrderMode == "live") {
                    showOrderLiveConfirmation = true
                }
                if store.modeSwitchInFlight == .orderMode {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }

            HStack(spacing: 10) {
                Text("계좌 기준")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 84, alignment: .leading)
                modeChip("PAPER", selected: currentAccountMode == "paper") {
                    Task { await store.updateAccountMode("paper") }
                }
                modeChip("LIVE", selected: currentAccountMode == "live") {
                    Task { await store.updateAccountMode("live") }
                }
                if store.modeSwitchInFlight == .accountMode {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }
        }
        .padding()
        .appPanelStyle()
    }

    private var currentOrderMode: String {
        (store.runtime?.orderMode ?? "paper").lowercased()
    }

    private var currentAccountMode: String {
        (store.runtime?.accountMode ?? "paper").lowercased()
    }

    private func modeChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .fill(selected ? DesignTokens.Colors.accentMuted.opacity(0.95) : DesignTokens.Colors.surface1.opacity(0.8))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .stroke(selected ? DesignTokens.Colors.accent.opacity(0.82) : DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
                )
        }
        .buttonStyle(.plain)
        .disabled(store.modeSwitchInFlight != nil)
    }

    private func diagnosticErrorLine(title: String, message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(message)
                    .font(.caption)
                    .textSelection(.enabled)
            }
        }
        .foregroundStyle(DesignTokens.Colors.warningMuted)
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

#Preview("Dev Workspace") {
    DevWorkspaceView()
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
