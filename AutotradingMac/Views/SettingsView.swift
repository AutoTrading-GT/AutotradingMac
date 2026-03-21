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
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
                pageHeader
                switch mode {
                case .settings:
                    generalGrid
                case .stategy:
                    strategyContent
                }
            }
            .padding(DesignTokens.Layout.pagePadding)
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
            return "현재 운용 기준을 읽기 전용으로 확인하는 공간입니다"
        }
    }

    private var generalGrid: some View {
        VStack(spacing: DesignTokens.Layout.sectionGap) {
            HStack(alignment: .top, spacing: DesignTokens.Layout.sectionGap) {
                apiConnectionPanel
                notificationPanel
            }
            HStack(alignment: .top, spacing: DesignTokens.Layout.sectionGap) {
                dataManagementPanel
                aboutPanel
            }
        }
    }

    private var strategyContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            Text("Strategy Settings 1단계: read-only 브리핑")
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 2)

            if let settings = store.strategySettings {
                scannerSettingsPanel(settings.scanner)

                HStack(alignment: .top, spacing: DesignTokens.Layout.sectionGap) {
                    signalSettingsPanel(settings.signal)
                    riskSettingsPanel(settings.risk)
                }
            } else {
                settingsPanel(title: "전략 설정 로드 상태") {
                    if let error = store.lastStrategySettingsErrorMessage, !error.isEmpty {
                        settingsRow(
                            icon: "exclamationmark.triangle",
                            title: "조회 상태",
                            value: error,
                            tone: .warning
                        )
                    } else {
                        settingsRow(
                            icon: "clock",
                            title: "조회 상태",
                            value: "전략 설정을 불러오는 중입니다...",
                            tone: .neutral
                        )
                    }
                    readOnlyCaption
                }
            }

            Text("이 페이지는 조회 전용입니다. 저장/apply 기능은 아직 연결되지 않았습니다.")
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
        }
        .task {
            if store.strategySettings == nil {
                await store.reloadStrategySettings()
            }
        }
    }

    private func scannerSettingsPanel(_ scanner: ScannerSettingsSnapshot) -> some View {
        settingsPanel(
            title: "Scanner Settings",
            trailing: { StatusBadge(text: "Read-only", tone: .neutral) }
        ) {
            settingsRow(
                icon: "scope",
                title: "스캐너 점수 성격",
                value: scanner.scoreDefinition.name,
                tone: .neutral
            )
            settingsRow(
                icon: "text.alignleft",
                title: "설명",
                value: scanner.scoreDefinition.summary,
                tone: .neutral,
                multiline: true
            )
            settingsRow(
                icon: "function",
                title: "계산 기준",
                value: scanner.scoreDefinition.formulaBasis,
                tone: .neutral,
                multiline: true
            )
            Divider().opacity(0.25)
            settingsRow(
                icon: "line.3.horizontal.decrease.circle",
                title: "지원 모드",
                value: scanner.modes.joined(separator: ", ")
            )
            settingsRow(title: "기본 모드", value: scanner.defaultMode)
            settingsRow(title: "페이지 증가 단위", value: "\(scanner.pageStep)")
            settingsRow(title: "스캔 최대 노출", value: "\(scanner.maxLimit)")
            settingsRow(title: "후보군 상한", value: "\(scanner.candidateLimit)")
            settingsRow(title: "랭킹 소스", value: scanner.rankingSource)

            if let turnover = scanner.scoreDefinition.weights["turnover"] {
                settingsRow(
                    icon: "chart.bar.xaxis",
                    title: "가중치(turnover)",
                    value: scoreWeightText(turnover)
                )
            }
            if let surge = scanner.scoreDefinition.weights["surge"] {
                settingsRow(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "가중치(surge)",
                    value: scoreWeightText(surge)
                )
            }
            ForEach(Array(scanner.scoreDefinition.notes.enumerated()), id: \.offset) { _, note in
                settingsRow(
                    icon: "info.circle",
                    title: "노트",
                    value: note,
                    tone: .neutral,
                    multiline: true
                )
            }
        }
    }

    private func signalSettingsPanel(_ signal: SignalSettingsSnapshot) -> some View {
        settingsPanel(
            title: "Signal Settings",
            trailing: { StatusBadge(text: "Read-only", tone: .neutral) }
        ) {
            settingsRow(title: "Top-N 범위", value: "\(signal.topN)")
            settingsRow(title: "급상승 임계값", value: "\(signal.rankJumpThreshold)")
            settingsRow(title: "급상승 윈도우(초)", value: "\(signal.rankJumpWindowSeconds)")
            settingsRow(title: "유지 허용 편차", value: "\(signal.rankHoldTolerance)")
            settingsRow(title: "활성 신호 타입", value: signal.enabledSignalTypes.joined(separator: ", "))
        }
    }

    private func riskSettingsPanel(_ risk: RiskSettingsSnapshot) -> some View {
        settingsPanel(
            title: "Risk Settings",
            trailing: { StatusBadge(text: "Read-only", tone: .neutral) }
        ) {
            settingsRow(title: "허용 신호 타입", value: risk.allowedSignalTypes.joined(separator: ", "))
            settingsRow(title: "최대 동시 후보", value: "\(risk.maxConcurrentCandidates)")
            settingsRow(title: "쿨다운(분)", value: "\(risk.cooldownMinutes)")
            settingsRow(title: "신호 윈도우(분)", value: "\(risk.signalWindowMinutes)")
            settingsRow(title: "동시성 윈도우(분)", value: "\(risk.concurrencyWindowMinutes)")
            settingsRow(
                title: "보유 시 신규 진입 차단",
                value: risk.blockWhenPositionExists ? "활성" : "비활성"
            )
        }
    }

    private func scoreWeightText(_ weights: ScannerScoreWeightsSnapshot) -> String {
        let rank = Int(weights.rank.rounded())
        let turnover = Int(weights.turnover.rounded())
        let change = Int(weights.changePct.rounded())
        return "순위 \(rank) / 거래대금 \(turnover) / 등락률 \(change)"
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
                title: "계좌번호(마스킹)",
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
            settingsRow(title: "주문 모드", value: store.runtime?.orderMode ?? "-")
            settingsRow(title: "계좌정보 모드", value: store.runtime?.accountMode ?? "-")
            settingsRow(title: "앱 상태", value: store.runtime?.appStatus ?? "-")
            settingsRow(title: "환경", value: store.runtime?.env ?? "-")
        }
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
        mono: Bool = false,
        multiline: Bool = false
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
                .lineLimit(multiline ? nil : 1)
                .truncationMode(multiline ? .tail : .middle)
                .multilineTextAlignment(.trailing)
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

#Preview("Settings") {
    SettingsView(mode: .settings)
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}

#Preview("Stategy") {
    SettingsView(mode: .stategy)
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
