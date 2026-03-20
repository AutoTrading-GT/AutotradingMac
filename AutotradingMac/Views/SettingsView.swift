//
//  SettingsView.swift
//  AutotradingMac
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MonitoringStore
    let mode: SettingsPageMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                pageHeader
                switch mode {
                case .settings:
                    generalGrid
                case .stategy:
                    strategyContent
                }
            }
            .padding(16)
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(pageTitle)
                .font(.title3.weight(.semibold))
            Text(pageSubtitle)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
    }

    private var pageTitle: String {
        switch mode {
        case .settings:
            return "Settings"
        case .stategy:
            return "Stategy"
        }
    }

    private var pageSubtitle: String {
        switch mode {
        case .settings:
            return "애플리케이션 환경설정"
        case .stategy:
            return "전략을 선택하고 기본 조건을 확인하는 공간입니다"
        }
    }

    private var generalGrid: some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                apiConnectionPanel
                notificationPanel
            }
            HStack(alignment: .top, spacing: 16) {
                dataManagementPanel
                aboutPanel
            }
        }
    }

    private var strategyContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentStrategyOverview

            HStack(alignment: .top, spacing: 16) {
                buyConditionsPanel
                sellConditionsPanel
            }
            HStack(alignment: .top, spacing: 16) {
                strategySelectionPanel
                riskManagementPanel
            }

            HStack(spacing: 10) {
                Spacer()
                Button("임시 저장") {}
                    .buttonStyle(StrategyActionButtonStyle(primary: false))
                    .disabled(true)
                Button("적용") {}
                    .buttonStyle(StrategyActionButtonStyle(primary: true))
                    .disabled(true)
            }

            Text("읽기 전용 표시입니다. 현재는 전략 설정 저장/적용 기능이 연결되지 않았습니다.")
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
        }
    }

    private var apiConnectionPanel: some View {
        settingsPanel(
            title: "API 연결",
            trailing: { StatusBadge(text: connectionStatusText, tone: connectionStatusTone) }
        ) {
            settingsRow(icon: "key.horizontal", title: "App Key", value: "••••••••••••")
            settingsRow(icon: "lock.shield", title: "App Secret", value: "••••••••••••")
            settingsRow(icon: "wifi", title: "연결 상태", value: connectionHealthText, tone: connectionStatusTone)
            settingsRow(
                icon: "person.text.rectangle",
                title: "계좌번호",
                value: accountNumberText,
                tone: accountStatusTone,
                mono: true
            )
            Divider().opacity(0.25)
            settingsRow(title: "Backend Base URL", value: AppConfig.backendBaseURL.absoluteString, mono: true)
            settingsRow(title: "WebSocket URL", value: AppConfig.webSocketURL.absoluteString, mono: true)
        }
    }

    private var notificationPanel: some View {
        settingsPanel(title: "알림 설정") {
            toggleRow(icon: "bell", title: "거래 체결 알림", isOn: true)
            toggleRow(icon: "bell", title: "매매 신호 알림", isOn: true)
            toggleRow(icon: "bell", title: "시스템 오류 알림", isOn: false)
            readOnlyCaption
        }
    }

    private var dataManagementPanel: some View {
        settingsPanel(title: "데이터 관리") {
            toggleRow(icon: "externaldrive", title: "자동 백업", isOn: true)
            settingsRow(icon: "calendar.badge.clock", title: "로그 보관 기간", value: "30일")
            settingsRow(icon: "internaldrive", title: "사용 중인 저장공간", value: storageUsageText)
            readOnlyCaption
        }
    }

    private var aboutPanel: some View {
        settingsPanel(title: "정보") {
            settingsRow(title: "버전", value: appVersion, mono: true)
            settingsRow(title: "빌드", value: appBuild, mono: true)
            settingsRow(title: "실행 모드", value: store.runtime?.executionMode ?? "-")
            settingsRow(title: "앱 상태", value: store.runtime?.appStatus ?? "-")
            settingsRow(title: "환경", value: store.runtime?.env ?? "-")
        }
    }

    private var currentStrategyOverview: some View {
        settingsPanel(
            title: "현재 전략",
            trailing: {
                StatusBadge(
                    text: runtimeConfig.executionMode == "disabled" ? "비활성화" : "활성화",
                    tone: runtimeConfig.executionMode == "disabled" ? .neutral : .success
                )
            }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                Text("기본 템플릿")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .padding(.horizontal, 14)
                    .padding(.top, 2)

                HStack(alignment: .top, spacing: 18) {
                    strategyOverviewMetric(
                        title: "최근 수정",
                        value: relativeUpdatedText,
                        tone: .neutral
                    )
                    strategyOverviewMetric(
                        title: "실행 횟수",
                        value: "\(store.recentSignals.count)회",
                        tone: .neutral
                    )
                    strategyOverviewMetric(
                        title: "성공률",
                        value: strategySuccessRateText,
                        tone: strategySuccessRateTone
                    )
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
    }

    private var buyConditionsPanel: some View {
        settingsPanel(
            title: "매수 조건",
            trailing: { StatusBadge(text: "준비 중", tone: .neutral) }
        ) {
            strategyConditionRow(title: "신규 유입 신호", value: signalAvailabilityText(for: "new_entry"))
            strategyConditionRow(title: "순위 급상승 신호", value: signalAvailabilityText(for: "rank_jump"))
            strategyConditionRow(title: "유지 신호", value: signalAvailabilityText(for: "rank_maintained"))
            Divider().opacity(0.25)
            strategyConditionRow(
                icon: "number",
                title: "주문 수량",
                value: DisplayFormatters.number(runtimeConfig.paperOrderQty)
            )
        }
    }

    private var sellConditionsPanel: some View {
        settingsPanel(
            title: "매도 조건",
            trailing: { StatusBadge(text: "준비 중", tone: .neutral) }
        ) {
            strategyConditionRow(
                icon: "arrow.up.forward.circle",
                title: "목표 수익률 도달",
                value: percentText(fromRatio: runtimeConfig.paperTakeProfitPct)
            )
            strategyConditionRow(
                icon: "arrow.down.forward.circle",
                title: "손절 기준 달성",
                value: percentText(fromRatio: runtimeConfig.paperStopLossPct)
            )
            strategyConditionRow(
                icon: "clock",
                title: "최대 보유 시간",
                value: "\(runtimeConfig.paperMaxHoldingMinutes)분"
            )
        }
    }

    private var strategySelectionPanel: some View {
        settingsPanel(
            title: "전략 선택",
            trailing: { StatusBadge(text: "기본 설정", tone: .success) }
        ) {
            VStack(spacing: 10) {
                strategyOptionRow(
                    title: "기본 모멘텀 전략",
                    subtitle: "실행 모드: \(runtimeConfig.executionMode)",
                    icon: "chart.line.uptrend.xyaxis",
                    active: true
                )
                strategyOptionRow(
                    title: "사용자 정의 전략",
                    subtitle: "추가 예정",
                    icon: "slider.horizontal.3",
                    active: false
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private var riskManagementPanel: some View {
        settingsPanel(
            title: "위험 관리",
            trailing: { StatusBadge(text: "준비 중", tone: .neutral) }
        ) {
            strategyConditionRow(
                icon: "shield",
                title: "최대 동시 후보수",
                value: "\(runtimeConfig.riskMaxConcurrentCandidates)개"
            )
            strategyConditionRow(
                icon: "shield",
                title: "재진입 cooldown",
                value: "\(runtimeConfig.riskCooldownMinutes)분"
            )
            strategyConditionRow(
                icon: "shield",
                title: "신호 판정 윈도우",
                value: "\(runtimeConfig.riskSignalWindowMinutes)분"
            )
            strategyConditionRow(
                icon: "shield",
                title: "보유 시 신규 진입 차단",
                value: runtimeConfig.riskBlockWhenPositionExists ? "활성" : "비활성"
            )
        }
    }

    private func strategyOverviewMetric(title: String, value: String, tone: StatusTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(settingsValueColor(for: tone))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func strategyConditionRow(icon: String = "circle.fill", title: String, value: String) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
                    .frame(width: 12)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func strategyOptionRow(title: String, subtitle: String, icon: String, active: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(active ? DesignTokens.Colors.profit : DesignTokens.Colors.textTertiary)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(active ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
            }
            Spacer(minLength: 8)
            if active {
                Circle()
                    .fill(DesignTokens.Colors.success)
                    .frame(width: 7, height: 7)
            } else {
                StatusBadge(text: "추가 예정", tone: .neutral)
            }
        }
        .padding(10)
        .background(active ? DesignTokens.Colors.surface2 : DesignTokens.Colors.surface1, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(active ? DesignTokens.Colors.borderMedium : DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func settingsPanel<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        settingsPanel(title: title, trailing: { EmptyView() }, content: content)
    }

    @ViewBuilder
    private func settingsPanel<Trailing: View, Content: View>(
        title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                trailing()
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().opacity(0.3)

            VStack(spacing: 0) {
                content()
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(DesignTokens.Colors.bgPanel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func settingsRow(
        icon: String? = nil,
        title: String,
        value: String,
        tone: StatusTone = .neutral,
        mono: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .frame(width: 14)
                }
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            Text(value)
                .font(mono ? .caption.monospacedDigit() : .caption)
                .foregroundStyle(settingsValueColor(for: tone))
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func toggleRow(icon: String, title: String, isOn: Bool) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(width: 14)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            Spacer(minLength: 8)
            togglePill(isOn: isOn)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func togglePill(isOn: Bool) -> some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            RoundedRectangle(cornerRadius: 999)
                .fill(isOn ? DesignTokens.Colors.success : DesignTokens.Colors.surface2)
                .frame(width: 34, height: 20)
            Circle()
                .fill(Color.white.opacity(isOn ? 1.0 : 0.7))
                .frame(width: 15, height: 15)
                .padding(.horizontal, 2.5)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
        .accessibilityLabel(Text(isOn ? "활성" : "비활성"))
    }

    private var readOnlyCaption: some View {
        Text("읽기 전용 표시입니다. 설정 저장/제어는 아직 연결되지 않았습니다.")
            .font(.caption2)
            .foregroundStyle(DesignTokens.Colors.textQuaternary)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private var connectionStatusTone: StatusTone {
        switch store.connectionState {
        case .connected:
            return .success
        case .connecting:
            return .warning
        case .error:
            return .danger
        case .disconnected:
            return .neutral
        }
    }

    private var connectionStatusText: String {
        switch store.connectionState {
        case .connected:
            return "연결됨"
        case .connecting:
            return "연결중"
        case .error:
            return "오류"
        case .disconnected:
            return "미연결"
        }
    }

    private var connectionHealthText: String {
        switch store.connectionState {
        case .connected:
            return "정상"
        case .connecting:
            return "확인 중"
        case .error, .disconnected:
            return "주의 필요"
        }
    }

    private var accountStatusTone: StatusTone {
        guard let accountSummary = store.runtime?.accountSummary else {
            return .neutral
        }
        return accountSummary.available ? .success : .warning
    }

    private var accountNumberText: String {
        if let accountNumber = store.runtime?.accountSummary?.accountNumber,
           !accountNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return accountNumber
        }
        if let masked = store.runtime?.accountSummary?.maskedAccount,
           !masked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return masked
        }
        if let label = store.runtime?.accountSummary?.accountLabel,
           !label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return label
        }
        return "-"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }

    private var storageUsageText: String {
        let approxCount = store.recentOrders.count + store.recentFills.count + store.recentSignals.count + store.recentRiskDecisions.count
        let estimateMb = max(24, approxCount / 2)
        return "\(estimateMb) MB"
    }

    private var runtimeConfig: StrategyRuntimeConfig {
        StrategyRuntimeConfig.current
    }

    private var strategySuccessRate: Double? {
        let closed = store.recentClosedPositions.compactMap(\.realizedPnl)
        guard !closed.isEmpty else { return nil }
        let wins = closed.filter { $0 > 0 }.count
        return (Double(wins) / Double(closed.count)) * 100.0
    }

    private var strategySuccessRateText: String {
        guard let strategySuccessRate else { return "-" }
        return DisplayFormatters.percent(strategySuccessRate)
    }

    private var strategySuccessRateTone: StatusTone {
        guard let strategySuccessRate else { return .neutral }
        return strategySuccessRate >= 50 ? .success : .warning
    }

    private var relativeUpdatedText: String {
        guard let date = store.lastUpdatedAt else { return "대기 중" }
        let delta = max(Int(Date().timeIntervalSince(date)), 0)
        if delta < 10 { return "방금 전" }
        if delta < 60 { return "\(delta)초 전" }
        if delta < 3600 { return "\(delta / 60)분 전" }
        return "\(delta / 3600)시간 전"
    }

    private func signalAvailabilityText(for signalType: String) -> String {
        runtimeConfig.riskAllowedSignalTypes.contains(signalType) ? "허용" : "차단"
    }

    private func percentText(fromRatio ratio: Double) -> String {
        DisplayFormatters.percent(ratio * 100.0)
    }

    private func settingsValueColor(for tone: StatusTone) -> Color {
        switch tone {
        case .neutral:
            return DesignTokens.Colors.textPrimary
        default:
            return tone.foreground
        }
    }
}

enum SettingsPageMode {
    case settings
    case stategy
}

private struct StrategyActionButtonStyle: ButtonStyle {
    let primary: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(primary ? .semibold : .regular))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(primary ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(primary ? DesignTokens.Colors.accent : DesignTokens.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(DesignTokens.Colors.borderSubtle, lineWidth: primary ? 0 : 1)
            )
            .opacity(configuration.isPressed ? 0.85 : 1.0)
    }
}
