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
            return "핵심 운용 파라미터를 안전하게 조정하는 공간입니다"
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
            Text("설명 문구를 유지한 상태에서 핵심 파라미터만 부분 수정할 수 있습니다.")
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 2)

            strategyToolbar

            if let draft = store.strategyDraft {
                scannerSettingsPanel(draft.scanner)

                HStack(alignment: .top, spacing: DesignTokens.Layout.sectionGap) {
                    signalSettingsPanel(draft.signal)
                    riskSettingsPanel(draft.risk)
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

            if !store.strategyValidationMessages.isEmpty {
                settingsPanel(title: "저장 전 확인 필요") {
                    ForEach(store.strategyValidationMessages, id: \.self) { message in
                        settingsRow(
                            icon: "exclamationmark.triangle",
                            title: "검증",
                            value: message,
                            tone: .warning,
                            multiline: true
                        )
                    }
                }
            }

            if let error = store.lastStrategySettingsErrorMessage, !error.isEmpty {
                settingsPanel(title: "최근 저장/조회 결과") {
                    settingsRow(
                        icon: "exclamationmark.triangle",
                        title: "메시지",
                        value: error,
                        tone: .warning,
                        multiline: true
                    )
                }
            }
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
            trailing: { StatusBadge(text: "Editable", tone: .info) }
        ) {
            settingsRow(
                icon: "scope",
                title: "무엇을 위한 기준인가요?",
                value: "시장 종목 후보를 빠르게 훑고 우선순위를 정하기 위한 스캐너 기준입니다.",
                tone: .neutral,
                multiline: true
            )
            settingsRow(
                icon: "text.alignleft",
                title: "스캔 점수",
                value: scanner.scoreDefinition.summary,
                tone: .neutral,
                multiline: true
            )
            settingsRow(
                icon: "chart.bar.doc.horizontal",
                title: "점수 반영 요소",
                value: "순위, 거래대금, 등락률을 함께 반영해 후보를 우선순위로 정렬합니다.",
                tone: .neutral,
                multiline: true
            )
            Divider().opacity(0.25)
            VStack(alignment: .leading, spacing: 10) {
                Text("기본 스캔 기준")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                AppSegmentedControl(
                    options: [
                        AppSegmentedOption(value: "turnover", title: "거래대금 순위"),
                        AppSegmentedOption(value: "surge", title: "급등률 순위"),
                    ],
                    selection: scannerDefaultModeBinding(),
                    minSegmentWidth: 120,
                    height: 34
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            editableIntRow(
                title: "상위 후보 평가 범위(Top-N)",
                value: scanner.topN,
                range: 1...30,
                step: 1,
                icon: "number",
                onChange: { store.updateStrategyScannerTopN($0) }
            )
            settingsRow(
                title: "지원 스캔 기준",
                value: scanner.modes.map(scannerModeLabel).joined(separator: " · ")
            )
            editableDoubleTextRow(
                title: "최소 거래대금 필터 (원)",
                icon: "line.3.horizontal.decrease.circle",
                text: scannerMinTurnoverText,
                onChange: { store.updateStrategyScannerMinTurnover(parseOptionalDouble($0)) }
            )
            editableDoubleTextRow(
                title: "최소 등락률 필터 (%)",
                icon: "percent",
                text: scannerMinChangePctText,
                onChange: { store.updateStrategyScannerMinChangePct(parseOptionalDouble($0)) }
            )

            scannerWeightEditor(
                title: "거래대금 순위 기준 비중",
                mode: "turnover",
                weights: scanner.scoreDefinition.weights["turnover"] ?? ScannerScoreWeightsSnapshot(rank: 40, turnover: 45, changePct: 15)
            )
            scannerWeightEditor(
                title: "급등률 순위 기준 비중",
                mode: "surge",
                weights: scanner.scoreDefinition.weights["surge"] ?? ScannerScoreWeightsSnapshot(rank: 40, turnover: 15, changePct: 45)
            )
            ForEach(Array(scanner.scoreDefinition.notes.enumerated()), id: \.offset) { _, note in
                settingsRow(
                    icon: "info.circle",
                    title: "참고",
                    value: localizedScannerNote(note),
                    tone: .neutral,
                    multiline: true
                )
            }
        }
    }

    private func signalSettingsPanel(_ signal: SignalSettingsSnapshot) -> some View {
        settingsPanel(
            title: "Signal Settings",
            trailing: { StatusBadge(text: "Editable", tone: .info) }
        ) {
            settingsRow(
                icon: "dot.scope",
                title: "무엇을 위한 기준인가요?",
                value: "스캐너 후보 중 어떤 종목을 실제 관찰 신호로 올릴지 판단하는 기준입니다.",
                tone: .neutral,
                multiline: true
            )
            editableIntRow(
                title: "신호 판단 범위(Top-N)",
                value: signal.topN,
                range: 1...30,
                step: 1,
                icon: "number",
                onChange: { store.updateStrategySignalTopN($0) }
            )
            editableIntRow(
                title: "급상승 임계값(순위 단계)",
                value: signal.rankJumpThreshold,
                range: 1...50,
                step: 1,
                icon: "arrow.up.right",
                onChange: { store.updateStrategyRankJumpThreshold($0) }
            )
            editableIntRow(
                title: "급상승 윈도우(초)",
                value: signal.rankJumpWindowSeconds,
                range: 10...86_400,
                step: 10,
                icon: "timer",
                onChange: { store.updateStrategyRankJumpWindowSeconds($0) }
            )
            editableIntRow(
                title: "상위권 유지 편차",
                value: signal.rankHoldTolerance,
                range: 0...20,
                step: 1,
                icon: "equal.circle",
                onChange: { store.updateStrategyRankHoldTolerance($0) }
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("활성 신호 유형")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                ForEach(strategySignalTypeOptions, id: \.self) { type in
                    Toggle(
                        localizedSignalType(type),
                        isOn: signalEnabledBinding(type: type)
                    )
                    .toggleStyle(.switch)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            settingsRow(
                title: "활성 신호 요약",
                value: signal.enabledSignalTypes.map(localizedSignalType).joined(separator: " · ")
            )
        }
    }

    private func riskSettingsPanel(_ risk: RiskSettingsSnapshot) -> some View {
        settingsPanel(
            title: "Risk Settings",
            trailing: { StatusBadge(text: "Editable", tone: .info) }
        ) {
            settingsRow(
                icon: "shield",
                title: "무엇을 위한 기준인가요?",
                value: "신호가 나와도 보수적으로 걸러서 과도한 진입을 막는 안전 기준입니다.",
                tone: .neutral,
                multiline: true
            )

            VStack(alignment: .leading, spacing: 8) {
                Text("허용 신호 유형")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                ForEach(strategySignalTypeOptions, id: \.self) { type in
                    Toggle(
                        localizedSignalType(type),
                        isOn: riskAllowedBinding(type: type)
                    )
                    .toggleStyle(.switch)
                    .font(.caption)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)

            editableIntRow(
                title: "최대 동시 후보 수",
                value: risk.maxConcurrentCandidates,
                range: 1...50,
                step: 1,
                icon: "person.2",
                onChange: { store.updateStrategyMaxConcurrentCandidates($0) }
            )
            editableIntRow(
                title: "재진입 대기 시간(분)",
                value: risk.cooldownMinutes,
                range: 1...1_440,
                step: 1,
                icon: "clock.badge.exclamationmark",
                onChange: { store.updateStrategyCooldownMinutes($0) }
            )
            editableIntRow(
                title: "신호 유효 시간(분)",
                value: risk.signalWindowMinutes,
                range: 1...1_440,
                step: 1,
                icon: "hourglass",
                onChange: { store.updateStrategySignalWindowMinutes($0) }
            )
            editableIntRow(
                title: "동시성 계산 시간창(분)",
                value: risk.concurrencyWindowMinutes,
                range: 1...1_440,
                step: 1,
                icon: "scope",
                onChange: { store.updateStrategyConcurrencyWindowMinutes($0) }
            )
            Toggle(
                "보유 시 신규 진입 차단",
                isOn: Binding(
                    get: { store.strategyDraft?.risk.blockWhenPositionExists ?? risk.blockWhenPositionExists },
                    set: { store.updateStrategyBlockWhenPositionExists($0) }
                )
            )
            .toggleStyle(.switch)
            .font(.caption)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var strategyToolbar: some View {
        settingsPanel(title: "편집 상태") {
            settingsRow(
                icon: "square.and.pencil",
                title: "변경 사항",
                value: store.strategyDirty ? "변경 사항 있음" : "변경 없음",
                tone: store.strategyDirty ? .warning : .success
            )
            settingsRow(
                icon: "clock.arrow.circlepath",
                title: "마지막 반영 시각",
                value: store.strategyUpdatedAt.map(DisplayFormatters.dateTime) ?? "-"
            )
            if let policy = store.strategyApplyPolicy, !policy.isEmpty {
                settingsRow(
                    icon: "info.circle",
                    title: "반영 정책",
                    value: policy,
                    tone: .neutral,
                    multiline: true
                )
            }

            HStack(spacing: 8) {
                Button("취소") {
                    store.cancelStrategyDraftChanges()
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(!store.strategyDirty || store.strategySaveInFlight)

                Button("기본값 복원") {
                    store.restoreStrategyDraftDefaults()
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(store.strategyDefaults == nil || store.strategySaveInFlight)

                Spacer()

                Button {
                    Task {
                        await store.saveStrategyDraft()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if store.strategySaveInFlight {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("저장")
                    }
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(!store.strategyDirty || store.strategySaveInFlight)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
    }

    private var strategySignalTypeOptions: [String] {
        ["new_entry", "rank_jump", "rank_maintained"]
    }

    private var scannerMinTurnoverText: String {
        guard let value = store.strategyDraft?.scanner.minTurnover else { return "" }
        return DisplayFormatters.number(value)
    }

    private var scannerMinChangePctText: String {
        guard let value = store.strategyDraft?.scanner.minChangePct else { return "" }
        return DisplayFormatters.number(value)
    }

    private func scannerDefaultModeBinding() -> Binding<String> {
        Binding(
            get: { store.strategyDraft?.scanner.defaultMode ?? "turnover" },
            set: { store.updateStrategyScannerDefaultMode($0) }
        )
    }

    private func signalEnabledBinding(type: String) -> Binding<Bool> {
        Binding(
            get: { store.strategyDraft?.signal.enabledSignalTypes.contains(type) ?? false },
            set: { store.updateStrategySignalTypeEnabled(type, isEnabled: $0) }
        )
    }

    private func riskAllowedBinding(type: String) -> Binding<Bool> {
        Binding(
            get: { store.strategyDraft?.risk.allowedSignalTypes.contains(type) ?? false },
            set: { store.updateStrategyRiskTypeAllowed(type, isAllowed: $0) }
        )
    }

    private func scannerWeightBinding(mode: String, key: String, fallback: Double) -> Binding<Double> {
        Binding(
            get: {
                guard let weights = store.strategyDraft?.scanner.scoreDefinition.weights[mode] else { return fallback }
                switch key {
                case "rank": return weights.rank
                case "turnover": return weights.turnover
                case "change_pct": return weights.changePct
                default: return fallback
                }
            },
            set: { store.updateStrategyScannerWeight(mode: mode, key: key, value: $0) }
        )
    }

    private func scannerWeightEditor(
        title: String,
        mode: String,
        weights: ScannerScoreWeightsSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            HStack(spacing: 10) {
                weightStepper(
                    label: "순위",
                    value: scannerWeightBinding(mode: mode, key: "rank", fallback: weights.rank)
                )
                weightStepper(
                    label: "거래대금",
                    value: scannerWeightBinding(mode: mode, key: "turnover", fallback: weights.turnover)
                )
                weightStepper(
                    label: "등락률",
                    value: scannerWeightBinding(mode: mode, key: "change_pct", fallback: weights.changePct)
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func weightStepper(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Stepper(
                value: value,
                in: 0...100,
                step: 1
            ) {
                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableIntRow(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        step: Int,
        icon: String? = nil,
        onChange: @escaping (Int) -> Void
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
            Spacer()
            Stepper(
                value: Binding(
                    get: { value },
                    set: { onChange($0) }
                ),
                in: range,
                step: step
            ) {
                Text("\(value)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(minWidth: 36, alignment: .trailing)
            }
            .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func editableDoubleTextRow(
        title: String,
        icon: String? = nil,
        text: String,
        onChange: @escaping (String) -> Void
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
            Spacer()
            TextField(
                "미설정",
                text: Binding(
                    get: { text },
                    set: onChange
                )
            )
            .textFieldStyle(.roundedBorder)
            .frame(width: 140)
            .font(.caption.monospacedDigit())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func parseOptionalDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    private func scannerWeightSummary(weights: ScannerScoreWeightsSnapshot) -> String {
        let rank = Int(weights.rank.rounded())
        let turnover = Int(weights.turnover.rounded())
        let change = Int(weights.changePct.rounded())
        return "순위 \(rank) · 거래대금 \(turnover) · 등락률 \(change) (가중치)"
    }

    private func scannerModeLabel(_ mode: String) -> String {
        switch mode.lowercased() {
        case "turnover":
            return "거래대금 순위"
        case "surge":
            return "급등률 순위"
        default:
            return mode
        }
    }

    private func localizedSignalType(_ type: String) -> String {
        switch type.lowercased() {
        case "new_entry":
            return "신규 진입 후보"
        case "rank_jump":
            return "순위 급상승"
        case "rank_maintained":
            return "상위권 유지"
        default:
            return type
        }
    }

    private func localizedScannerNote(_ note: String) -> String {
        note
            .replacingOccurrences(of: "turnover", with: "거래대금 순위")
            .replacingOccurrences(of: "surge", with: "급등률 순위")
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
