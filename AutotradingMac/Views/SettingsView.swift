//
//  SettingsView.swift
//  AutotradingMac
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MonitoringStore
    let mode: SettingsPageMode
    @State private var showAdvancedSettings = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: mode == .stategy ? strategySectionSpacing : DesignTokens.Layout.sectionGap) {
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
        .safeAreaInset(edge: .bottom) {
            if mode == .stategy {
                strategyActionBar
                    .frame(maxWidth: strategyContentMaxWidth, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, DesignTokens.Layout.pagePadding)
                    .padding(.top, 14)
                    .padding(.bottom, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.bgBase.opacity(0),
                                DesignTokens.Colors.bgBase.opacity(0.84),
                                DesignTokens.Colors.bgBase,
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(pageTitle)
                    .font(.system(size: mode == .stategy ? 24 : 22, weight: .semibold))
                    .tracking(-0.3)
                if mode == .stategy {
                    strategyBadge(
                        text: store.strategyDirty ? "편집 중" : "저장값 기준",
                        tone: store.strategyDirty ? .warning : .neutral,
                        size: .compact
                    )
                }
            }
            Text(pageSubtitle)
                .font(.system(size: mode == .stategy ? 13.5 : 12, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .lineLimit(2)
                .frame(maxWidth: mode == .stategy ? 820 : 720, alignment: .leading)
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
            return "Basic Strategy에서 핵심 운용 기준을 조정하고, Advanced Settings에서 세부 튜닝을 관리합니다."
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
        VStack(alignment: .leading, spacing: strategySectionSpacing) {
            Text("먼저 Basic Strategy에서 진입/청산/리스크 핵심을 설정하고, 상세 튜닝은 Advanced Settings에서 조정하세요.")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)

            if let draft = store.strategyDraft {
                strategyOverviewPanel(draft)
                basicStrategyPanel(draft.basic)
                advancedSettingsPanel(draft)
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
        .frame(maxWidth: strategyContentMaxWidth, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .task {
            if store.strategySettings == nil {
                await store.reloadStrategySettings()
            }
        }
    }

    private func strategyOverviewPanel(_ draft: StrategySettingsSnapshot) -> some View {
        strategyPanel(
            title: "현재 전략 요약",
            subtitle: "현재 운용 전략을 한눈에 보는 스냅샷입니다.",
            trailing: {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("마지막 적용")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        Text(strategyLastAppliedSummaryText)
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .help(strategyApplyPolicyTooltipText)
                }
            }
        ) {
            LazyVGrid(columns: strategyOverviewColumns, alignment: .leading, spacing: 12) {
                strategySnapshotCard(
                    title: "후보 선정",
                    value: localizedScannerMode(draft.basic.entry.selectionMode),
                    detail: "관찰 \(draft.basic.entry.topN)개 · 신호 \(draft.basic.entry.enabledSignalTypes.count)종",
                    tone: .neutral
                )
                strategySnapshotCard(
                    title: "청산 기준",
                    value: "익절 \(DisplayFormatters.percent(draft.basic.exit.targetProfitPct)) / 손절 \(DisplayFormatters.percent(draft.basic.exit.stopLossPct))",
                    detail: draft.basic.exit.forceCloseOnMarketClose ? "보유 \(draft.basic.exit.maxHoldingMinutes)분 · 장 마감 전 청산" : "보유 \(draft.basic.exit.maxHoldingMinutes)분",
                    tone: .neutral
                )
                strategySnapshotCard(
                    title: "리스크 한도",
                    value: "최대 손실 \(DisplayFormatters.percent(draft.basic.risk.maxLossLimitPct)) · 포지션 \(DisplayFormatters.percent(draft.basic.risk.positionSizePct))",
                    detail: "동시 보유 \(draft.basic.risk.maxConcurrentPositions)개",
                    tone: .neutral
                )
                strategySnapshotCard(
                    title: "일일 거래 제한",
                    value: riskDailyTradeLimitSnapshotText,
                    badge: riskDailyTradeLimitBadgeText,
                    tone: riskDailyTradeLimitTone
                )
                strategySnapshotCard(
                    title: "일일 손실 한도",
                    value: riskDailyLossSnapshotText,
                    badge: riskDailyLossRuntimeBadgeText,
                    tone: riskDailyLossRuntimeTone
                )
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func basicStrategyPanel(_ basic: BasicStrategySettingsSnapshot) -> some View {
        strategyPanel(
            title: "Basic Strategy",
            subtitle: "실제 엔진에 직접 연결되는 핵심 운용 기준입니다."
        ) {
            VStack(alignment: .leading, spacing: 22) {
                strategyCategoryBlock(
                    title: "진입 전략",
                    summary: "후보 선정, 감시 범위, 진입 신호를 한 패널에서 정리합니다."
                ) {
                    strategyBandPanel {
                        strategyBandSegment(
                            title: "후보 선정 방식",
                            tooltip: "스캐너 상위 후보를 어떤 기준으로 우선 감시할지 정합니다."
                        ) {
                            strategySegmentedControl(
                                options: [
                                    AppSegmentedOption(value: "turnover", title: "거래대금 중심"),
                                    AppSegmentedOption(value: "surge", title: "급등률 중심"),
                                ],
                                selection: Binding(
                                    get: { store.strategyDraft?.basic.entry.selectionMode ?? basic.entry.selectionMode },
                                    set: { store.updateStrategyBasicSelectionMode($0) }
                                ),
                                minSegmentWidth: 138,
                                height: 38
                            )
                        } second: {
                            strategyBandSegment(title: "관찰 후보 수") {
                                strategyBandStepperControl(
                                    value: basic.entry.topN,
                                    range: 1...30,
                                    step: 1,
                                    unit: "Top-N",
                                    onChange: { store.updateStrategyBasicTopN($0) }
                                )
                            }
                        } third: {
                            strategyBandSegment(
                                title: "진입 신호",
                                tooltip: "실제 진입 판단에 사용할 신호만 활성화합니다. 상위권 유지는 상위 순위를 유지하며 추세가 이어질 때 진입 후보로 사용합니다."
                            ) {
                                strategySignalToggleList(
                                    selected: basic.entry.enabledSignalTypes,
                                    binding: basicSignalEnabledBinding
                                )
                            }
                        }
                    }
                }

                strategyCategoryBlock(
                    title: "청산 전략",
                    summary: "손익, 보유 시간, 장 종료 전 정리 규칙을 한 패널에서 봅니다."
                ) {
                    strategyBandPanel {
                        strategyBandSegment(title: "익절 / 손절") {
                            HStack(alignment: .top, spacing: 12) {
                                strategyBandNumericField(
                                    label: "익절",
                                    unit: "%",
                                    text: basicTargetProfitText,
                                    onChange: { store.updateStrategyBasicTargetProfitPct(parseOptionalDouble($0) ?? 0) }
                                )
                                strategyBandNumericField(
                                    label: "손절",
                                    unit: "%",
                                    text: basicStopLossText,
                                    onChange: { store.updateStrategyBasicStopLossPct(parseOptionalDouble($0) ?? 0.1) }
                                )
                            }
                        } second: {
                            strategyBandSegment(title: "보유 시간 제한") {
                                strategyBandStepperControl(
                                    value: basic.exit.maxHoldingMinutes,
                                    range: 1...10_080,
                                    step: 1,
                                    unit: "분",
                                    onChange: { store.updateStrategyBasicMaxHoldingMinutes($0) }
                                )
                            }
                        } third: {
                            strategyBandSegment(title: "장마감 청산") {
                                strategyBandToggleControl(
                                    title: "장 마감 5분 전 전체 청산",
                                    isOn: Binding(
                                        get: { store.strategyDraft?.basic.exit.forceCloseOnMarketClose ?? basic.exit.forceCloseOnMarketClose },
                                        set: { store.updateStrategyBasicForceCloseOnMarketClose($0) }
                                    )
                                )
                            }
                        }
                    }
                }

                strategyCategoryBlock(
                    title: "리스크 관리",
                    summary: "손실 한도, 포지션 비중, 거래 제한을 한 패널에서 묶어 봅니다."
                ) {
                    strategyBandPanel {
                        strategyBandSegment(title: "최대 손실 한도") {
                            strategyBandNumericField(
                                label: "손실 한도",
                                unit: "%",
                                text: basicMaxLossLimitText,
                                onChange: { store.updateStrategyBasicMaxLossLimitPct(parseOptionalDouble($0) ?? 0) }
                            )
                        } second: {
                            strategyBandSegment(
                                title: "포지션 크기",
                                tooltip: "신규 진입 한 번에 전체 자산 대비 얼마를 사용할지 정합니다."
                            ) {
                                strategyBandNumericField(
                                    label: "1회 진입 비중",
                                    unit: "%",
                                    text: basicPositionSizePctText,
                                    onChange: { store.updateStrategyBasicPositionSizePct(parseOptionalDouble($0) ?? 0.1) }
                                )
                            }
                        } third: {
                            let limitEnabled = store.strategyDraft?.basic.risk.dailyTradeLimitEnabled ?? basic.risk.dailyTradeLimitEnabled
                            strategyBandSegment(
                                title: "거래 제한",
                                tooltip: "일일 신규 진입 횟수와 동시에 보유할 종목 수를 함께 관리합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "일일 거래 횟수 제한 사용",
                                        isOn: Binding(
                                            get: { store.strategyDraft?.basic.risk.dailyTradeLimitEnabled ?? basic.risk.dailyTradeLimitEnabled },
                                            set: { store.updateStrategyBasicDailyTradeLimitEnabled($0) }
                                        )
                                    )

                                    HStack(alignment: .top, spacing: 12) {
                                        strategyBandStepperTile(
                                            label: "최대 거래 횟수",
                                            value: basic.risk.dailyTradeLimitCount,
                                            range: 1...1_000,
                                            step: 1,
                                            unit: "회",
                                            onChange: { store.updateStrategyBasicDailyTradeLimitCount($0) }
                                        )
                                        .disabled(!limitEnabled)
                                        .opacity(limitEnabled ? 1.0 : 0.42)

                                        strategyBandStepperTile(
                                            label: "동시 보유 종목 수",
                                            value: basic.risk.maxConcurrentPositions,
                                            range: 1...50,
                                            step: 1,
                                            unit: "개",
                                            onChange: { store.updateStrategyBasicMaxConcurrentPositions($0) }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func advancedSettingsPanel(_ draft: StrategySettingsSnapshot) -> some View {
        strategyPanel(
            title: "Advanced Settings",
            subtitle: "Basic Strategy를 보완하는 상세 튜닝 영역입니다.",
            prominence: .secondary
        ) {
            DisclosureGroup(isExpanded: $showAdvancedSettings) {
                VStack(alignment: .leading, spacing: 14) {
                    scannerSettingsPanel(draft.advanced.scanner)
                    signalSettingsPanel(draft.advanced.signal)
                    riskSettingsPanel(draft.advanced.risk)
                    strategyHelpPanel
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 18)
            } label: {
                HStack(spacing: 10) {
                    strategyBadge(text: "선택 사항", tone: .neutral, size: .compact)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("상세 튜닝 펼치기")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                        Text("스캐너 가중치, 신호 임계값, 리스크 시간창을 조정합니다.")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                    }
                    Spacer()
                    Text(showAdvancedSettings ? "펴짐" : "접힘")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .tint(DesignTokens.Colors.textSecondary)
        }
    }

    private func scannerSettingsPanel(_ scanner: ScannerSettingsSnapshot) -> some View {
        advancedSectionCard(
            title: "Scanner",
            summary: "후보 우선순위와 필터 기준을 조정합니다."
        ) {
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 320), alignment: .leading, spacing: 14) {
                strategyGroup(title: "기본 기준", subtitle: "스캔 기준과 평가 범위") {
                    strategySegmentControlRow(
                        title: "기본 스캔 기준",
                        subtitle: "기본 랭킹 모드",
                        control: AnyView(
                            strategySegmentedControl(
                                options: [
                                    AppSegmentedOption(value: "turnover", title: "거래대금 순위"),
                                    AppSegmentedOption(value: "surge", title: "급등률 순위"),
                                ],
                                selection: scannerDefaultModeBinding(),
                                minSegmentWidth: 126,
                                height: 36
                            )
                        )
                    )
                    compactNumberControl(
                        title: "상위 후보 평가 범위",
                        subtitle: "Top-N",
                        value: scanner.topN,
                        range: 1...30,
                        step: 1,
                        onChange: { store.updateStrategyScannerTopN($0) }
                    )
                }
                strategyGroup(title: "필터", subtitle: "최소 거래 조건") {
                    editableDoubleTextRow(
                        title: "최소 거래대금",
                        unit: "원",
                        text: scannerMinTurnoverText,
                        onChange: { store.updateStrategyScannerMinTurnover(parseOptionalDouble($0)) }
                    )
                    editableDoubleTextRow(
                        title: "최소 등락률",
                        unit: "%",
                        text: scannerMinChangePctText,
                        onChange: { store.updateStrategyScannerMinChangePct(parseOptionalDouble($0)) }
                    )
                }
                strategyGroup(title: "가중치", subtitle: "후보 점수 구성 비율") {
                    scannerWeightEditor(
                        title: "거래대금 순위 기준",
                        mode: "turnover",
                        weights: scanner.scoreDefinition.weights["turnover"] ?? ScannerScoreWeightsSnapshot(rank: 40, turnover: 45, changePct: 15)
                    )
                    scannerWeightEditor(
                        title: "급등률 순위 기준",
                        mode: "surge",
                        weights: scanner.scoreDefinition.weights["surge"] ?? ScannerScoreWeightsSnapshot(rank: 40, turnover: 15, changePct: 45)
                    )
                }
            }
        }
    }

    private func signalSettingsPanel(_ signal: SignalSettingsSnapshot) -> some View {
        advancedSectionCard(
            title: "Signal",
            summary: "후보 중 실제 신호로 인정할 범위와 임계값입니다."
        ) {
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 320), alignment: .leading, spacing: 14) {
                strategyGroup(title: "신호 판단 범위", subtitle: "신호 평가 대상 범위") {
                    compactNumberControl(
                        title: "신호 판단 범위",
                        subtitle: "Top-N",
                        value: signal.topN,
                        range: 1...30,
                        step: 1,
                        onChange: { store.updateStrategySignalTopN($0) }
                    )
                }
                strategyGroup(title: "급상승/유지 조건", subtitle: "순위 변화 판단 기준") {
                    compactNumberControl(
                        title: "급상승 임계값",
                        subtitle: "순위 단계",
                        value: signal.rankJumpThreshold,
                        range: 1...50,
                        step: 1,
                        onChange: { store.updateStrategyRankJumpThreshold($0) }
                    )
                    compactNumberControl(
                        title: "급상승 윈도우",
                        subtitle: "초",
                        value: signal.rankJumpWindowSeconds,
                        range: 10...86_400,
                        step: 10,
                        onChange: { store.updateStrategyRankJumpWindowSeconds($0) }
                    )
                    compactNumberControl(
                        title: "상위권 유지 편차",
                        subtitle: "순위 단계",
                        value: signal.rankHoldTolerance,
                        range: 0...20,
                        step: 1,
                        onChange: { store.updateStrategyRankHoldTolerance($0) }
                    )
                }
                strategyGroup(title: "활성 신호 유형", subtitle: "추가 감시할 신호 선택") {
                    strategySignalToggleGrid(
                        selected: signal.enabledSignalTypes,
                        binding: signalEnabledBinding
                    )
                }
            }
        }
    }

    private func riskSettingsPanel(_ risk: RiskSettingsSnapshot) -> some View {
        advancedSectionCard(
            title: "Risk",
            summary: "고급 리스크 게이트와 시간 제한을 조정합니다."
        ) {
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 320), alignment: .leading, spacing: 14) {
                strategyGroup(title: "허용 신호", subtitle: "리스크 게이트가 통과시킬 신호") {
                    strategySignalToggleGrid(
                        selected: risk.allowedSignalTypes,
                        binding: riskAllowedBinding
                    )
                }
                strategyGroup(title: "동시 후보 제한", subtitle: "과도한 동시 진입 방지") {
                    compactNumberControl(
                        title: "최대 동시 후보 수",
                        subtitle: "개",
                        value: risk.maxConcurrentCandidates,
                        range: 1...50,
                        step: 1,
                        onChange: { store.updateStrategyMaxConcurrentCandidates($0) }
                    )
                    strategyToggleRow(
                        title: "보유 시 신규 진입 차단",
                        subtitle: "기존 포지션이 있으면 추가 진입을 막습니다.",
                        isOn: Binding(
                            get: { store.strategyDraft?.risk.blockWhenPositionExists ?? risk.blockWhenPositionExists },
                            set: { store.updateStrategyBlockWhenPositionExists($0) }
                        )
                    )
                }
                strategyGroup(title: "재진입/시간 제한", subtitle: "보수적 재진입 판단") {
                    compactNumberControl(
                        title: "재진입 대기 시간",
                        subtitle: "분",
                        value: risk.cooldownMinutes,
                        range: 1...1_440,
                        step: 1,
                        onChange: { store.updateStrategyCooldownMinutes($0) }
                    )
                    compactNumberControl(
                        title: "신호 유효 시간",
                        subtitle: "분",
                        value: risk.signalWindowMinutes,
                        range: 1...1_440,
                        step: 1,
                        onChange: { store.updateStrategySignalWindowMinutes($0) }
                    )
                    compactNumberControl(
                        title: "동시성 계산 시간창",
                        subtitle: "분",
                        value: risk.concurrencyWindowMinutes,
                        range: 1...1_440,
                        step: 1,
                        onChange: { store.updateStrategyConcurrencyWindowMinutes($0) }
                    )
                }
            }
        }
    }

    private var strategyHelpPanel: some View {
        advancedSectionCard(
            title: "도움말",
            summary: "긴 설명 대신 필요한 운영 원칙만 남깁니다."
        ) {
            VStack(alignment: .leading, spacing: 8) {
                strategyCompactNote(
                    title: "스캔 점수",
                    detail: "실전 승률이 아니라 후보 우선순위 점수입니다."
                )
                strategyCompactNote(
                    title: "반영 시점",
                    detail: "저장된 값은 다음 평가 사이클부터 적용됩니다."
                )
                strategyCompactNote(
                    title: "안전 원칙",
                    detail: "저장 전에는 서버 설정이 바뀌지 않습니다."
                )
            }
        }
    }

    private var strategyActionBar: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    strategyBadge(
                        text: store.strategyDirty ? "변경 사항 있음" : "변경 없음",
                        tone: store.strategyDirty ? .warning : .success
                    )
                    Text(store.strategyApplyPolicy ?? "저장된 값은 다음 평가 사이클부터 반영됩니다.")
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }
                Text(
                    "저장: \(store.strategyUpdatedAt.map(DisplayFormatters.dateTime) ?? "-")  |  적용: \(store.strategyLastAppliedAt.map(DisplayFormatters.dateTime) ?? "-")"
                )
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
            }
            Spacer(minLength: 18)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface2.opacity(0.9),
                            DesignTokens.Colors.surface1.opacity(0.86),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.92), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(Color.white.opacity(0.028))
                .frame(height: 1)
                .padding(.horizontal, 1)
        }
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 3)
    }

    private var strategyContentMaxWidth: CGFloat { 1120 }

    private var strategySectionSpacing: CGFloat { 22 }

    private func strategyAdaptiveColumns(minimum: CGFloat) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum, maximum: 520), spacing: 14, alignment: .top)]
    }

    private var strategyOverviewColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 12, alignment: .top), count: 5)
    }

    private func strategyPanel<Trailing: View, Content: View>(
        title: String,
        subtitle: String? = nil,
        prominence: StrategyPanelProminence = .primary,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                    Text(title)
                        .font(.system(size: prominence == .primary ? 17 : 16, weight: .semibold))
                        .tracking(-0.1)
                        .foregroundStyle(prominence == .primary ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(DesignTokens.Colors.textTertiary)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 16)
                trailing()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 14)

            Divider().opacity(prominence == .primary ? 0.3 : 0.18)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(strategyPanelBackground(prominence: prominence))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .stroke(strategyPanelBorder(prominence: prominence), lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl - 1, style: .continuous)
                .stroke(Color.white.opacity(prominence == .primary ? 0.035 : 0.02), lineWidth: 0.8)
                .padding(1)
        )
        .overlay(alignment: .top) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(prominence == .primary ? 0.04 : 0.02), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: prominence == .primary ? 30 : 22)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous))
        }
        .shadow(
            color: Color.black.opacity(prominence == .primary ? 0.24 : 0.12),
            radius: prominence == .primary ? 12 : 6,
            x: 0,
            y: prominence == .primary ? 5 : 2
        )
    }

    private func strategyPanel<Content: View>(
        title: String,
        subtitle: String? = nil,
        prominence: StrategyPanelProminence = .primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        strategyPanel(title: title, subtitle: subtitle, prominence: prominence, trailing: { EmptyView() }, content: content)
    }

    private func strategyPanelBackground(prominence: StrategyPanelProminence) -> LinearGradient {
        switch prominence {
        case .primary:
            return LinearGradient(
                colors: [
                    DesignTokens.Colors.bgPanel.opacity(0.98),
                    DesignTokens.Colors.bgElevated.opacity(0.94),
                    DesignTokens.Colors.bgBase.opacity(0.9),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LinearGradient(
                colors: [
                    DesignTokens.Colors.surface1.opacity(0.62),
                    DesignTokens.Colors.bgElevated.opacity(0.58),
                    DesignTokens.Colors.bgBase.opacity(0.46),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func strategyPanelBorder(prominence: StrategyPanelProminence) -> Color {
        switch prominence {
        case .primary:
            return AppTheme.panelBorder
        case .secondary:
            return DesignTokens.Colors.borderSubtle.opacity(0.65)
        }
    }

    private func advancedSectionCard<Content: View>(
        title: String,
        summary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Text(summary)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface1.opacity(0.52),
                            DesignTokens.Colors.surface1.opacity(0.22),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.58), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg - 1, style: .continuous)
                .stroke(Color.white.opacity(0.018), lineWidth: 0.7)
                .padding(1)
        )
    }

    private func strategySummaryBlock<Trailing: View, Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                trailing()
            }

            VStack(alignment: .leading, spacing: 10) {
                content()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface2.opacity(0.92),
                            DesignTokens.Colors.surface1.opacity(0.5),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.82), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg - 1, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.7)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 2)
    }

    private func strategySummaryBlock<Content: View>(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        strategySummaryBlock(title: title, subtitle: subtitle, trailing: { EmptyView() }, content: content)
    }

    private func strategySummaryMetric(
        title: String,
        value: String,
        detail: String,
        tone: StatusTone
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(settingsValueColor(for: tone))
            Text(detail)
                .font(.system(size: 12.5, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func strategyStatusLine(
        title: String,
        badge: String? = nil,
        detail: String,
        tone: StatusTone
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
                if let badge {
                    strategyBadge(text: badge, tone: tone, size: .compact)
                }
                Spacer(minLength: 0)
            }
            Text(detail)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(settingsValueColor(for: tone))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func strategySnapshotCard(
        title: String,
        value: String,
        detail: String? = nil,
        badge: String? = nil,
        tone: StatusTone
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
                Spacer(minLength: 8)
                if let badge {
                    strategyBadge(text: badge, tone: tone, size: .compact)
                }
            }

            Text(value)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(settingsValueColor(for: tone))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface2.opacity(0.9),
                            DesignTokens.Colors.surface1.opacity(0.56),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.84), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg - 1, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.7)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.11), radius: 5, x: 0, y: 2)
    }

    private func strategyBadge(
        text: String,
        tone: StatusTone,
        size: StrategyBadgeSize = .regular
    ) -> some View {
        Text(text)
            .font(size.font)
            .tracking(0.15)
            .foregroundStyle(strategyBadgeForeground(tone))
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                strategyBadgeFill(tone).opacity(0.88),
                                strategyBadgeFill(tone).opacity(0.62),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .stroke(strategyBadgeBorder(tone), lineWidth: 0.9)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1)
                    .padding(.horizontal, 1)
            }
            .shadow(color: Color.black.opacity(0.14), radius: 2, x: 0, y: 1)
            .lineLimit(1)
    }

    private func strategyBadgeFill(_ tone: StatusTone) -> Color {
        switch tone {
        case .success:
            return DesignTokens.Colors.successBackground
        case .warning:
            return DesignTokens.Colors.warningBackground
        case .danger:
            return DesignTokens.Colors.dangerBackground
        case .info:
            return DesignTokens.Colors.infoBackground
        case .neutral:
            return DesignTokens.Colors.surface2.opacity(0.92)
        }
    }

    private func strategyBadgeBorder(_ tone: StatusTone) -> Color {
        switch tone {
        case .success:
            return DesignTokens.Colors.success.opacity(0.26)
        case .warning:
            return DesignTokens.Colors.warning.opacity(0.28)
        case .danger:
            return DesignTokens.Colors.danger.opacity(0.3)
        case .info:
            return DesignTokens.Colors.info.opacity(0.3)
        case .neutral:
            return DesignTokens.Colors.borderMedium.opacity(0.75)
        }
    }

    private func strategyBadgeForeground(_ tone: StatusTone) -> Color {
        switch tone {
        case .neutral:
            return DesignTokens.Colors.textSecondary
        default:
            return tone.foreground
        }
    }

    private func strategyCategoryBlock<Content: View>(
        title: String,
        summary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .tracking(-0.1)
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(summary)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            content()
        }
    }

    private func strategyBandPanel<First: View, Second: View, Third: View>(
        @ViewBuilder first: () -> First,
        @ViewBuilder second: () -> Second,
        @ViewBuilder third: () -> Third
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 0) {
                first()
                strategyBandDivider(axis: .vertical)
                second()
                strategyBandDivider(axis: .vertical)
                third()
            }
            VStack(alignment: .leading, spacing: 0) {
                first()
                strategyBandDivider(axis: .horizontal)
                second()
                strategyBandDivider(axis: .horizontal)
                third()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface2.opacity(0.74),
                            DesignTokens.Colors.surface1.opacity(0.5),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.88), lineWidth: 0.95)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.xl - 1, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.75)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 2)
    }

    private func strategyBandDivider(axis: Axis) -> some View {
        Group {
            if axis == .vertical {
                Rectangle()
                    .fill(DesignTokens.Colors.borderSubtle.opacity(0.72))
                    .frame(width: 1)
                    .padding(.vertical, 14)
            } else {
                Rectangle()
                    .fill(DesignTokens.Colors.borderSubtle.opacity(0.56))
                    .frame(height: 1)
                    .padding(.horizontal, 16)
            }
        }
        .overlay {
            Group {
                if axis == .vertical {
                    Rectangle()
                        .fill(Color.white.opacity(0.024))
                        .frame(width: 1)
                        .padding(.vertical, 14)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.02))
                        .frame(height: 1)
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    private func strategyBandSegment<Content: View>(
        title: String,
        tooltip: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let tooltip {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        .help(tooltip)
                }
            }

            content()
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }

    private func strategyBandNumericField(
        label: String,
        unit: String,
        text: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 8) {
                TextField(
                    "미설정",
                    text: Binding(
                        get: { text },
                        set: onChange
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .medium, design: .monospaced))

                Text(unit)
                    .font(.system(size: 12.5, weight: .regular))
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
            }
            .padding(.horizontal, 11)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.surface1.opacity(0.95),
                                DesignTokens.Colors.surface2.opacity(0.62),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.92), lineWidth: 0.9)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func strategyBandStepperControl(
        value: Int,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        HStack(spacing: 8) {
            Button {
                let next = max(range.lowerBound, value - step)
                guard next != value else { return }
                onChange(next)
            } label: {
                Image(systemName: "minus")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(strategyMiniButtonBackground(isPressed: false))
            .disabled(value <= range.lowerBound)

            HStack(spacing: 6) {
                Text("\(value)")
                    .font(.system(size: 13.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(unit)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
            }
            .frame(minWidth: 86, minHeight: 28)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .fill(DesignTokens.Colors.surface3.opacity(0.58))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
            )

            Button {
                let next = min(range.upperBound, value + step)
                guard next != value else { return }
                onChange(next)
            } label: {
                Image(systemName: "plus")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .background(strategyMiniButtonBackground(isPressed: false))
            .disabled(value >= range.upperBound)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface1.opacity(0.92),
                            DesignTokens.Colors.surface2.opacity(0.7),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func strategyBandStepperTile(
        label: String,
        value: Int,
        range: ClosedRange<Int>,
        step: Int,
        unit: String,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            strategyBandStepperControl(
                value: value,
                range: range,
                step: step,
                unit: unit,
                onChange: onChange
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func strategyBandToggleControl(
        title: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(DesignTokens.Colors.warningMuted)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface1.opacity(0.92),
                            DesignTokens.Colors.surface2.opacity(0.66),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
        )
    }

    private func strategySignalToggleList(
        selected: [String],
        binding: @escaping (String) -> Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(strategySignalTypeOptions, id: \.self) { type in
                HStack(spacing: 10) {
                    Toggle("", isOn: binding(type))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .tint(DesignTokens.Colors.warningMuted)

                    Text(localizedSignalType(type))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(
                            selected.contains(type)
                                ? DesignTokens.Colors.textPrimary
                                : DesignTokens.Colors.textSecondary
                        )

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .fill(
                            selected.contains(type)
                                ? DesignTokens.Colors.surface3.opacity(0.42)
                                : DesignTokens.Colors.surface1.opacity(0.46)
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .stroke(DesignTokens.Colors.borderSubtle.opacity(0.72), lineWidth: 0.85)
                )
            }
        }
    }

    private func strategyGroup<Content: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface2.opacity(0.68),
                            DesignTokens.Colors.surface1.opacity(0.48),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg - 1, style: .continuous)
                .stroke(Color.white.opacity(0.028), lineWidth: 0.7)
                .padding(1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }

    private func strategySegmentControlRow(
        title: String,
        subtitle: String? = nil,
        control: AnyView
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                }
            }
            control
                .padding(5)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .fill(DesignTokens.Colors.surface1.opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                        .stroke(DesignTokens.Colors.borderSubtle.opacity(0.62), lineWidth: 0.9)
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private func strategySegmentedControl(
        options: [AppSegmentedOption<String>],
        selection: Binding<String>,
        minSegmentWidth: CGFloat,
        height: CGFloat
    ) -> some View {
        HStack(spacing: 4) {
            ForEach(options) { option in
                let isSelected = option.value == selection.wrappedValue
                Button {
                    selection.wrappedValue = option.value
                } label: {
                    Text(option.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: minSegmentWidth)
                        .frame(height: height - 8)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                .fill(
                                    isSelected
                                        ? LinearGradient(
                                            colors: [
                                                DesignTokens.Colors.surface3.opacity(0.92),
                                                DesignTokens.Colors.accentMuted.opacity(0.52),
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        : LinearGradient(
                                            colors: [
                                                Color.clear,
                                                Color.clear,
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                .stroke(
                                    isSelected ? DesignTokens.Colors.borderMedium.opacity(0.95) : Color.clear,
                                    lineWidth: 0.9
                                )
                        )
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                .fill(Color.white.opacity(isSelected ? 0.045 : 0.0))
                                .frame(height: 1)
                                .padding(.horizontal, 1)
                        }
                }
                .buttonStyle(.plain)
                .shadow(color: Color.black.opacity(isSelected ? 0.18 : 0), radius: 3, x: 0, y: 1)
            }
        }
        .padding(4)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface1.opacity(0.96),
                            DesignTokens.Colors.surface1.opacity(0.72),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.92), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg - 1, style: .continuous)
                .stroke(Color.white.opacity(0.03), lineWidth: 0.7)
                .padding(1)
        )
    }

    private func strategyFormRow<Control: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .frame(minWidth: 144, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func compactNumberControl(
        title: String,
        subtitle: String? = nil,
        value: Int,
        range: ClosedRange<Int>,
        step: Int,
        onChange: @escaping (Int) -> Void
    ) -> some View {
        strategyFormRow(title: title, subtitle: subtitle) {
            HStack(spacing: 8) {
                Button {
                    let next = max(range.lowerBound, value - step)
                    guard next != value else { return }
                    onChange(next)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(strategyMiniButtonBackground(isPressed: false))
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(width: 50, height: 26)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .fill(DesignTokens.Colors.surface3.opacity(0.62))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .stroke(Color.white.opacity(0.05), lineWidth: 0.8)
                    )

                Button {
                    let next = min(range.upperBound, value + step)
                    guard next != value else { return }
                    onChange(next)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.plain)
                .background(strategyMiniButtonBackground(isPressed: false))
                .disabled(value >= range.upperBound)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.surface1.opacity(0.92),
                                DesignTokens.Colors.surface2.opacity(0.72),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.88), lineWidth: 0.9)
            )
        }
    }

    private func strategyMiniButtonBackground(isPressed: Bool) -> some View {
        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.surface2.opacity(isPressed ? 0.9 : 0.72),
                        DesignTokens.Colors.surface1.opacity(isPressed ? 0.82 : 0.62),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.8)
            )
    }

    private func strategyToggleRow(
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>
    ) -> some View {
        strategyFormRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(DesignTokens.Colors.warningMuted)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Colors.surface1.opacity(0.94),
                                    DesignTokens.Colors.surface2.opacity(0.64),
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                        .stroke(DesignTokens.Colors.borderSubtle.opacity(0.88), lineWidth: 0.9)
                )
        }
    }

    private func strategySignalToggleGrid(
        selected: [String],
        binding: @escaping (String) -> Binding<Bool>
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(strategySignalTypeOptions, id: \.self) { type in
                strategyToggleRow(
                    title: localizedSignalType(type),
                    subtitle: localizedSignalDescription(type),
                    isOn: binding(type)
                )
            }
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

    private var basicTargetProfitText: String {
        guard let value = store.strategyDraft?.basic.exit.targetProfitPct else { return "" }
        return DisplayFormatters.number(value)
    }

    private var basicStopLossText: String {
        guard let value = store.strategyDraft?.basic.exit.stopLossPct else { return "" }
        return DisplayFormatters.number(value)
    }

    private var basicMaxLossLimitText: String {
        guard let value = store.strategyDraft?.basic.risk.maxLossLimitPct else { return "" }
        return DisplayFormatters.number(value)
    }

    private var basicPositionSizePctText: String {
        guard let value = store.strategyDraft?.basic.risk.positionSizePct else { return "" }
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

    private func basicSignalEnabledBinding(type: String) -> Binding<Bool> {
        Binding(
            get: { store.strategyDraft?.basic.entry.enabledSignalTypes.contains(type) ?? false },
            set: { store.updateStrategyBasicSignalTypeEnabled(type, isEnabled: $0) }
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
        .padding(.vertical, 10)
    }

    private func weightStepper(label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
            HStack(spacing: 6) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .background(strategyMiniButtonBackground(isPressed: false))
                .disabled(value.wrappedValue <= 0)

                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(minWidth: 32, minHeight: 22)
                    .background(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .fill(DesignTokens.Colors.surface3.opacity(0.54))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
                            .stroke(Color.white.opacity(0.04), lineWidth: 0.8)
                    )

                Button {
                    value.wrappedValue = min(100, value.wrappedValue + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .background(strategyMiniButtonBackground(isPressed: false))
                .disabled(value.wrappedValue >= 100)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.surface1.opacity(0.9),
                                DesignTokens.Colors.surface2.opacity(0.66),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.88), lineWidth: 0.9)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func editableDoubleTextRow(
        title: String,
        unit: String? = nil,
        description: String? = nil,
        text: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        strategyFormRow(title: title, subtitle: description) {
            HStack(spacing: 6) {
                TextField(
                    "미설정",
                    text: Binding(
                        get: { text },
                        set: onChange
                    )
                )
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .frame(width: 96)

                if let unit {
                    Text(unit)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 38)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.surface1.opacity(0.95),
                                DesignTokens.Colors.surface2.opacity(0.62),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.95), lineWidth: 0.9)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(Color.white.opacity(0.03))
                    .frame(height: 1)
                    .padding(.horizontal, 1)
            }
        }
    }

    private func strategyCompactNote(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
        }
    }

    private func parseOptionalDouble(_ text: String) -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return nil
        }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        return Double(normalized)
    }

    private func localizedSignalType(_ type: String) -> String {
        switch type.lowercased() {
        case "new_entry":
            return "신규 진입"
        case "rank_jump":
            return "순위 급상승"
        case "rank_maintained":
            return "상위권 유지"
        default:
            return type
        }
    }

    private func localizedSignalDescription(_ type: String) -> String {
        switch type.lowercased() {
        case "new_entry":
            return "상위 후보 중 즉시 진입 가능한 신규 종목"
        case "rank_jump":
            return "짧은 시간 내 순위가 빠르게 상승한 종목"
        case "rank_maintained":
            return "상위권을 유지하며 추세가 이어지는 종목"
        default:
            return "사용자 정의 신호"
        }
    }

    private func localizedScannerMode(_ mode: String) -> String {
        switch mode.lowercased() {
        case "turnover":
            return "거래대금 중심"
        case "surge":
            return "급등률 중심"
        default:
            return mode
        }
    }

    private func strategyGroupStatusText(_ group: String) -> String {
        guard let status = store.strategyGroupApplyStatus(group) else {
            return "상태 정보 없음"
        }
        switch status.appliedStatus.lowercased() {
        case "applied":
            return "반영 완료"
        case "pending_next_cycle":
            return "다음 평가 사이클 반영 대기"
        case "partial":
            return "부분 반영 (\(status.notWiredFields.count)개 항목 미연결)"
        case "not_wired":
            return "저장 전용(엔진 미연결)"
        default:
            return status.appliedStatus
        }
    }

    private func strategyGroupStatusTone(_ group: String) -> StatusTone {
        guard let status = store.strategyGroupApplyStatus(group) else { return .neutral }
        switch status.appliedStatus.lowercased() {
        case "applied":
            return .success
        case "pending_next_cycle":
            return .warning
        case "partial":
            return .warning
        case "not_wired":
            return .neutral
        default:
            return .neutral
        }
    }

    private var strategyOverallApplyStatusText: String {
        if store.strategyDirty {
            return "저장 전 변경 있음"
        }

        let statuses = ["entry", "exit", "risk"].compactMap { store.strategyGroupApplyStatus($0)?.appliedStatus.lowercased() }
        if statuses.contains("partial") {
            return "부분 반영"
        }
        if statuses.contains("pending_next_cycle") {
            return "다음 사이클 반영 대기"
        }
        if statuses.allSatisfy({ $0 == "applied" }) && !statuses.isEmpty {
            return "반영 완료"
        }
        return "상태 확인 필요"
    }

    private var strategyOverallApplyStatusTone: StatusTone {
        if store.strategyDirty {
            return .warning
        }

        let statuses = ["entry", "exit", "risk"].compactMap { store.strategyGroupApplyStatus($0)?.appliedStatus.lowercased() }
        if statuses.contains("partial") || statuses.contains("pending_next_cycle") {
            return .warning
        }
        if statuses.allSatisfy({ $0 == "applied" }) && !statuses.isEmpty {
            return .success
        }
        return .neutral
    }

    private var strategyApplyPolicyTooltipText: String {
        "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다."
    }

    private var strategyLastAppliedSummaryText: String {
        store.strategyLastAppliedAt.map(DisplayFormatters.dateTime) ?? "아직 적용 이력 없음"
    }

    private var riskDailyTradeLimitBadgeText: String {
        let configuredRisk = store.strategyDraft?.basic.risk
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue
        let enabled = effective?["daily_trade_limit_enabled"]?.boolValue
            ?? configuredRisk?.dailyTradeLimitEnabled
            ?? false
        let remaining = effective?["daily_trade_limit_remaining"]?.intValue

        if !enabled {
            return "무제한"
        }
        if let remaining, remaining <= 0 {
            return "한도 도달"
        }
        return "활성"
    }

    private var riskDailyTradeLimitTone: StatusTone {
        let configuredRisk = store.strategyDraft?.basic.risk
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue
        let enabled = effective?["daily_trade_limit_enabled"]?.boolValue
            ?? configuredRisk?.dailyTradeLimitEnabled
            ?? false
        let remaining = effective?["daily_trade_limit_remaining"]?.intValue

        if !enabled {
            return .neutral
        }
        if let remaining, remaining <= 0 {
            return .danger
        }
        return .success
    }

    private var riskDailyTradeLimitSnapshotText: String {
        let configuredRisk = store.strategyDraft?.basic.risk
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue

        let enabled = effective?["daily_trade_limit_enabled"]?.boolValue
            ?? configuredRisk?.dailyTradeLimitEnabled
            ?? false
        let limit = effective?["daily_trade_limit_count"]?.intValue
            ?? configuredRisk?.dailyTradeLimitCount
            ?? 0
        let todayUsed = effective?["today_trade_count"]?.intValue
        let remaining = effective?["daily_trade_limit_remaining"]?.intValue

        if !enabled {
            return "무제한"
        }
        if let todayUsed, let remaining {
            return "오늘 \(todayUsed)/\(limit)회 · 남은 \(remaining)회"
        }
        if let todayUsed {
            return "오늘 \(todayUsed)/\(limit)회"
        }
        return "최대 \(limit)회"
    }

    private var riskDailyTradeLimitRuntimeText: String {
        let configuredRisk = store.strategyDraft?.basic.risk
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue

        let enabled = effective?["daily_trade_limit_enabled"]?.boolValue
            ?? configuredRisk?.dailyTradeLimitEnabled
            ?? false
        let limit = effective?["daily_trade_limit_count"]?.intValue
            ?? configuredRisk?.dailyTradeLimitCount
            ?? 0
        let todayUsed = effective?["today_trade_count"]?.intValue
        let remaining = effective?["daily_trade_limit_remaining"]?.intValue

        if !enabled {
            return "무제한"
        }
        if let todayUsed, let remaining {
            return "오늘 \(todayUsed)/\(limit)회 사용, 남은 \(remaining)회"
        }
        if let todayUsed {
            return "오늘 \(todayUsed)/\(limit)회 사용"
        }
        return "최대 \(limit)회"
    }

    private var riskDailyLossRuntimeText: String {
        let configuredRisk = store.strategyDraft?.basic.risk
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue

        let maxLossLimitPct = effective?["max_loss_limit_pct"]?.doubleValue
            ?? configuredRisk?.maxLossLimitPct
            ?? 0.0
        let todayLossPct = effective?["today_loss_pct"]?.doubleValue
        let todayTotalPnl = effective?["today_total_pnl"]?.doubleValue
        let reached = effective?["daily_loss_limit_reached"]?.boolValue ?? false

        let limitText = DisplayFormatters.percent(maxLossLimitPct)
        if let todayLossPct {
            let lossText = DisplayFormatters.percent(todayLossPct)
            if let todayTotalPnl {
                let pnlText = DisplayFormatters.krw(todayTotalPnl)
                let state = reached ? "한도 도달" : "정상"
                return "오늘 손익 \(pnlText), 손실률 \(lossText) / 한도 \(limitText) (\(state))"
            }
            let state = reached ? "한도 도달" : "정상"
            return "오늘 손실률 \(lossText) / 한도 \(limitText) (\(state))"
        }
        return "한도 \(limitText) · 오늘 손실률 계산 대기"
    }

    private var riskDailyLossSnapshotText: String {
        let configuredRisk = store.strategyDraft?.basic.risk
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue

        let maxLossLimitPct = effective?["max_loss_limit_pct"]?.doubleValue
            ?? configuredRisk?.maxLossLimitPct
            ?? 0.0
        let todayLossPct = effective?["today_loss_pct"]?.doubleValue ?? 0.0

        if effective?["today_loss_pct"]?.doubleValue == nil {
            return "한도 \(DisplayFormatters.percent(maxLossLimitPct))"
        }
        return "손실률 \(DisplayFormatters.percent(todayLossPct)) / 한도 \(DisplayFormatters.percent(maxLossLimitPct))"
    }

    private var riskDailyLossRuntimeBadgeText: String {
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue
        if (effective?["daily_loss_limit_reached"]?.boolValue ?? false) {
            return "한도 도달"
        }
        if effective?["today_loss_pct"]?.doubleValue == nil {
            return "계산 대기"
        }
        return "정상"
    }

    private var riskDailyLossRuntimeTone: StatusTone {
        let effective = store.strategyGroupApplyStatus("risk")?.effectiveValue
        if (effective?["daily_loss_limit_reached"]?.boolValue ?? false) {
            return .danger
        }
        if effective?["today_loss_pct"]?.doubleValue == nil {
            return .warning
        }
        return .neutral
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
                    .font(DesignTokens.Typography.sectionTitle)
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
        .appPanelStyle(cornerRadius: DesignTokens.Radius.xl)
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

private enum StrategyPanelProminence {
    case primary
    case secondary
}

private enum StrategyBadgeSize {
    case regular
    case compact

    var font: Font {
        switch self {
        case .regular:
            return .system(size: 12, weight: .semibold)
        case .compact:
            return .system(size: 11, weight: .semibold)
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .regular: return 10
        case .compact: return 8
        }
    }

    var verticalPadding: CGFloat {
        switch self {
        case .regular: return 4.5
        case .compact: return 3.5
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .regular: return 7
        case .compact: return 6
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
