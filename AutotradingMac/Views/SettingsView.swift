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
        .safeAreaInset(edge: .bottom) {
            if mode == .stategy {
                strategyActionBar
                    .padding(.horizontal, DesignTokens.Layout.pagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.bgBase.opacity(0),
                                DesignTokens.Colors.bgBase.opacity(0.88),
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(pageTitle)
                    .font(.title3.weight(.semibold))
                if mode == .stategy {
                    StatusBadge(
                        text: store.strategyDirty ? "편집 중" : "저장값 기준",
                        tone: store.strategyDirty ? .warning : .neutral
                    )
                }
            }
            Text(pageSubtitle)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)
                .lineLimit(2)
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
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            Text("먼저 Basic Strategy에서 진입/청산/리스크 핵심을 설정하고, 상세 튜닝은 Advanced Settings에서 조정하세요.")
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 2)

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
            subtitle: "핵심 운용 기준과 실제 적용 상태를 묶어서 확인합니다."
        ) {
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 280), alignment: .leading, spacing: 12) {
                strategySummaryBlock(
                    title: "전략 핵심 요약",
                    subtitle: "후보 선정, 청산 기준, 리스크 한도를 빠르게 확인합니다."
                ) {
                    strategySummaryMetric(
                        title: "후보 선정",
                        value: localizedScannerMode(draft.basic.entry.selectionMode),
                        detail: "관찰 \(draft.basic.entry.topN)개 · 신호 \(draft.basic.entry.enabledSignalTypes.count)종 사용",
                        tone: .neutral
                    )
                    strategySummaryMetric(
                        title: "청산 기준",
                        value: "익절 \(DisplayFormatters.percent(draft.basic.exit.targetProfitPct)) / 손절 \(DisplayFormatters.percent(draft.basic.exit.stopLossPct))",
                        detail: "보유 \(draft.basic.exit.maxHoldingMinutes)분 · \(draft.basic.exit.forceCloseOnMarketClose ? "장 마감 전 강제 청산" : "시간 기준만 사용")",
                        tone: .neutral
                    )
                    strategySummaryMetric(
                        title: "리스크 한도",
                        value: "손실 \(DisplayFormatters.percent(draft.basic.risk.maxLossLimitPct)) · 포지션 \(DisplayFormatters.percent(draft.basic.risk.positionSizePct))",
                        detail: draft.basic.risk.dailyTradeLimitEnabled
                            ? "일일 최대 \(draft.basic.risk.dailyTradeLimitCount)회 · 동시 보유 \(draft.basic.risk.maxConcurrentPositions)개"
                            : "일일 거래 무제한 · 동시 보유 \(draft.basic.risk.maxConcurrentPositions)개",
                        tone: .neutral
                    )
                }

                strategySummaryBlock(
                    title: "적용 상태",
                    subtitle: "저장/반영 흐름과 오늘 기준 리스크 상태를 봅니다.",
                    trailing: {
                        StatusBadge(
                            text: strategyOverallApplyStatusText,
                            tone: strategyOverallApplyStatusTone
                        )
                    }
                ) {
                    strategyStatusLine(
                        title: "반영 정책",
                        detail: store.strategyApplyPolicy ?? "저장 후 다음 평가 사이클부터 반영",
                        tone: .neutral
                    )
                    strategyStatusLine(
                        title: "마지막 적용",
                        detail: store.strategyLastAppliedAt.map(DisplayFormatters.dateTime) ?? "아직 적용 이력 없음",
                        tone: .neutral
                    )
                    strategyStatusLine(
                        title: "일일 거래 제한",
                        badge: riskDailyTradeLimitBadgeText,
                        detail: riskDailyTradeLimitRuntimeText,
                        tone: riskDailyTradeLimitTone
                    )
                    strategyStatusLine(
                        title: "일일 손실 한도",
                        badge: riskDailyLossRuntimeBadgeText,
                        detail: riskDailyLossRuntimeText,
                        tone: riskDailyLossRuntimeTone
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    private func basicStrategyPanel(_ basic: BasicStrategySettingsSnapshot) -> some View {
        strategyPanel(
            title: "Basic Strategy",
            subtitle: "실제 엔진에 직접 연결되는 핵심 운용 기준입니다."
        ) {
            VStack(alignment: .leading, spacing: 18) {
                strategyCategoryBlock(
                    title: "진입 전략",
                    summary: "무엇을 우선 감시하고 어떤 신호로 진입할지 정합니다."
                ) {
                    LazyVGrid(columns: strategyAdaptiveColumns(minimum: 280), alignment: .leading, spacing: 12) {
                        strategyGroup(
                            title: "후보 선정",
                            subtitle: "후보 모집단과 감시 범위를 정합니다."
                        ) {
                            strategySegmentControlRow(
                                title: "후보 선정 방식",
                                subtitle: "기본 정렬 기준",
                                control: AnyView(
                                    AppSegmentedControl(
                                        options: [
                                            AppSegmentedOption(value: "turnover", title: "거래대금 중심"),
                                            AppSegmentedOption(value: "surge", title: "급등률 중심"),
                                        ],
                                        selection: Binding(
                                            get: { store.strategyDraft?.basic.entry.selectionMode ?? basic.entry.selectionMode },
                                            set: { store.updateStrategyBasicSelectionMode($0) }
                                        ),
                                        minSegmentWidth: 132,
                                        height: 34
                                    )
                                )
                            )
                            compactNumberControl(
                                title: "관찰 후보 수",
                                subtitle: "감시 Top-N",
                                value: basic.entry.topN,
                                range: 1...30,
                                step: 1,
                                onChange: { store.updateStrategyBasicTopN($0) }
                            )
                        }

                        strategyGroup(
                            title: "진입 신호",
                            subtitle: "실제 진입에 사용할 신호만 남깁니다."
                        ) {
                            strategySignalToggleGrid(
                                selected: basic.entry.enabledSignalTypes,
                                binding: basicSignalEnabledBinding
                            )
                        }
                    }
                }

                strategyCategoryBlock(
                    title: "청산 전략",
                    summary: "손익 기준과 시간 기준을 분리해 읽기 쉽게 정리합니다."
                ) {
                    LazyVGrid(columns: strategyAdaptiveColumns(minimum: 280), alignment: .leading, spacing: 12) {
                        strategyGroup(
                            title: "손익 기준",
                            subtitle: "수익 실현과 손절 기준입니다."
                        ) {
                            editableDoubleTextRow(
                                title: "목표 수익률",
                                unit: "%",
                                text: basicTargetProfitText,
                                onChange: { store.updateStrategyBasicTargetProfitPct(parseOptionalDouble($0) ?? 0) }
                            )
                            editableDoubleTextRow(
                                title: "손절 기준",
                                unit: "%",
                                text: basicStopLossText,
                                onChange: { store.updateStrategyBasicStopLossPct(parseOptionalDouble($0) ?? 0.1) }
                            )
                        }

                        strategyGroup(
                            title: "시간 기준",
                            subtitle: "보유 시간과 장 종료 전 정리 규칙입니다."
                        ) {
                            compactNumberControl(
                                title: "보유 시간 제한",
                                subtitle: "분",
                                value: basic.exit.maxHoldingMinutes,
                                range: 1...10_080,
                                step: 1,
                                onChange: { store.updateStrategyBasicMaxHoldingMinutes($0) }
                            )
                            strategyToggleRow(
                                title: "장 마감 5분 전 전체 청산",
                                subtitle: "정규장 종료 전에 보유 포지션을 모두 정리합니다.",
                                isOn: Binding(
                                    get: { store.strategyDraft?.basic.exit.forceCloseOnMarketClose ?? basic.exit.forceCloseOnMarketClose },
                                    set: { store.updateStrategyBasicForceCloseOnMarketClose($0) }
                                )
                            )
                        }
                    }
                }

                strategyCategoryBlock(
                    title: "리스크 관리",
                    summary: "손실 한도와 거래 제한을 묶어서 관리합니다."
                ) {
                    LazyVGrid(columns: strategyAdaptiveColumns(minimum: 280), alignment: .leading, spacing: 12) {
                        strategyGroup(
                            title: "손실/비중",
                            subtitle: "계좌 손실 허용치와 1회 진입 비중입니다."
                        ) {
                            editableDoubleTextRow(
                                title: "최대 손실 한도",
                                unit: "%",
                                text: basicMaxLossLimitText,
                                onChange: { store.updateStrategyBasicMaxLossLimitPct(parseOptionalDouble($0) ?? 0) }
                            )
                            editableDoubleTextRow(
                                title: "1회 포지션 크기",
                                unit: "%",
                                description: "전체 자산 대비",
                                text: basicPositionSizePctText,
                                onChange: { store.updateStrategyBasicPositionSizePct(parseOptionalDouble($0) ?? 0.1) }
                            )
                        }

                        strategyGroup(
                            title: "거래 제한",
                            subtitle: "일일 거래량과 동시 보유 한도를 정합니다."
                        ) {
                            strategyToggleRow(
                                title: "일일 거래 횟수 제한 사용",
                                subtitle: "꺼져 있으면 거래 횟수는 무제한입니다.",
                                isOn: Binding(
                                    get: { store.strategyDraft?.basic.risk.dailyTradeLimitEnabled ?? basic.risk.dailyTradeLimitEnabled },
                                    set: { store.updateStrategyBasicDailyTradeLimitEnabled($0) }
                                )
                            )
                            compactNumberControl(
                                title: "최대 거래 횟수",
                                subtitle: "회",
                                value: basic.risk.dailyTradeLimitCount,
                                range: 1...1_000,
                                step: 1,
                                onChange: { store.updateStrategyBasicDailyTradeLimitCount($0) }
                            )
                            .disabled(!(store.strategyDraft?.basic.risk.dailyTradeLimitEnabled ?? basic.risk.dailyTradeLimitEnabled))
                            .opacity((store.strategyDraft?.basic.risk.dailyTradeLimitEnabled ?? basic.risk.dailyTradeLimitEnabled) ? 1.0 : 0.45)

                            compactNumberControl(
                                title: "동시 보유 종목 수",
                                subtitle: "개",
                                value: basic.risk.maxConcurrentPositions,
                                range: 1...50,
                                step: 1,
                                onChange: { store.updateStrategyBasicMaxConcurrentPositions($0) }
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
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
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 16)
            } label: {
                HStack(spacing: 10) {
                    StatusBadge(text: "선택 사항", tone: .neutral)
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
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 260), alignment: .leading, spacing: 12) {
                strategyGroup(title: "기본 기준", subtitle: "스캔 기준과 평가 범위") {
                    strategySegmentControlRow(
                        title: "기본 스캔 기준",
                        subtitle: "기본 랭킹 모드",
                        control: AnyView(
                            AppSegmentedControl(
                                options: [
                                    AppSegmentedOption(value: "turnover", title: "거래대금 순위"),
                                    AppSegmentedOption(value: "surge", title: "급등률 순위"),
                                ],
                                selection: scannerDefaultModeBinding(),
                                minSegmentWidth: 120,
                                height: 34
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
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 260), alignment: .leading, spacing: 12) {
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
            LazyVGrid(columns: strategyAdaptiveColumns(minimum: 260), alignment: .leading, spacing: 12) {
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
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    StatusBadge(
                        text: store.strategyDirty ? "변경 사항 있음" : "변경 없음",
                        tone: store.strategyDirty ? .warning : .success
                    )
                    Text(store.strategyApplyPolicy ?? "저장된 값은 다음 평가 사이클부터 반영됩니다.")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(1)
                }
                Text(
                    "저장: \(store.strategyUpdatedAt.map(DisplayFormatters.dateTime) ?? "-")  |  적용: \(store.strategyLastAppliedAt.map(DisplayFormatters.dateTime) ?? "-")"
                )
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
            }
            Spacer(minLength: 12)
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
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appToolbarChrome(cornerRadius: DesignTokens.Radius.xl)
    }

    private var strategyContentMaxWidth: CGFloat { 980 }

    private func strategyAdaptiveColumns(minimum: CGFloat) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum, maximum: 420), spacing: 12, alignment: .top)]
    }

    private func strategyPanel<Content: View>(
        title: String,
        subtitle: String? = nil,
        prominence: StrategyPanelProminence = .primary,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 4) {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                    .foregroundStyle(prominence == .primary ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)

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
    }

    private func strategyPanelBackground(prominence: StrategyPanelProminence) -> LinearGradient {
        switch prominence {
        case .primary:
            return LinearGradient(
                colors: [
                    AppTheme.panelBackground.opacity(0.98),
                    DesignTokens.Colors.bgElevated.opacity(0.88),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .secondary:
            return LinearGradient(
                colors: [
                    DesignTokens.Colors.surface1.opacity(0.74),
                    DesignTokens.Colors.bgElevated.opacity(0.5),
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            content()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.Colors.surface1.opacity(0.38))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.55), lineWidth: 0.9)
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
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(subtitle)
                        .font(.caption2)
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.Colors.surface1.opacity(0.52))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.82), lineWidth: 0.9)
        )
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
                .font(.caption2.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(settingsValueColor(for: tone))
            Text(detail)
                .font(.caption2)
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
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
                if let badge {
                    StatusBadge(text: badge, tone: tone)
                }
                Spacer(minLength: 0)
            }
            Text(detail)
                .font(.caption)
                .foregroundStyle(settingsValueColor(for: tone))
                .fixedSize(horizontal: false, vertical: true)
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
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                Text(summary)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
            }
            content()
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
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.Colors.surface1.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
        )
    }

    private func strategySegmentControlRow(
        title: String,
        subtitle: String? = nil,
        control: AnyView
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                }
            }
            control
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func strategyFormRow<Control: View>(
        title: String,
        subtitle: String? = nil,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 3) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            control()
                .frame(minWidth: 124, alignment: .trailing)
        }
        .padding(.horizontal, 14)
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
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(value <= range.lowerBound)

                Text("\(value)")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(width: 44)

                Button {
                    let next = min(range.upperBound, value + step)
                    guard next != value else { return }
                    onChange(next)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(value >= range.upperBound)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .appSurfaceStyle(cornerRadius: DesignTokens.Radius.md)
        }
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
                .tint(DesignTokens.Colors.warning)
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
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            HStack(spacing: 6) {
                Button {
                    value.wrappedValue = max(0, value.wrappedValue - 1)
                } label: {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(value.wrappedValue <= 0)

                Text("\(Int(value.wrappedValue.rounded()))")
                    .font(.caption.monospacedDigit().weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .frame(minWidth: 30)

                Button {
                    value.wrappedValue = min(100, value.wrappedValue + 1)
                } label: {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(AppToolButtonStyle())
                .disabled(value.wrappedValue >= 100)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .appSurfaceStyle(cornerRadius: DesignTokens.Radius.md)
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
                .font(.caption.monospacedDigit())
                .frame(width: 88)

                if let unit {
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                }
            }
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(DesignTokens.Colors.surface1.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.95), lineWidth: 0.9)
            )
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
