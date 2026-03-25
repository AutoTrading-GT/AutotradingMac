//
//  SettingsView.swift
//  AutotradingMac
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MonitoringStore
    let mode: SettingsPageMode
    @State private var showAdvancedSettings = false
    @State private var selectedStrategyTemplateID: String?

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
        .task {
            guard mode == .settings else { return }
            await store.reloadAppSettings()
            await store.refreshNotificationAuthorizationStatus()
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
            return "Strategy"
        }
    }

    private var pageSubtitle: String {
        switch mode {
        case .settings:
            return "애플리케이션 환경설정"
        case .stategy:
            return "전략 템플릿 선택, 전략별 파라미터 조정, 공통 리스크/실행 가드를 분리해서 관리합니다."
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
            Text("현재 활성 전략과 선택 가능한 전략 템플릿을 분리해서 보여주고, 공통 리스크/실행 설정은 전략 전환과 별개로 유지합니다.")
                .font(.system(size: 13.5, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 2)
                .padding(.bottom, 2)

            if let draft = store.strategyDraft {
                strategyOverviewPanel(draft)
                strategySelectionPanel(draft)

                if let template = selectedStrategyTemplate(from: draft) {
                    if template.strategyId == draft.activeStrategyId && template.selectable {
                        strategySpecificSettingsPanel(draft, template: template)
                    } else {
                        strategyTemplatePreviewPanel(draft, template: template)
                    }
                }

                commonRiskExecutionPanel(draft)
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
        let activeTemplate = draft.activeTemplate
        return strategyPanel(
            title: "현재 전략 요약",
            subtitle: "현재 실제 운용 중인 전략 템플릿과 공통 가드를 한눈에 보는 스냅샷입니다.",
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
                    title: "활성 전략",
                    value: activeTemplate?.displayName ?? "알 수 없음",
                    detail: "\(activeTemplate?.category.uppercased() ?? "UNKNOWN") · \(activeTemplate?.shortDescription ?? "전략 메타 없음")",
                    tone: .neutral
                )
                strategySnapshotCard(
                    title: "전략형 진입",
                    value: localizedScannerMode(draft.basic.entry.selectionMode),
                    detail: "관찰 \(draft.basic.entry.topN)개 · 신호 \(draft.basic.entry.enabledSignalTypes.count)종",
                    tone: .neutral
                )
                strategySnapshotCard(
                    title: "전략형 청산",
                    value: "익절 \(DisplayFormatters.percent(draft.basic.exit.targetProfitPct)) / 손절 \(DisplayFormatters.percent(draft.basic.exit.stopLossPct))",
                    detail: "최대 보유 \(draft.basic.exit.maxHoldingMinutes)분",
                    tone: .neutral
                )
                strategySnapshotCard(
                    title: "공통 리스크",
                    value: "최대 손실 \(DisplayFormatters.percent(draft.basic.risk.maxLossLimitPct)) · 포지션 \(DisplayFormatters.percent(draft.basic.risk.positionSizePct))",
                    detail: "동시 보유 \(draft.basic.risk.maxConcurrentPositions)개 · 장마감 \(draft.basic.exit.forceCloseOnMarketClose ? "청산" : "유지")",
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

    private func strategySelectionPanel(_ draft: StrategySettingsSnapshot) -> some View {
        let selectedStrategyId = resolvedSelectedStrategyTemplateID(for: draft)
        return strategyPanel(
            title: "전략 선택",
            subtitle: "활성 전략 전환과 프리뷰용 후보 전략을 카드 단위로 구분합니다."
        ) {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(draft.strategyTemplates) { template in
                    Button {
                        selectedStrategyTemplateID = template.strategyId
                    } label: {
                        HStack(alignment: .top, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(template.displayName)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Colors.textPrimary)
                                    strategyBadge(
                                        text: templateStatusText(template),
                                        tone: templateStatusTone(template),
                                        size: .compact
                                    )
                                }
                                Text(template.shortDescription)
                                    .font(.system(size: 12.5, weight: .regular))
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("유형 \(template.category.uppercased()) · \(template.implementationNote)")
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
                            }

                            Spacer(minLength: 12)

                            VStack(alignment: .trailing, spacing: 6) {
                                if template.strategyId == draft.activeStrategyId {
                                    Text("현재 활성")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                } else if template.selectable {
                                    Text("선택 가능")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                } else {
                                    Text("프리뷰 전용")
                                        .font(.system(size: 11.5, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                                }
                                Text(template.strategyId)
                                    .font(.system(size: 10.5, weight: .medium))
                                    .foregroundStyle(DesignTokens.Colors.textQuaternary)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(templateCardFill(template, isSelected: template.strategyId == selectedStrategyId))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(templateCardStroke(template, isSelected: template.strategyId == selectedStrategyId), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let selectedTemplate = draft.template(id: selectedStrategyId) {
                    HStack(alignment: .center, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectionSummaryTitle(for: selectedTemplate, draft: draft))
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                            Text(selectionSummaryDetail(for: selectedTemplate, draft: draft))
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(DesignTokens.Colors.textTertiary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        if selectedTemplate.selectable && selectedTemplate.strategyId != draft.activeStrategyId {
                            Button("이 전략으로 전환") {
                                selectedStrategyTemplateID = selectedTemplate.strategyId
                                store.updateStrategyActiveTemplate(selectedTemplate.strategyId)
                            }
                            .buttonStyle(AppToolButtonStyle())
                        } else {
                            strategyBadge(
                                text: templateStatusText(selectedTemplate),
                                tone: templateStatusTone(selectedTemplate),
                                size: .compact
                            )
                        }
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    @ViewBuilder
    private func strategySpecificSettingsPanel(
        _ draft: StrategySettingsSnapshot,
        template: StrategyTemplateSnapshot
    ) -> some View {
        if template.strategyId == "opening_pullback_reentry" {
            openingPullbackStrategyPanel(template: template)
        } else {
            VStack(alignment: .leading, spacing: strategySectionSpacing) {
                basicStrategyPanel(template: template)
                advancedSettingsPanel()
            }
        }
    }

    private func strategyTemplatePreviewPanel(
        _ draft: StrategySettingsSnapshot,
        template: StrategyTemplateSnapshot
    ) -> some View {
        let params = draft.strategyParams[template.strategyId] ?? [:]
        let subtitle: String = {
            if template.selectable && template.wiredToEngine {
                return "\(template.displayName)은 엔진 연결 전략입니다. 활성 전략으로 전환하면 전용 편집 폼이 열립니다."
            }
            return "\(template.displayName)은 아직 엔진 미연결 상태입니다. 선택 카드는 미리 볼 수 있지만 활성화되지는 않습니다."
        }()
        return strategyPanel(
            title: "전략 프리뷰",
            subtitle: subtitle
        ) {
            VStack(alignment: .leading, spacing: 12) {
                strategyBadge(
                    text: templateStatusText(template),
                    tone: templateStatusTone(template),
                    size: .compact
                )
                ForEach(template.configurableFields, id: \.fieldId) { field in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(field.label)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                            Text(field.description)
                                .font(.system(size: 11.5, weight: .regular))
                                .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        }
                        Spacer(minLength: 12)
                        Text(strategyTemplateValueText(field: field, params: params))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(field.wired ? DesignTokens.Colors.textSecondary : DesignTokens.Colors.textTertiary)
                            .multilineTextAlignment(.trailing)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func commonRiskExecutionPanel(_ draft: StrategySettingsSnapshot) -> some View {
        strategyPanel(
            title: "공통 리스크 / 실행 설정",
            subtitle: "전략 템플릿을 바꿔도 유지되는 손실 한도, 포지션 크기, 장마감 실행 가드를 관리합니다."
        ) {
            VStack(alignment: .leading, spacing: 22) {
                strategyCategoryBlock(
                    title: "공통 리스크 / 실행 가드",
                    summary: "손실 한도와 포지션 크기, 거래 제한, 장마감 청산을 전략별 파라미터에서 분리합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(title: "최대 손실 한도") {
                                strategyBandNumericField(
                                    label: "손실 한도",
                                    unit: "%",
                                    text: basicMaxLossLimitTextBinding
                                )
                            }
                        },
                        second: {
                            strategyBandSegment(
                                title: "포지션 크기",
                                tooltip: "활성 전략이 바뀌어도 유지할 1회 진입 비중입니다."
                            ) {
                                strategyBandNumericField(
                                    label: "1회 진입 비중",
                                    unit: "%",
                                    text: basicPositionSizePctTextBinding
                                )
                            }
                        },
                        third: {
                            strategyBandSegment(
                                title: "거래 제한 / 장마감 가드",
                                tooltip: "일일 신규 진입 횟수, 동시 보유 수, 장마감 청산 정책을 함께 관리합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "일일 거래 횟수 제한 사용",
                                        isOn: basicDailyTradeLimitEnabledBinding
                                    )

                                    HStack(alignment: .top, spacing: 12) {
                                        strategyBandStepperTile(
                                            label: "최대 거래 횟수",
                                            value: basicDailyTradeLimitCountValue(defaultValue: draft.basic.risk.dailyTradeLimitCount),
                                            range: 1...1_000,
                                            step: 1,
                                            unit: "회",
                                            onChange: { store.updateStrategyBasicDailyTradeLimitCount($0) }
                                        )
                                        .disabled(!basicDailyTradeLimitEnabledValue(defaultValue: draft.basic.risk.dailyTradeLimitEnabled))
                                        .opacity(basicDailyTradeLimitEnabledValue(defaultValue: draft.basic.risk.dailyTradeLimitEnabled) ? 1.0 : 0.42)

                                        strategyBandStepperTile(
                                            label: "동시 보유 종목 수",
                                            value: basicMaxConcurrentPositionsValue(defaultValue: draft.basic.risk.maxConcurrentPositions),
                                            range: 1...50,
                                            step: 1,
                                            unit: "개",
                                            onChange: { store.updateStrategyBasicMaxConcurrentPositions($0) }
                                        )
                                    }

                                    strategyBandToggleControl(
                                        title: "장 마감 5분 전 전체 청산",
                                        isOn: basicForceCloseOnMarketCloseBinding
                                    )
                                }
                            }
                        }
                    )
                }

                riskSettingsPanel(defaultRisk: draft.advanced.risk)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func basicStrategyPanel(
        template: StrategyTemplateSnapshot
    ) -> some View {
        strategyPanel(
            title: "선택한 전략 설정",
            subtitle: "\(template.displayName)의 전략형 진입/청산 파라미터를 조정합니다."
        ) {
            VStack(alignment: .leading, spacing: 22) {
                strategyCategoryBlock(
                    title: "진입 전략",
                    summary: "후보 선정, 감시 범위, 진입 신호를 한 패널에서 정리합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "후보 선정 방식",
                                tooltip: "스캐너 상위 후보를 어떤 기준으로 우선 감시할지 정합니다."
                            ) {
                                strategySegmentedControl(
                                    options: [
                                        AppSegmentedOption(value: "turnover", title: "거래대금 중심"),
                                        AppSegmentedOption(value: "surge", title: "급등률 중심"),
                                    ],
                                    selection: basicSelectionModeBinding,
                                    minSegmentWidth: 138,
                                    height: 38
                                )
                            }
                        },
                        second: {
                            strategyBandSegment(title: "관찰 후보 수") {
                                strategyBandStepperControl(
                                    value: basicTopNValue,
                                    range: 1...30,
                                    step: 1,
                                    unit: "Top-N",
                                    onChange: { store.updateStrategyBasicTopN($0) }
                                )
                            }
                        },
                        third: {
                            strategyBandSegment(
                                title: "진입 신호",
                                tooltip: "실제 진입 판단에 사용할 신호만 활성화합니다. 상위권 유지는 상위 순위를 유지하며 추세가 이어질 때 진입 후보로 사용합니다."
                            ) {
                                strategySignalToggleList(
                                    options: momentumSignalTypeOptions,
                                    selected: basicEnabledSignalTypes,
                                    binding: basicSignalEnabledBinding
                                )
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "청산 전략",
                    summary: "손익, 보유 시간, 장 종료 전 정리 규칙을 한 패널에서 봅니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(title: "익절 / 손절") {
                                HStack(alignment: .top, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "익절",
                                        unit: "%",
                                        text: basicTargetProfitTextBinding
                                    )
                                    strategyBandNumericField(
                                        label: "손절",
                                        unit: "%",
                                        text: basicStopLossTextBinding
                                    )
                                }
                            }
                        },
                        second: {
                            strategyBandSegment(title: "보유 시간 제한") {
                                strategyBandStepperControl(
                                    value: basicMaxHoldingMinutesValue,
                                    range: 1...10_080,
                                    step: 1,
                                    unit: "분",
                                    onChange: { store.updateStrategyBasicMaxHoldingMinutes($0) }
                                )
                            }
                        },
                        third: {
                            strategyBandSegment(title: "공통 실행 가드") {
                                Text("장 마감 강제 청산은 아래 공통 리스크 / 실행 설정에서 별도로 관리합니다.")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func openingPullbackStrategyPanel(
        template: StrategyTemplateSnapshot
    ) -> some View {
        return strategyPanel(
            title: "선택한 전략 설정",
            subtitle: "\(template.displayName)의 개장 초 impulse → pullback → re-entry 규칙을 전용 폼으로 편집합니다."
        ) {
            VStack(alignment: .leading, spacing: 22) {
                strategyCategoryBlock(
                    title: "시간대",
                    summary: "개장 초 관찰 시작, 후보 인정 종료, 진입 허용 종료 시각을 분리합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "관찰 시작 / 후보 시작",
                                tooltip: "관찰은 observe_start_time부터 시작하고, 후보 인정은 candidate_start_time 이후부터 허용합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandTextField(
                                        label: "관찰 시작",
                                        placeholder: "09:00",
                                        unit: "KST",
                                        text: activeStrategyStringBinding("observe_start_time")
                                    )
                                    strategyBandTextField(
                                        label: "후보 시작",
                                        placeholder: "09:02",
                                        unit: "KST",
                                        text: activeStrategyStringBinding("candidate_start_time")
                                    )
                                }
                            }
                        },
                        second: {
                            strategyBandSegment(
                                title: "후보 종료 / 진입 종료",
                                tooltip: "opening impulse 후보를 인정할 마지막 시각과, 실제 재진입 매수를 허용할 마지막 시각을 따로 둡니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandTextField(
                                        label: "후보 종료",
                                        placeholder: "09:20",
                                        unit: "KST",
                                        text: activeStrategyStringBinding("candidate_end_time")
                                    )
                                    strategyBandTextField(
                                        label: "진입 종료",
                                        placeholder: "10:00",
                                        unit: "KST",
                                        text: activeStrategyStringBinding("entry_end_time")
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(title: "운용 메모") {
                                VStack(alignment: .leading, spacing: 8) {
                                    strategyCompactNote(
                                        title: "현재 구현",
                                        detail: "1분봉, 거래대금/급등률 rank, VWAP, 시장제도 필터, 1호가 스프레드/잔량 필터, 부분익절, 시간청산까지 반영됩니다."
                                    )
                                    strategyCompactNote(
                                        title: "시장제도 필터",
                                        detail: "신규상장, 단기과열, 시장경보, 최근 VI 회피 필터를 후보/신호 단계에 함께 적용합니다."
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "후보 선정",
                    summary: "어떤 rank 후보를 opening impulse 감시 대상으로 삼을지 정합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "후보 랭킹 기준",
                                tooltip: "개장 초 강세 후보를 거래대금 중심 또는 급등률 중심 rank에서 고릅니다."
                            ) {
                                strategySegmentedControl(
                                    options: [
                                        AppSegmentedOption(value: "turnover", title: "거래대금 중심"),
                                        AppSegmentedOption(value: "surge", title: "급등률 중심"),
                                    ],
                                    selection: activeStrategyStringBinding("selection_mode", defaultValue: "turnover"),
                                    minSegmentWidth: 138,
                                    height: 38
                                )
                            }
                        },
                        second: {
                            strategyBandSegment(title: "관찰 범위") {
                                strategyBandStepperTile(
                                    label: "감시 후보 수",
                                    value: activeStrategyIntValue("top_n", defaultValue: 8),
                                    range: 1...30,
                                    step: 1,
                                    unit: "Top-N",
                                    onChange: { store.updateActiveStrategyParamInt("top_n", value: $0, range: 1...30) }
                                )
                            }
                        },
                        third: {
                            strategyBandSegment(
                                title: "Opening Impulse",
                                tooltip: "전일 종가 대비 개장 초 상승폭이 이 범위 안에 있어야 후보로 인정합니다."
                            ) {
                                HStack(alignment: .top, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "최소 상승폭",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "open_impulse_min_return_pct",
                                            defaultValue: 0.1,
                                            range: 0.1...20
                                        )
                                    )
                                    strategyBandNumericField(
                                        label: "최대 상승폭",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "open_impulse_max_return_pct",
                                            defaultValue: 0.1,
                                            range: 0.1...20
                                        )
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "눌림 정의",
                    summary: "첫 상승 구간 뒤 어느 정도 조정이 나와야 눌림으로 볼지 정합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "되돌림 범위",
                                tooltip: "opening impulse 폭 대비 몇 % 되돌림까지를 유효한 pullback으로 볼지 정합니다."
                            ) {
                                HStack(alignment: .top, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "최소 되돌림",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "pullback_retrace_min_pct",
                                            defaultValue: 0.1,
                                            range: 0.1...100
                                        )
                                    )
                                    strategyBandNumericField(
                                        label: "최대 되돌림",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "pullback_retrace_max_pct",
                                            defaultValue: 0.1,
                                            range: 0.1...100
                                        )
                                    )
                                }
                            }
                        },
                        second: {
                            strategyBandSegment(title: "눌림 봉 수") {
                                HStack(alignment: .top, spacing: 12) {
                                    strategyBandStepperTile(
                                        label: "최소 봉 수",
                                        value: activeStrategyIntValue("pullback_bars_min", defaultValue: 2),
                                        range: 1...30,
                                        step: 1,
                                        unit: "봉",
                                        onChange: { store.updateActiveStrategyParamInt("pullback_bars_min", value: $0, range: 1...30) }
                                    )
                                    strategyBandStepperTile(
                                        label: "최대 봉 수",
                                        value: activeStrategyIntValue("pullback_bars_max", defaultValue: 6),
                                        range: 1...60,
                                        step: 1,
                                        unit: "봉",
                                        onChange: { store.updateActiveStrategyParamInt("pullback_bars_max", value: $0, range: 1...60) }
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(title: "패턴 원칙") {
                                VStack(alignment: .leading, spacing: 8) {
                                    strategyCompactNote(
                                        title: "현재 구현 기준",
                                        detail: "1차 버전은 1분봉 기준 retrace 범위와 pullback 봉 수를 함께 만족해야 다음 재상승 트리거를 평가합니다."
                                    )
                                    strategyCompactNote(
                                        title: "주의",
                                        detail: "호가 미시구조나 체결강도 기반 눌림 판정은 아직 포함되지 않습니다."
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "재진입 조건",
                    summary: "눌림 뒤 재상승이 실제 매수 신호로 이어지기 위한 거래량과 VWAP 조건입니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "거래량 재증가",
                                tooltip: "re-entry 봉의 거래량이 pullback 평균 대비 이 배수 이상이어야 합니다."
                            ) {
                                strategyBandNumericField(
                                    label: "거래량 배수",
                                    unit: "x",
                                    text: activeStrategyDoubleTextBinding(
                                        "reentry_volume_multiplier",
                                        defaultValue: 0.1,
                                        range: 0.1...20
                                    )
                                )
                            }
                        },
                        second: {
                            strategyBandSegment(
                                title: "VWAP 필터",
                                tooltip: "pullback 중 VWAP 위 유지 또는 재상승 시 VWAP 회복 여부를 진입 조건으로 씁니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "VWAP 필터 사용",
                                        isOn: activeStrategyBoolBinding("use_vwap_filter", defaultValue: true)
                                    )
                                    strategyBandToggleControl(
                                        title: "재진입 시 VWAP 재돌파 요구",
                                        isOn: activeStrategyBoolBinding("require_vwap_reclaim", defaultValue: false)
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(title: "신호 타입") {
                                VStack(alignment: .leading, spacing: 8) {
                                    strategyBadge(text: "ENGINE WIRED", tone: .success, size: .compact)
                                    strategyCompactNote(
                                        title: "실행 신호",
                                        detail: localizedSignalDescription("opening_pullback_reentry")
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "시장제도 / 거래안전 필터",
                    summary: "실전에서 피해야 할 신규상장, 단기과열, 시장경보, 최근 VI 종목을 opening 전략 전용으로 제외합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "신규상장 제외",
                                tooltip: "전용 상장일 마스터 대신 KIS 일봉 이력 개수로 최근 상장 여부를 판단합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "신규상장 제외 사용",
                                        isOn: activeStrategyBoolBinding("exclude_recently_listed_enabled", defaultValue: true)
                                    )
                                    strategyBandStepperTile(
                                        label: "제외 기준",
                                        value: activeStrategyIntValue("exclude_recently_listed_days", defaultValue: 5),
                                        range: 1...60,
                                        step: 1,
                                        unit: "거래일",
                                        onChange: {
                                            store.updateActiveStrategyParamInt(
                                                "exclude_recently_listed_days",
                                                value: $0,
                                                range: 1...60
                                            )
                                        }
                                    )
                                }
                            }
                        },
                        second: {
                            strategyBandSegment(
                                title: "단기과열 / 시장경보",
                                tooltip: "KIS 현재가 payload의 단기과열 플래그와 투자주의/경고/위험 코드를 사용합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "단기과열 종목 제외",
                                        isOn: activeStrategyBoolBinding("exclude_short_term_overheated_enabled", defaultValue: true)
                                    )
                                    strategyBandToggleControl(
                                        title: "시장경보 종목 제외",
                                        isOn: activeStrategyBoolBinding("exclude_market_warning_enabled", defaultValue: true)
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(
                                title: "최근 VI 회피",
                                tooltip: "최근 market.tick 이력에서 VI 관련 플래그가 보인 종목은 지정 시간 동안 진입을 막습니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "최근 VI 종목 제외",
                                        isOn: activeStrategyBoolBinding("exclude_recent_vi_enabled", defaultValue: true)
                                    )
                                    strategyBandStepperTile(
                                        label: "확인 시간",
                                        value: activeStrategyIntValue("recent_vi_lookback_minutes", defaultValue: 10),
                                        range: 1...120,
                                        step: 1,
                                        unit: "분",
                                        onChange: {
                                            store.updateActiveStrategyParamInt(
                                                "recent_vi_lookback_minutes",
                                                value: $0,
                                                range: 1...120
                                            )
                                        }
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "체결 품질 필터",
                    summary: "최우선 호가 스프레드와 1호가 잔량/불균형을 확인해 실제 체결 품질이 나쁜 종목을 제외합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "스프레드",
                                tooltip: "최우선 매도호가와 매수호가의 차이를 mid price 대비 비율로 계산합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "스프레드 필터 사용",
                                        isOn: activeStrategyBoolBinding("use_spread_filter", defaultValue: true)
                                    )
                                    strategyBandNumericField(
                                        label: "최대 스프레드",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "max_spread_pct",
                                            defaultValue: 0.01,
                                            range: 0.01...10
                                        )
                                    )
                                }
                            }
                        },
                        second: {
                            strategyBandSegment(
                                title: "최소 잔량",
                                tooltip: "최우선 매수/매도호가 잔량이 너무 얇으면 실제 진입 주문 슬리피지가 커질 수 있습니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "호가잔량 필터 사용",
                                        isOn: activeStrategyBoolBinding("use_orderbook_depth_filter", defaultValue: true)
                                    )
                                    strategyBandStepperTile(
                                        label: "최소 매수호가 잔량",
                                        value: activeStrategyIntValue("min_best_bid_size", defaultValue: 300),
                                        range: 1...1_000_000,
                                        step: 50,
                                        unit: "주",
                                        onChange: {
                                            store.updateActiveStrategyParamInt(
                                                "min_best_bid_size",
                                                value: $0,
                                                range: 1...1_000_000
                                            )
                                        }
                                    )
                                    strategyBandStepperTile(
                                        label: "최소 매도호가 잔량",
                                        value: activeStrategyIntValue("min_best_ask_size", defaultValue: 300),
                                        range: 1...1_000_000,
                                        step: 50,
                                        unit: "주",
                                        onChange: {
                                            store.updateActiveStrategyParamInt(
                                                "min_best_ask_size",
                                                value: $0,
                                                range: 1...1_000_000
                                            )
                                        }
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(
                                title: "호가 불균형",
                                tooltip: "현재 엔진은 호가/예상체결 API의 최우선 1호가 잔량만 사용합니다. 2~10호가 깊이는 후속 TODO입니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "최대 비율",
                                        unit: "x",
                                        text: activeStrategyDoubleTextBinding(
                                            "max_orderbook_imbalance_ratio",
                                            defaultValue: 1.0,
                                            range: 1...100
                                        )
                                    )
                                    strategyCompactNote(
                                        title: "현재 구현 범위",
                                        detail: "KIS `주식현재가 호가/예상체결` 응답의 1호가(`askp1/bidp1`, `askp_rsqn1/bidp_rsqn1`) 기준으로만 차단합니다."
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "포지션 사이징",
                    summary: "이 전략은 진입 금액 비율이 아니라, 한 거래에서 허용할 손실과 손절 거리로 수량을 계산할 수 있습니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(
                                title: "리스크 기준",
                                tooltip: "계좌의 몇 %를 살지가 아니라, 한 거래에서 계좌의 몇 %까지 손실을 허용할지를 먼저 정합니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandToggleControl(
                                        title: "리스크 사이징 사용",
                                        isOn: activeStrategyBoolBinding("use_risk_per_trade_sizing", defaultValue: true)
                                    )
                                    strategyBandNumericField(
                                        label: "거래당 최대 손실",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "risk_per_trade_pct",
                                            defaultValue: 0.01,
                                            range: 0.01...10
                                        )
                                    )
                                }
                            }
                        },
                        second: {
                            strategyBandSegment(
                                title: "안전 상한",
                                tooltip: "손절폭이 매우 좁을 때 risk-per-trade 결과가 과도하게 커지지 않도록 포지션 금액 상한을 둡니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "최대 포지션 상한",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "max_position_size_pct_cap",
                                            defaultValue: 0.1,
                                            range: 0.1...100
                                        )
                                    )
                                    strategyCompactNote(
                                        title: "공통 포지션 비율과의 관계",
                                        detail: "다른 전략은 계속 공통 `position_size_pct`를 사용하고, Opening 전략은 리스크 사이징을 끄면 그 경로로 fallback합니다."
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(
                                title: "보수 버퍼",
                                tooltip: "체결가가 예상보다 조금 불리하게 나올 수 있다는 가정으로 주당 리스크를 더 크게 잡습니다."
                            ) {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "슬리피지 버퍼",
                                        unit: "%",
                                        text: activeStrategyDoubleTextBinding(
                                            "sizing_slippage_buffer_pct",
                                            defaultValue: 0,
                                            range: 0.0...5.0
                                        )
                                    )
                                    strategyCompactNote(
                                        title: "현재 계산식",
                                        detail: "허용 손실 금액 / (주당 손절 리스크 + 버퍼)로 수량을 계산하고, 최종 수량은 1주 단위로 내림 처리합니다."
                                    )
                                }
                            }
                        }
                    )
                }

                strategyCategoryBlock(
                    title: "청산",
                    summary: "초기 손절, 1차 부분익절, soft/hard time stop으로 1차 버전 청산 규칙을 관리합니다."
                ) {
                    strategyBandPanel(
                        first: {
                            strategyBandSegment(title: "초기 손절") {
                                strategyBandNumericField(
                                    label: "초기 손절",
                                    unit: "%",
                                    text: activeStrategyDoubleTextBinding(
                                        "initial_stop_pct",
                                        defaultValue: 0.1,
                                        range: 0.1...20
                                    )
                                )
                            }
                        },
                        second: {
                            strategyBandSegment(title: "1차 익절") {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "R 배수",
                                        unit: "R",
                                        text: activeStrategyDoubleTextBinding(
                                            "first_take_profit_r_multiple",
                                            defaultValue: 0.1,
                                            range: 0.1...10
                                        )
                                    )
                                    strategyBandNumericField(
                                        label: "분할 비율",
                                        unit: "ratio",
                                        text: activeStrategyDoubleTextBinding(
                                            "first_take_profit_partial_ratio",
                                            defaultValue: 0.01,
                                            range: 0.01...0.99
                                        )
                                    )
                                }
                            }
                        },
                        third: {
                            strategyBandSegment(title: "시간청산") {
                                VStack(alignment: .leading, spacing: 12) {
                                    strategyBandNumericField(
                                        label: "Soft Time Stop",
                                        unit: "분",
                                        text: activeStrategyOptionalIntTextBinding(
                                            "time_stop_soft_minutes",
                                            range: 1...240
                                        )
                                    )
                                    strategyBandStepperTile(
                                        label: "Hard Time Stop",
                                        value: activeStrategyIntValue("time_stop_hard_minutes", defaultValue: 45),
                                        range: 1...480,
                                        step: 1,
                                        unit: "분",
                                        onChange: { store.updateActiveStrategyParamInt("time_stop_hard_minutes", value: $0, range: 1...480) }
                                    )
                                }
                            }
                        }
                    )
                }

                strategyPanel(
                    title: "구현 메모",
                    subtitle: "현재는 stop 기반 risk-per-trade sizing까지 연결되어 있고, 더 정교한 체결 모델은 아직 포함하지 않습니다.",
                    prominence: .secondary
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        strategyCompactNote(
                            title: "현재 적용",
                            detail: "수량은 stop price 우선, 없으면 pullback low, 마지막으로 signal payload의 initial_stop_pct 기반으로 계산합니다."
                        )
                        strategyCompactNote(
                            title: "현재 제약",
                            detail: "고급 슬리피지 모델이나 예상 체결량 모델은 아직 없고, 보수 버퍼와 포지션 상한으로만 과도한 사이징을 막습니다."
                        )
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 18)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
        }
    }

    private func advancedSettingsPanel() -> some View {
        strategyPanel(
            title: "전략별 고급 설정",
            subtitle: "선택한 전략 템플릿에만 적용되는 세부 스캐너/신호 튜닝입니다.",
            prominence: .secondary
        ) {
            DisclosureGroup(isExpanded: $showAdvancedSettings) {
                VStack(alignment: .leading, spacing: 14) {
                    scannerSettingsPanel()
                    signalSettingsPanel()
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
                        Text("스캐너 보조 필터, 점수 가중치, 신호 임계값을 조정합니다.")
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

    private func scannerSettingsPanel() -> some View {
        advancedSectionCard(
            title: "Scanner",
            summary: "Basic Strategy의 방향 위에 세부 필터와 가중치만 더합니다.",
            trailing: {
                advancedSectionMeta(
                    title: "Basic 기준",
                    value: "\(localizedScannerMode(basicSelectionModeValue)) · Top \(basicTopNValue)"
                )
            }
        ) {
            advancedCardRow(minHeight: 232) {
                advancedTuningCard(
                    title: "최소 거래 필터",
                    tooltip: "Basic Strategy의 스캔 방향과 별개로, 스캐너 후보군을 더 보수적으로 좁히는 조건입니다.",
                    minHeight: 232
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        strategyBandNumericField(
                            label: "최소 거래대금",
                            unit: "원",
                            text: scannerMinTurnoverTextBinding
                        )
                        strategyBandNumericField(
                            label: "최소 등락률",
                            unit: "%",
                            text: scannerMinChangePctTextBinding
                        )
                    }
                }
            } second: {
                advancedTuningCard(
                    title: "거래대금 순위 가중치",
                    tooltip: "순위, 거래대금, 등락률이 후보 점수에 반영되는 비율을 100% 안에서 조정합니다.",
                    minHeight: 232
                ) {
                    advancedWeightEditor(
                        mode: "turnover",
                        weights: currentScannerWeights(
                            mode: "turnover",
                            fallback: ScannerScoreWeightsSnapshot(rank: 40, turnover: 45, changePct: 15)
                        )
                    )
                }
            } third: {
                advancedTuningCard(
                    title: "급등률 순위 가중치",
                    tooltip: "급등률 모드에서 순위, 거래대금, 등락률 비중을 따로 조정합니다.",
                    minHeight: 232
                ) {
                    advancedWeightEditor(
                        mode: "surge",
                        weights: currentScannerWeights(
                            mode: "surge",
                            fallback: ScannerScoreWeightsSnapshot(rank: 40, turnover: 15, changePct: 45)
                        )
                    )
                }
            }
        }
    }

    private func signalSettingsPanel() -> some View {
        advancedSectionCard(
            title: "Signal",
            summary: "Basic 신호를 보완하는 세부 판단 임계값만 조정합니다."
        ) {
            advancedCardRow(minHeight: 246) {
                advancedTuningCard(
                    title: "신호 평가 범위",
                    tooltip: "Basic Strategy의 관찰 후보 안에서 실제 신호로 평가할 범위를 더 좁히거나 넓힙니다.",
                    minHeight: 246
                ) {
                    strategyBandStepperTile(
                        label: "평가 대상 범위",
                        value: signalTopNValue,
                        range: 1...30,
                        step: 1,
                        unit: "Top-N",
                        onChange: { store.updateStrategySignalTopN($0) }
                    )
                }
            } second: {
                advancedTuningCard(
                    title: "급상승 / 유지 조건",
                    tooltip: "순위가 얼마나 빠르게 변해야 급상승으로 볼지, 상위권 유지 허용 편차를 어디까지 둘지 정합니다.",
                    minHeight: 246
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        strategyBandStepperTile(
                            label: "급상승 임계값",
                            value: signalRankJumpThresholdValue,
                            range: 1...50,
                            step: 1,
                            unit: "단계",
                            onChange: { store.updateStrategyRankJumpThreshold($0) }
                        )
                        strategyBandStepperTile(
                            label: "급상승 윈도우",
                            value: signalRankJumpWindowSecondsValue,
                            range: 10...86_400,
                            step: 10,
                            unit: "초",
                            onChange: { store.updateStrategyRankJumpWindowSeconds($0) }
                        )
                        strategyBandStepperTile(
                            label: "상위권 유지 편차",
                            value: signalRankHoldToleranceValue,
                            range: 0...20,
                            step: 1,
                            unit: "단계",
                            onChange: { store.updateStrategyRankHoldTolerance($0) }
                        )
                    }
                }
            } third: {
                advancedTuningCard(
                    title: "활성 신호 유형",
                    tooltip: "Basic에서 선택한 진입 신호 중 세부 평가에 계속 반영할 유형만 남깁니다.",
                    minHeight: 246
                ) {
                    strategySignalToggleList(
                        options: momentumSignalTypeOptions,
                        selected: currentSignalEnabledTypes,
                        binding: signalEnabledBinding
                    )
                }
            }
        }
    }

    private func riskSettingsPanel(defaultRisk: RiskSettingsSnapshot) -> some View {
        advancedSectionCard(
            title: "Shared Risk Runtime",
            summary: "전략 템플릿과 분리된 공통 리스크 게이트와 시간창을 조정합니다."
        ) {
            advancedCardRow(minHeight: 258) {
                advancedTuningCard(
                    title: "허용 신호",
                    tooltip: "리스크 게이트를 통과시킬 신호 유형만 남깁니다.",
                    minHeight: 258
                ) {
                    strategySignalToggleList(
                        options: strategySignalTypeOptions,
                        selected: currentRiskAllowedSignalTypes,
                        binding: riskAllowedBinding
                    )
                }
            } second: {
                advancedTuningCard(
                    title: "동시 후보 제한",
                    tooltip: "한 번에 너무 많은 승인 후보가 열리는 상황을 막는 보수적 제한입니다.",
                    minHeight: 258
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        strategyBandStepperTile(
                            label: "최대 동시 후보 수",
                            value: riskMaxConcurrentCandidatesValue(defaultValue: defaultRisk.maxConcurrentCandidates),
                            range: 1...50,
                            step: 1,
                            unit: "개",
                            onChange: { store.updateStrategyMaxConcurrentCandidates($0) }
                        )
                        strategyBandToggleControl(
                            title: "보유 시 신규 진입 차단",
                            isOn: riskBlockWhenPositionExistsBinding(defaultValue: defaultRisk.blockWhenPositionExists)
                        )
                    }
                }
            } third: {
                advancedTuningCard(
                    title: "재진입 / 시간 제한",
                    tooltip: "같은 종목 재진입과 동시성 계산, 신호 유효 시간을 보수적으로 조정합니다.",
                    minHeight: 258
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        strategyBandStepperTile(
                            label: "재진입 대기 시간",
                            value: riskCooldownMinutesValue(defaultValue: defaultRisk.cooldownMinutes),
                            range: 1...1_440,
                            step: 1,
                            unit: "분",
                            onChange: { store.updateStrategyCooldownMinutes($0) }
                        )
                        strategyBandStepperTile(
                            label: "신호 유효 시간",
                            value: riskSignalWindowMinutesValue(defaultValue: defaultRisk.signalWindowMinutes),
                            range: 1...1_440,
                            step: 1,
                            unit: "분",
                            onChange: { store.updateStrategySignalWindowMinutes($0) }
                        )
                        strategyBandStepperTile(
                            label: "동시성 계산 시간창",
                            value: riskConcurrencyWindowMinutesValue(defaultValue: defaultRisk.concurrencyWindowMinutes),
                            range: 1...1_440,
                            step: 1,
                            unit: "분",
                            onChange: { store.updateStrategyConcurrencyWindowMinutes($0) }
                        )
                    }
                }
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

    private func advancedSectionCard<Trailing: View, Content: View>(
        title: String,
        summary: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                    Text(summary)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                Spacer(minLength: 10)
                trailing()
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

    private func advancedSectionCard<Content: View>(
        title: String,
        summary: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        advancedSectionCard(title: title, summary: summary, trailing: { EmptyView() }, content: content)
    }

    private func advancedSectionMeta(title: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
            Text(value)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
    }

    private func advancedCardRow<First: View, Second: View, Third: View>(
        minHeight: CGFloat,
        @ViewBuilder _ first: () -> First,
        @ViewBuilder second: () -> Second,
        @ViewBuilder third: () -> Third
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                first()
                second()
                third()
            }
            VStack(alignment: .leading, spacing: 14) {
                first()
                second()
                third()
            }
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
    }

    private func advancedTuningCard<Content: View>(
        title: String,
        tooltip: String? = nil,
        minHeight: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 6) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let tooltip {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                        .help(tooltip)
                }
            }
            Spacer(minLength: 4)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .topLeading)
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface1.opacity(0.58),
                            DesignTokens.Colors.surface1.opacity(0.28),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.62), lineWidth: 0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg - 1, style: .continuous)
                .stroke(Color.white.opacity(0.022), lineWidth: 0.7)
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
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 8) {
                TextField("미설정", text: text)
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

    private func strategyBandNumericField(
        label: String,
        unit: String,
        text: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        strategyBandNumericField(
            label: label,
            unit: unit,
            text: Binding(
                get: { text },
                set: onChange
            )
        )
    }

    private func strategyBandTextField(
        label: String,
        placeholder: String,
        unit: String? = nil,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            HStack(spacing: 8) {
                TextField(placeholder, text: text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13.5, weight: .medium, design: .monospaced))

                if let unit {
                    Text(unit)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                }
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

    private func strategyBandTextField(
        label: String,
        placeholder: String,
        unit: String? = nil,
        text: String,
        onChange: @escaping (String) -> Void
    ) -> some View {
        strategyBandTextField(
            label: label,
            placeholder: placeholder,
            unit: unit,
            text: Binding(
                get: { text },
                set: onChange
            )
        )
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
        options: [String] = [],
        selected: [String],
        binding: @escaping (String) -> Binding<Bool>
    ) -> some View {
        let resolvedOptions = options.isEmpty ? strategySignalTypeOptions : options
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(resolvedOptions, id: \.self) { type in
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
        ["new_entry", "rank_jump", "rank_maintained", "opening_pullback_reentry"]
    }

    private var momentumSignalTypeOptions: [String] {
        ["new_entry", "rank_jump", "rank_maintained"]
    }

    private var currentActiveStrategyParams: [String: JSONValue] {
        guard let draft = store.strategyDraft else { return [:] }
        let strategyId = draft.activeStrategyId.isEmpty ? "turnover_surge_momentum" : draft.activeStrategyId
        return draft.strategyParams[strategyId] ?? [:]
    }

    private var currentStrategyDraftSnapshot: StrategySettingsSnapshot? {
        store.strategyDraft ?? store.strategySettings
    }

    private var currentBasicSettings: BasicStrategySettingsSnapshot? {
        currentStrategyDraftSnapshot?.basic
    }

    private var currentScannerSettings: ScannerSettingsSnapshot? {
        currentStrategyDraftSnapshot?.scanner
    }

    private var currentSignalSettings: SignalSettingsSnapshot? {
        currentStrategyDraftSnapshot?.signal
    }

    private var currentRiskSettings: RiskSettingsSnapshot? {
        currentStrategyDraftSnapshot?.risk
    }

    private var basicSelectionModeValue: String {
        currentBasicSettings?.entry.selectionMode ?? "turnover"
    }

    private var basicTopNValue: Int {
        currentBasicSettings?.entry.topN ?? 10
    }

    private var basicEnabledSignalTypes: [String] {
        currentBasicSettings?.entry.enabledSignalTypes ?? []
    }

    private var basicMaxHoldingMinutesValue: Int {
        currentBasicSettings?.exit.maxHoldingMinutes ?? 60
    }

    private var currentSignalEnabledTypes: [String] {
        currentSignalSettings?.enabledSignalTypes ?? []
    }

    private var currentRiskAllowedSignalTypes: [String] {
        currentRiskSettings?.allowedSignalTypes ?? []
    }

    private var signalTopNValue: Int {
        currentSignalSettings?.topN ?? 10
    }

    private var signalRankJumpThresholdValue: Int {
        currentSignalSettings?.rankJumpThreshold ?? 3
    }

    private var signalRankJumpWindowSecondsValue: Int {
        currentSignalSettings?.rankJumpWindowSeconds ?? 600
    }

    private var signalRankHoldToleranceValue: Int {
        currentSignalSettings?.rankHoldTolerance ?? 1
    }

    private func activeStrategyStringValue(_ key: String, defaultValue: String = "") -> String {
        currentActiveStrategyParams.stringValue(for: key) ?? defaultValue
    }

    private func activeStrategyIntValue(_ key: String, defaultValue: Int) -> Int {
        currentActiveStrategyParams.intValue(for: key) ?? defaultValue
    }

    private func activeStrategyStringBinding(_ key: String, defaultValue: String = "") -> Binding<String> {
        Binding(
            get: { activeStrategyStringValue(key, defaultValue: defaultValue) },
            set: { store.updateActiveStrategyParamString(key, value: $0) }
        )
    }

    private func activeStrategyBoolBinding(_ key: String, defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: { currentActiveStrategyParams.boolValue(for: key) ?? defaultValue },
            set: { store.updateActiveStrategyParamBool(key, value: $0) }
        )
    }

    private func activeStrategyDoubleTextBinding(
        _ key: String,
        defaultValue: Double,
        range: ClosedRange<Double>
    ) -> Binding<String> {
        Binding(
            get: {
                guard let value = currentActiveStrategyParams.doubleValue(for: key) else { return "" }
                return DisplayFormatters.number(value)
            },
            set: {
                store.updateActiveStrategyParamDouble(
                    key,
                    value: parseOptionalDouble($0) ?? defaultValue,
                    range: range
                )
            }
        )
    }

    private func activeStrategyOptionalIntTextBinding(
        _ key: String,
        range: ClosedRange<Int>
    ) -> Binding<String> {
        Binding(
            get: {
                guard let value = currentActiveStrategyParams.intValue(for: key) else { return "" }
                return String(value)
            },
            set: {
                let value = parseOptionalDouble($0).map(Int.init)
                store.updateActiveStrategyParamOptionalInt(key, value: value, range: range)
            }
        )
    }

    private var basicSelectionModeBinding: Binding<String> {
        Binding(
            get: { basicSelectionModeValue },
            set: { store.updateStrategyBasicSelectionMode($0) }
        )
    }

    private var basicDailyTradeLimitEnabledBinding: Binding<Bool> {
        Binding(
            get: { currentBasicSettings?.risk.dailyTradeLimitEnabled ?? false },
            set: { store.updateStrategyBasicDailyTradeLimitEnabled($0) }
        )
    }

    private var basicForceCloseOnMarketCloseBinding: Binding<Bool> {
        Binding(
            get: { currentBasicSettings?.exit.forceCloseOnMarketClose ?? false },
            set: { store.updateStrategyBasicForceCloseOnMarketClose($0) }
        )
    }

    private func basicDailyTradeLimitEnabledValue(defaultValue: Bool) -> Bool {
        currentBasicSettings?.risk.dailyTradeLimitEnabled ?? defaultValue
    }

    private func basicDailyTradeLimitCountValue(defaultValue: Int) -> Int {
        currentBasicSettings?.risk.dailyTradeLimitCount ?? defaultValue
    }

    private func basicMaxConcurrentPositionsValue(defaultValue: Int) -> Int {
        currentBasicSettings?.risk.maxConcurrentPositions ?? defaultValue
    }

    private func riskMaxConcurrentCandidatesValue(defaultValue: Int) -> Int {
        currentRiskSettings?.maxConcurrentCandidates ?? defaultValue
    }

    private func riskCooldownMinutesValue(defaultValue: Int) -> Int {
        currentRiskSettings?.cooldownMinutes ?? defaultValue
    }

    private func riskSignalWindowMinutesValue(defaultValue: Int) -> Int {
        currentRiskSettings?.signalWindowMinutes ?? defaultValue
    }

    private func riskConcurrencyWindowMinutesValue(defaultValue: Int) -> Int {
        currentRiskSettings?.concurrencyWindowMinutes ?? defaultValue
    }

    private func riskBlockWhenPositionExistsBinding(defaultValue: Bool) -> Binding<Bool> {
        Binding(
            get: { currentRiskSettings?.blockWhenPositionExists ?? defaultValue },
            set: { store.updateStrategyBlockWhenPositionExists($0) }
        )
    }

    private var scannerMinTurnoverTextBinding: Binding<String> {
        Binding(
            get: {
                guard let value = currentScannerSettings?.minTurnover else { return "" }
                return DisplayFormatters.number(value)
            },
            set: { store.updateStrategyScannerMinTurnover(parseOptionalDouble($0)) }
        )
    }

    private var scannerMinChangePctTextBinding: Binding<String> {
        Binding(
            get: {
                guard let value = currentScannerSettings?.minChangePct else { return "" }
                return DisplayFormatters.number(value)
            },
            set: { store.updateStrategyScannerMinChangePct(parseOptionalDouble($0)) }
        )
    }

    private var basicTargetProfitTextBinding: Binding<String> {
        Binding(
            get: {
                guard let value = currentBasicSettings?.exit.targetProfitPct else { return "" }
                return DisplayFormatters.number(value)
            },
            set: { store.updateStrategyBasicTargetProfitPct(parseOptionalDouble($0) ?? 0) }
        )
    }

    private var basicStopLossTextBinding: Binding<String> {
        Binding(
            get: {
                guard let value = currentBasicSettings?.exit.stopLossPct else { return "" }
                return DisplayFormatters.number(value)
            },
            set: { store.updateStrategyBasicStopLossPct(parseOptionalDouble($0) ?? 0.1) }
        )
    }

    private var basicMaxLossLimitTextBinding: Binding<String> {
        Binding(
            get: {
                guard let value = currentBasicSettings?.risk.maxLossLimitPct else { return "" }
                return DisplayFormatters.number(value)
            },
            set: { store.updateStrategyBasicMaxLossLimitPct(parseOptionalDouble($0) ?? 0) }
        )
    }

    private var basicPositionSizePctTextBinding: Binding<String> {
        Binding(
            get: {
                guard let value = currentBasicSettings?.risk.positionSizePct else { return "" }
                return DisplayFormatters.number(value)
            },
            set: { store.updateStrategyBasicPositionSizePct(parseOptionalDouble($0) ?? 0.1) }
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

    private func currentScannerWeights(mode: String, fallback: ScannerScoreWeightsSnapshot) -> ScannerScoreWeightsSnapshot {
        currentScannerSettings?.scoreDefinition.weights[mode] ?? fallback
    }

    private func advancedWeightEditor(
        mode: String,
        weights: ScannerScoreWeightsSnapshot
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("총합 100% 안에서 비율이 자동 유지됩니다.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            AdvancedWeightRangeControl(
                rank: scannerWeightBinding(mode: mode, key: "rank", fallback: weights.rank),
                turnover: scannerWeightBinding(mode: mode, key: "turnover", fallback: weights.turnover),
                changePct: scannerWeightBinding(mode: mode, key: "change_pct", fallback: weights.changePct)
            )
        }
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
        case "opening_pullback_reentry":
            return "Opening Pullback Re-entry"
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
        case "opening_pullback_reentry":
            return "개장 초 impulse 이후 눌림을 소화하고 단기 고점/VWAP 재확인 뒤 재상승하는 종목"
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

    private func resolvedSelectedStrategyTemplateID(for draft: StrategySettingsSnapshot) -> String {
        if let selectedStrategyTemplateID,
           draft.strategyTemplates.contains(where: { $0.strategyId == selectedStrategyTemplateID }) {
            return selectedStrategyTemplateID
        }
        return draft.activeStrategyId
    }

    private func selectedStrategyTemplate(from draft: StrategySettingsSnapshot) -> StrategyTemplateSnapshot? {
        let selectedStrategyId = resolvedSelectedStrategyTemplateID(for: draft)
        return draft.template(id: selectedStrategyId) ?? draft.activeTemplate
    }

    private func templateStatusText(_ template: StrategyTemplateSnapshot) -> String {
        switch template.status.lowercased() {
        case "active":
            return "ACTIVE"
        case "available":
            return "AVAILABLE"
        case "preview_only":
            return "PREVIEW"
        case "not_wired":
            return "NOT WIRED"
        default:
            return template.status.uppercased()
        }
    }

    private func templateStatusTone(_ template: StrategyTemplateSnapshot) -> StatusTone {
        switch template.status.lowercased() {
        case "active":
            return .success
        case "available":
            return .neutral
        case "preview_only", "not_wired":
            return .warning
        default:
            return .neutral
        }
    }

    private func templateCardFill(_ template: StrategyTemplateSnapshot, isSelected: Bool) -> Color {
        if isSelected {
            return template.selectable
                ? DesignTokens.Colors.accentMuted.opacity(0.92)
                : DesignTokens.Colors.warningBackground.opacity(0.68)
        }
        return DesignTokens.Colors.bgPanel.opacity(0.82)
    }

    private func templateCardStroke(_ template: StrategyTemplateSnapshot, isSelected: Bool) -> Color {
        if isSelected {
            return template.selectable
                ? DesignTokens.Colors.accent.opacity(0.86)
                : DesignTokens.Colors.warning.opacity(0.82)
        }
        return DesignTokens.Colors.borderSubtle.opacity(0.88)
    }

    private func selectionSummaryTitle(
        for template: StrategyTemplateSnapshot,
        draft: StrategySettingsSnapshot
    ) -> String {
        if template.strategyId == draft.activeStrategyId {
            return "현재 운용 중인 전략"
        }
        if template.selectable {
            return "선택 가능한 전략"
        }
        return "프리뷰 전용 전략"
    }

    private func selectionSummaryDetail(
        for template: StrategyTemplateSnapshot,
        draft: StrategySettingsSnapshot
    ) -> String {
        if template.strategyId == draft.activeStrategyId {
            return "지금 엔진에 연결된 활성 전략입니다. 아래 패널에서 전략별 파라미터를 조정할 수 있습니다."
        }
        if template.selectable {
            return "활성 전략으로 전환하면 전략별 파라미터는 해당 템플릿 값으로 바뀌고, 공통 리스크/실행 설정은 유지됩니다."
        }
        return "현재 단계에서는 메타와 파라미터 프리뷰만 제공하며, 엔진 활성화는 허용되지 않습니다."
    }

    private func strategyTemplateValueText(
        field: StrategyConfigurableFieldSnapshot,
        params: [String: JSONValue]
    ) -> String {
        guard let value = params[field.fieldId] else { return "미정" }

        switch field.inputType {
        case "multiselect":
            return value.arrayStringValues?.joined(separator: ", ") ?? "미정"
        case "weight_set":
            guard let object = value.objectValue else { return "미정" }
            let rank = object["rank"]?.doubleValue ?? 0
            let turnover = object["turnover"]?.doubleValue ?? 0
            let changePct = object["change_pct"]?.doubleValue ?? 0
            return "순위 \(Int(rank)) · 거래대금 \(Int(turnover)) · 등락률 \(Int(changePct))"
        case "bool":
            if let boolValue = value.boolValue {
                return boolValue ? "ON" : "OFF"
            }
            return "미정"
        default:
            if let stringValue = value.stringValue, !stringValue.isEmpty {
                return stringValue
            }
            if let intValue = value.intValue {
                return field.unit == nil ? "\(intValue)" : "\(intValue) \(field.unit!)"
            }
            if let doubleValue = value.doubleValue {
                if let unit = field.unit {
                    if unit == "%" || unit == "x" {
                        return "\(DisplayFormatters.number(doubleValue))\(unit)"
                    }
                    return "\(DisplayFormatters.number(doubleValue)) \(unit)"
                }
                return DisplayFormatters.number(doubleValue)
            }
            return "미정"
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

        let statuses = ["strategy", "execution", "risk"].compactMap { store.strategyGroupApplyStatus($0)?.appliedStatus.lowercased() }
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

        let statuses = ["strategy", "execution", "risk"].compactMap { store.strategyGroupApplyStatus($0)?.appliedStatus.lowercased() }
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
            trailing: { StatusBadge(text: store.connectionStatusSummary.compactText, tone: store.connectionStatusSummary.tone) }
        ) {
            settingsRow(icon: "key.horizontal", title: "App Key", value: "••••••••••••")
            settingsRow(icon: "lock.shield", title: "App Secret", value: "••••••••••••")
            settingsRow(
                icon: store.connectionStatusSummary.iconName,
                title: "연결 상태",
                value: store.connectionStatusSummary.message,
                tone: store.connectionStatusSummary.tone,
                multiline: true
            )
            settingsRow(
                icon: "bolt.horizontal.circle",
                title: "실시간 연결",
                value: webSocketConnectionText,
                tone: webSocketConnectionTone
            )
            settingsRow(
                icon: "person.text.rectangle",
                title: "계좌번호(마스킹)",
                value: accountNumberText,
                tone: accountStatusTone,
                mono: true
            )
            Divider().opacity(0.25)
            settingsRow(title: "현재 연결 서버", value: store.resolvedBackendBaseURLText, mono: true, multiline: true)
            settingsRow(title: "WebSocket URL", value: store.resolvedWebSocketURLText, mono: true, multiline: true)
            serverAddressEditorRow
            Divider().opacity(0.25)
            settingsRow(title: "앱 상태", value: store.runtime?.appStatus ?? "-")
            settingsRow(title: "Readiness", value: store.runtime?.readinessStatus ?? "-", tone: readinessTone)
            settingsRow(title: "Startup 상태", value: startupStatusText, tone: startupStatusTone, multiline: true)
            settingsRow(title: "주문/계좌 모드", value: modeContextText)
            settingsRow(title: "실행 모드", value: store.runtime?.executionMode ?? store.runtime?.orderMode ?? "-")
            if let status = store.apiConnectionPanelStatus {
                settingsStatusCaption(status)
            } else if let detail = store.connectionStatusSummary.detail {
                settingsInfoCaption(detail, tone: store.connectionStatusSummary.tone)
            }
        }
    }

    private var notificationPanel: some View {
        settingsPanel(title: "알림 설정") {
            interactiveToggleRow(
                icon: "bell.badge",
                title: "거래 체결 알림",
                isOn: notificationBinding(.tradeFillNotificationsEnabled),
                isSaving: store.isSavingAppSetting(.tradeFillNotificationsEnabled),
                disabled: store.appSettings == nil
            )
            interactiveToggleRow(
                icon: "waveform.path.ecg",
                title: "매매 신호 알림",
                isOn: notificationBinding(.tradeSignalNotificationsEnabled),
                isSaving: store.isSavingAppSetting(.tradeSignalNotificationsEnabled),
                disabled: store.appSettings == nil
            )
            interactiveToggleRow(
                icon: "exclamationmark.bubble",
                title: "시스템 오류 알림",
                isOn: notificationBinding(.systemErrorNotificationsEnabled),
                isSaving: store.isSavingAppSetting(.systemErrorNotificationsEnabled),
                disabled: store.appSettings == nil
            )
            Divider().opacity(0.25)
            settingsRow(
                icon: "app.badge",
                title: "알림 권한",
                value: notificationPermissionText,
                tone: notificationPermissionTone
            )
            if let status = store.notificationPanelStatus {
                settingsStatusCaption(status)
            } else if let error = store.appSettingsErrorMessage, store.appSettings == nil {
                settingsStatusCaption(.error(error))
            }
        }
    }

    private var dataManagementPanel: some View {
        settingsPanel(title: "데이터 관리") {
            interactiveToggleRow(
                icon: "externaldrive",
                title: "자동 백업",
                isOn: autoBackupBinding,
                isSaving: store.isSavingAppSetting(.autoBackupEnabled),
                disabled: store.appSettings == nil
            )
            stepperSettingsRow(
                icon: "calendar.badge.clock",
                title: "로그 보관 기간",
                value: logRetentionDaysBinding,
                range: 1...365,
                suffix: "일",
                isSaving: store.isSavingAppSetting(.logRetentionDays),
                disabled: store.appSettings == nil
            )
            settingsRow(
                icon: "tray.full",
                title: "백업 보관 개수",
                value: backupRetentionCountText
            )
            settingsRow(icon: "internaldrive", title: "사용 중인 저장공간", value: storageUsageText)
            settingsRow(
                icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                title: "최근 로그 정리",
                value: cleanupStatusText,
                tone: cleanupStatusTone,
                multiline: true
            )
            settingsRow(
                icon: "archivebox",
                title: "최근 자동 백업",
                value: backupStatusText,
                tone: backupStatusTone,
                multiline: true
            )
            if let status = store.dataManagementPanelStatus {
                settingsStatusCaption(status)
            } else if let error = store.appSettingsErrorMessage, store.appSettings == nil {
                settingsStatusCaption(.error(error))
            }
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

    private func interactiveToggleRow(
        icon: String,
        title: String,
        isOn: Binding<Bool>,
        isSaving: Bool,
        disabled: Bool
    ) -> some View {
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
            if isSaving {
                ProgressView()
                    .controlSize(.small)
            }
            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .disabled(disabled || isSaving)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func stepperSettingsRow(
        icon: String,
        title: String,
        value: Binding<Int>,
        range: ClosedRange<Int>,
        suffix: String,
        isSaving: Bool,
        disabled: Bool
    ) -> some View {
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
            if isSaving {
                ProgressView()
                    .controlSize(.small)
            }
            Text("\(value.wrappedValue)\(suffix)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .frame(minWidth: 48, alignment: .trailing)
            Stepper("", value: value, in: range)
                .labelsHidden()
                .disabled(disabled || isSaving)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private func settingsStatusCaption(_ status: AppSettingsStatusMessage) -> some View {
        Text(status.text)
            .font(.caption2)
            .foregroundStyle(settingsStatusColor(status))
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private func settingsInfoCaption(_ text: String, tone: StatusTone = .neutral) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(settingsValueColor(for: tone))
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
            .textSelection(.enabled)
    }

    private var readOnlyCaption: some View {
        Text("읽기 전용 표시입니다. 설정 저장/제어는 아직 연결되지 않았습니다.")
            .font(.caption2)
            .foregroundStyle(DesignTokens.Colors.textQuaternary)
            .padding(.horizontal, 14)
            .padding(.top, 4)
            .padding(.bottom, 8)
    }

    private var webSocketConnectionTone: StatusTone {
        switch store.connectionState {
        case .connected:
            return .success
        case .connecting, .reconnecting:
            return .warning
        case .failed:
            return .danger
        case .disconnected:
            return .neutral
        }
    }

    private var webSocketConnectionText: String {
        switch store.connectionState {
        case .connected:
            return "연결됨"
        case .connecting:
            return "초기 연결 중"
        case .reconnecting:
            return "재연결 시도 중"
        case .failed:
            return "연결 실패"
        case .disconnected:
            return "미연결"
        }
    }

    private var readinessTone: StatusTone {
        .fromStatus(store.runtime?.readinessStatus)
    }

    private var startupStatusText: String {
        if let startupError = store.runtime?.startupError, !startupError.isEmpty {
            return startupError
        }
        return store.runtime?.startupStatus ?? "-"
    }

    private var startupStatusTone: StatusTone {
        if store.runtime?.startupError?.isEmpty == false {
            return .danger
        }
        return .fromStatus(store.runtime?.startupStatus)
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
        store.appSettings?.dataManagement.storageUsageLabel ?? "-"
    }

    private var backupRetentionCountText: String {
        guard let count = store.appSettings?.dataManagement.backupRetentionCount else { return "-" }
        return "최신 \(count)개 유지"
    }

    private var modeContextText: String {
        let orderMode = (store.runtime?.orderMode ?? "-").uppercased()
        let accountMode = (store.runtime?.accountMode ?? "-").uppercased()
        return "\(orderMode) / \(accountMode)"
    }

    private var backendBaseURLBinding: Binding<String> {
        Binding(
            get: { store.backendBaseURLDraft },
            set: { store.updateBackendBaseURLDraft($0) }
        )
    }

    private var backendBaseURLChanged: Bool {
        store.backendBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            != AppConfig.backendBaseURLInputString.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var serverAddressEditorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "server.rack")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                    .frame(width: 14)
                Text("서버 주소")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Spacer(minLength: 8)
                Button("기본값 복원") {
                    store.updateBackendBaseURLDraft("")
                    Task { await store.applyBackendBaseURLDraft() }
                }
                .buttonStyle(.borderless)
                .font(.caption)
                Button("적용") {
                    Task { await store.applyBackendBaseURLDraft() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!backendBaseURLChanged)
            }

            TextField("https://server.example:8008", text: backendBaseURLBinding)
                .textFieldStyle(.roundedBorder)
                .font(.caption.monospaced())

            Text("REST와 WebSocket은 이 주소를 기준으로 계산됩니다. 값을 비우면 기본 환경값을 사용합니다.")
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textQuaternary)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    private var cleanupStatusText: String {
        guard let dataManagement = store.appSettings?.dataManagement else { return "-" }
        let summary = dataManagement.lastCleanupSummary ?? "아직 실행 기록이 없습니다."
        guard let lastRun = dataManagement.lastCleanupAt else { return summary }
        return "\(summary) · \(DisplayFormatters.dateTime(lastRun))"
    }

    private var backupStatusText: String {
        guard let dataManagement = store.appSettings?.dataManagement else { return "-" }
        let summary = dataManagement.lastBackupSummary ?? "아직 실행 기록이 없습니다."
        let mode = backupModeLabel(dataManagement.backupMode)
        if let lastRun = dataManagement.lastBackupAt {
            if mode.isEmpty {
                return "\(summary) · \(DisplayFormatters.dateTime(lastRun))"
            }
            return "\(summary) · \(mode) · \(DisplayFormatters.dateTime(lastRun))"
        }
        if mode.isEmpty {
            return summary
        }
        return "\(summary) · \(mode)"
    }

    private var cleanupStatusTone: StatusTone {
        switch store.appSettings?.dataManagement.lastCleanupStatus?.lowercased() {
        case "success":
            return .success
        case "failed":
            return .warning
        case "pending":
            return .neutral
        default:
            return .neutral
        }
    }

    private var backupStatusTone: StatusTone {
        switch store.appSettings?.dataManagement.lastBackupStatus?.lowercased() {
        case "success":
            return .success
        case "partial_failure":
            return .warning
        case "failed":
            return .warning
        case "pending":
            return .neutral
        case "disabled":
            return .neutral
        default:
            return .neutral
        }
    }

    private func backupModeLabel(_ raw: String?) -> String {
        switch raw?.lowercased() {
        case "sqlite_file_copy":
            return "SQLite 파일 백업"
        case "postgres_pg_dump":
            return "PostgreSQL dump"
        case .some(let value) where !value.isEmpty:
            return value
        default:
            return ""
        }
    }

    private var autoBackupBinding: Binding<Bool> {
        Binding(
            get: { store.appSettings?.dataManagement.autoBackupEnabled ?? false },
            set: { newValue in
                Task {
                    await store.updateAutoBackupEnabled(newValue)
                }
            }
        )
    }

    private var logRetentionDaysBinding: Binding<Int> {
        Binding(
            get: { store.appSettings?.dataManagement.logRetentionDays ?? 30 },
            set: { newValue in
                Task {
                    await store.updateLogRetentionDays(newValue)
                }
            }
        )
    }

    private func notificationBinding(_ key: NotificationToggleKey) -> Binding<Bool> {
        Binding(
            get: {
                switch key {
                case .tradeFillNotificationsEnabled:
                    return store.appSettings?.notifications.tradeFillNotificationsEnabled ?? false
                case .tradeSignalNotificationsEnabled:
                    return store.appSettings?.notifications.tradeSignalNotificationsEnabled ?? false
                case .systemErrorNotificationsEnabled:
                    return store.appSettings?.notifications.systemErrorNotificationsEnabled ?? false
                }
            },
            set: { newValue in
                Task {
                    switch key {
                    case .tradeFillNotificationsEnabled:
                        await store.updateTradeFillNotifications(newValue)
                    case .tradeSignalNotificationsEnabled:
                        await store.updateTradeSignalNotifications(newValue)
                    case .systemErrorNotificationsEnabled:
                        await store.updateSystemErrorNotifications(newValue)
                    }
                }
            }
        )
    }

    private var notificationPermissionText: String {
        switch store.notificationPermissionStatus {
        case .authorized, .provisional:
            return "허용됨"
        case .notDetermined:
            return "요청 전"
        case .denied:
            return "권한 필요"
        case .unknown:
            return "확인 중"
        }
    }

    private var notificationPermissionTone: StatusTone {
        switch store.notificationPermissionStatus {
        case .authorized, .provisional:
            return .success
        case .denied:
            return .warning
        case .notDetermined, .unknown:
            return .neutral
        }
    }

    private func settingsStatusColor(_ status: AppSettingsStatusMessage) -> Color {
        switch status.kind {
        case .saving:
            return DesignTokens.Colors.textSecondary
        case .success:
            return DesignTokens.Colors.success
        case .error:
            return DesignTokens.Colors.warning
        }
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

private struct AdvancedWeightRangeControl: View {
    @Binding var rank: Double
    @Binding var turnover: Double
    @Binding var changePct: Double

    private let trackHeight: CGFloat = 14
    private let knobSize: CGFloat = 16

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { proxy in
                let width = max(proxy.size.width - knobSize, 1)
                let boundaries = normalizedBoundaries()
                let firstX = knobSize / 2 + CGFloat(boundaries.first / 100) * width
                let secondX = knobSize / 2 + CGFloat(boundaries.second / 100) * width
                let leadingInset = knobSize / 2
                let firstWidth = max(0, firstX - leadingInset)
                let middleWidth = max(0, secondX - firstX)
                let trailingWidth = max(0, proxy.size.width - leadingInset - secondX)

                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(DesignTokens.Colors.surface1.opacity(0.76))
                        .frame(height: trackHeight)

                    HStack(spacing: 0) {
                        Capsule(style: .continuous)
                            .fill(DesignTokens.Colors.info.opacity(0.82))
                            .frame(width: firstWidth, height: trackHeight)
                        Rectangle()
                            .fill(DesignTokens.Colors.warning.opacity(0.78))
                            .frame(width: middleWidth, height: trackHeight)
                        Capsule(style: .continuous)
                            .fill(DesignTokens.Colors.success.opacity(0.74))
                            .frame(width: trailingWidth, height: trackHeight)
                    }
                    .clipShape(Capsule(style: .continuous))

                    handle
                        .position(x: firstX, y: trackHeight / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let local = boundaryValue(from: value.location.x, width: width)
                                    update(firstBoundary: local, secondBoundary: boundaries.second)
                                }
                        )

                    handle
                        .position(x: secondX, y: trackHeight / 2)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let local = boundaryValue(from: value.location.x, width: width)
                                    update(firstBoundary: boundaries.first, secondBoundary: local)
                                }
                        )
                }
                .frame(height: max(knobSize, trackHeight))
            }
            .frame(height: knobSize)

            HStack(spacing: 8) {
                legendChip(title: "순위", value: rank, color: DesignTokens.Colors.info.opacity(0.82))
                legendChip(title: "거래대금", value: turnover, color: DesignTokens.Colors.warning.opacity(0.78))
                legendChip(title: "등락률", value: changePct, color: DesignTokens.Colors.success.opacity(0.74))
            }
        }
    }

    private var handle: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        DesignTokens.Colors.surface3.opacity(0.96),
                        DesignTokens.Colors.surface2.opacity(0.82),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .frame(width: knobSize, height: knobSize)
            .overlay(
                Circle()
                    .stroke(DesignTokens.Colors.borderMedium.opacity(0.95), lineWidth: 0.9)
            )
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 0.7)
                    .padding(1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
    }

    private func legendChip(title: String, value: Double, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text("\(title) \(Int(value.rounded()))")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(DesignTokens.Colors.textSecondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(DesignTokens.Colors.surface1.opacity(0.58))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.68), lineWidth: 0.8)
        )
    }

    private func normalizedBoundaries() -> (first: Double, second: Double) {
        let total = max(rank + turnover + changePct, 0.0001)
        let normalizedRank = (rank / total) * 100
        let normalizedTurnover = (turnover / total) * 100
        let first = max(0, min(100, normalizedRank))
        let second = max(first, min(100, normalizedRank + normalizedTurnover))
        return (first, second)
    }

    private func boundaryValue(from x: CGFloat, width: CGFloat) -> Double {
        let position = max(0, min(width, x - knobSize / 2))
        return Double(position / width) * 100
    }

    private func update(firstBoundary: Double, secondBoundary: Double) {
        let firstInt = Int(max(0, min(firstBoundary, secondBoundary)).rounded())
        let secondInt = Int(max(Double(firstInt), min(secondBoundary, 100)).rounded())
        let nextRank = Double(firstInt)
        let nextTurnover = Double(max(0, secondInt - firstInt))
        let nextChange = Double(max(0, 100 - secondInt))
        rank = nextRank
        turnover = nextTurnover
        changePct = nextChange
    }
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
