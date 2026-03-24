//
//  DashboardView.swift
//  AutotradingMac
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
                metricsRow
                accountStatusRow
                contentColumns
            }
            .padding(DesignTokens.Layout.pagePadding)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 10) {
            dashboardMetricCard(
                label: "총 평가금액",
                value: totalEvaluationText,
                change: totalEvaluationChangeText,
                trend: trendForValue(totalEvaluationChangeValue)
            )
            dashboardMetricCard(
                label: "예수금",
                value: cashText,
                change: nil,
                trend: .flat
            )
            dashboardMetricCard(
                label: "평가손익",
                value: valuationPnLText,
                change: valuationPnLChangeText,
                trend: trendForValue(store.pnlSummary.unrealizedPnlTotal)
            )
            dashboardMetricCard(
                label: "최근 7일 승률",
                value: winRateText,
                change: winRateChangeText,
                trend: .flat,
                iconSystemName: "target"
            )
        }
    }

    private func dashboardMetricCard(
        label: String,
        value: String,
        change: String?,
        trend: DashboardTrend,
        iconSystemName: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                if let iconSystemName {
                    Image(systemName: iconSystemName)
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
                }
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            if let change {
                HStack(spacing: 6) {
                    Text(change)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(trend.color)
                    Spacer(minLength: 0)
                }
            } else {
                Text(" ")
                    .font(.caption)
            }
        }
        .padding(DesignTokens.Layout.panelInnerPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appPanelStyle()
    }

    private var contentColumns: some View {
        HStack(alignment: .top, spacing: DesignTokens.Layout.sectionGap) {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
                scannerPanel
                holdingsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
                signalsPanel
                openOrdersPanel
                recentLogsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    @ViewBuilder
    private var accountStatusRow: some View {
        if let accountSummary {
            HStack(spacing: 8) {
                Text(accountSummary.accountLabel ?? "계좌")
                    .font(.caption.weight(.semibold))
                if let masked = accountSummary.maskedAccount {
                    Text(masked)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
                Text("주문 모드: \((store.runtime?.orderMode ?? "paper").uppercased())")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Text("계좌 기준: \((store.runtime?.accountMode ?? "paper").uppercased())")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                Spacer(minLength: 8)
                if !accountSummary.available {
                    Text(accountSummary.unavailableReason ?? "계좌 정보를 조회할 수 없습니다.")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Colors.warning)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.horizontal, 2)
        }
    }

    private var scannerPanel: some View {
        dashboardPanel(title: "스캔 종목", subtitle: "마지막 스캔: \(lastScanText)", noPadding: true) {
            if scannerItems.isEmpty {
                panelEmptyState("표시 가능한 스캔 종목이 없습니다.")
            } else {
                VStack(spacing: 0) {
                    ForEach(scannerItems) { item in
                        dashboardRow {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(item.code)
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: DashboardScannerColumns.rowMinHeight, alignment: .center)

                                scoreBadge(item.score)
                                    .frame(width: DashboardScannerColumns.scoreWidth, alignment: .center)

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(DisplayFormatters.number(item.price))
                                        .font(.subheadline.monospacedDigit())
                                    Text(DisplayFormatters.signedPercent(item.changePct))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(trendForValue(item.changePct).color)
                                }
                                .frame(width: DashboardScannerColumns.priceChangeWidth, alignment: .trailing)

                                Text(item.metricText)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    .frame(width: DashboardScannerColumns.metricWidth, alignment: .trailing)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
        }
    }

    private var holdingsPanel: some View {
        dashboardPanel(title: "보유 종목", subtitle: "\(store.currentPositions.count)개", noPadding: true) {
            if holdingItems.isEmpty {
                panelEmptyState("현재 보유 종목이 없습니다.")
            } else {
                VStack(spacing: 0) {
                    ForEach(holdingItems) { item in
                        dashboardRow {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text("\(DisplayFormatters.number(item.qty))주")
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("평단: \(DisplayFormatters.number(item.avgPrice))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    Text(DisplayFormatters.number(item.currentPrice))
                                        .font(.subheadline.monospacedDigit())
                                }
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(DisplayFormatters.pnl(item.pnl))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(trendForValue(item.pnl).color)
                                    Text(DisplayFormatters.percent(item.pnlPercent))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(trendForValue(item.pnl).color.opacity(0.85))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var signalsPanel: some View {
        dashboardPanel(title: "매매 신호", noPadding: true) {
            if signalItems.isEmpty {
                panelEmptyState("현재 요약할 매매 액션이 없습니다.")
            } else {
                VStack(spacing: 0) {
                    ForEach(signalItems) { item in
                        dashboardRow {
                            HStack(alignment: .center, spacing: 10) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(signalRowSecondaryText(item))
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                signalBadge(item.action.label, tone: actionTone(item.action))
                                    .frame(width: DashboardSignalColumns.actionWidth, alignment: .center)

                                StatusBadge(text: item.status.label, tone: statusTone(item.status))
                                    .frame(width: DashboardSignalColumns.statusWidth, alignment: .center)
                            }
                        }
                    }
                }
            }
        }
    }

    private var openOrdersPanel: some View {
        dashboardPanel(title: "미체결 주문", noPadding: true) {
            if openOrderItems.isEmpty {
                panelEmptyState("미체결 주문이 없습니다.")
            } else {
                VStack(spacing: 0) {
                    ForEach(openOrderItems) { item in
                        dashboardRow {
                            HStack(spacing: 10) {
                                Image(systemName: item.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(item.iconColor)
                                    .frame(width: 14)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(item.typeText)
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                }
                                Spacer(minLength: 8)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(DisplayFormatters.number(item.qty))주")
                                        .font(.caption.monospacedDigit())
                                    Text(item.priceText)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                                }
                                StatusBadge(text: item.statusText, tone: item.statusTone)
                            }
                        }
                    }
                }
            }
        }
    }

    private var recentLogsPanel: some View {
        dashboardPanel(title: "최근 로그", noPadding: true) {
            if logItems.isEmpty {
                panelEmptyState("표시할 최근 로그가 없습니다.")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(logItems.prefix(5)), id: \.id) { (item: DashboardLogItem) in
                        dashboardRow {
                            HStack(spacing: 10) {
                                Text(timeString(item.timestamp))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    .frame(width: 62, alignment: .leading)
                                Image(systemName: item.iconName)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(item.iconColor)
                                    .frame(width: 14)
                                HStack(spacing: 3) {
                                    Text(item.message)
                                        .font(.callout)
                                        .lineLimit(1)
                                    if let trailingAmount = item.trailingAmount {
                                        Text(trailingAmount)
                                            .font(.callout.monospacedDigit())
                                            .lineLimit(1)
                                            .foregroundStyle(item.trailingAmountColor ?? DesignTokens.Colors.textTertiary)
                                    }
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
        }
    }

    private func dashboardPanel<Content: View>(
        title: String,
        subtitle: String? = nil,
        noPadding: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title)
                    .font(DesignTokens.Typography.sectionTitle)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .padding(.horizontal, DesignTokens.Layout.panelInnerPadding)
            .padding(.top, 11)
            .padding(.bottom, 9)

            Divider().opacity(0.3)

            if noPadding {
                content()
            } else {
                content().padding(DesignTokens.Layout.panelInnerPadding)
            }
        }
        .appPanelStyle()
    }

    private func dashboardRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, DesignTokens.Layout.rowHorizontalPadding)
                .padding(.vertical, DesignTokens.Layout.rowVerticalPadding)
            Divider()
                .overlay(DesignTokens.Colors.borderSubtle)
                .opacity(0.55)
        }
    }

    private func panelEmptyState(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Layout.rowHorizontalPadding)
            .padding(.vertical, 11)
    }

    private func scoreBadge(_ value: Int) -> some View {
        Text("\(value)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(value >= 85 ? DesignTokens.Colors.success : DesignTokens.Colors.info)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(value >= 85 ? DesignTokens.Colors.successBackground.opacity(0.85) : DesignTokens.Colors.infoBackground.opacity(0.82))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.6), lineWidth: 0.8)
            )
    }

    private func signalBadge(_ text: String, tone: StatusTone) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(tone.background.opacity(0.78))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.58), lineWidth: 0.8)
            )
    }

    private var symbolByCode: [String: String] {
        var map: [String: String] = [:]
        func merge(code: String?, symbol: String?) {
            guard
                let code,
                !code.isEmpty,
                let symbol,
                !symbol.isEmpty
            else { return }
            if map[code] == nil {
                map[code] = symbol
            }
        }

        store.marketRows.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentSignals.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentExitEvents.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentRiskDecisions.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentOrders.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentFills.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.currentPositions.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentClosedPositions.forEach { merge(code: $0.code, symbol: $0.symbol) }
        return map
    }

    private var scannerItems: [ScannerItem] {
        Array(store.marketRows.prefix(6)).map { row in
            ScannerItem(
                code: row.code,
                name: row.symbol.isEmpty || row.symbol == "-" ? row.code : row.symbol,
                score: scannerScore(for: row),
                price: row.price,
                changePct: row.changePct,
                metricText: DisplayFormatters.metricKorean(row.metric)
            )
        }
    }

    private var holdingItems: [HoldingItem] {
        Array(store.currentPositions.prefix(6)).map { row in
            let price = row.markPrice ?? row.avgPrice
            let pnl = row.unrealizedPnl
            let basis = (row.avgPrice ?? 0) * row.qty
            let percent = basis > 0 && pnl != nil ? (pnl! / basis) * 100.0 : nil
            return HoldingItem(
                code: row.code,
                name: instrumentName(symbol: row.symbol, code: row.code, fallback: row.code),
                qty: row.qty,
                avgPrice: row.avgPrice,
                currentPrice: price,
                pnl: pnl,
                pnlPercent: percent
            )
        }
    }

    private var signalItems: [DashboardSignalSummaryRow] {
        DashboardSignalSummaryBuilder.build(
            signals: store.recentSignals,
            strategyEvents: store.recentStrategyEvents,
            riskDecisions: store.recentRiskDecisions,
            orders: store.recentOrders,
            fills: store.recentFills,
            closedPositions: store.recentClosedPositions,
            symbolByCode: symbolByCode
        )
    }

    private var openOrderItems: [OpenOrderItem] {
        store.recentOrders
            .filter { row in
                let state = row.status.lowercased()
                return state != "filled" && state != "rejected" && state != "cancelled"
            }
            .prefix(6)
            .map { row in
                let style = EventVisualStyleResolver.order(side: row.side, status: row.status)
                return OpenOrderItem(
                    id: row.orderId,
                    name: instrumentName(symbol: row.symbol, code: row.code, fallback: row.code),
                    qty: row.orderQty,
                    typeText: row.side == "buy" ? "매수 주문" : "매도 주문",
                    priceText: DisplayFormatters.number(row.orderPrice),
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    statusText: row.status,
                    statusTone: .fromStatus(row.status)
                )
            }
    }

    private var logItems: [DashboardLogItem] {
        var items: [DashboardLogItem] = []
        items.append(
            contentsOf: store.recentExitEvents.map { row in
                let style = EventVisualStyleResolver.exit(
                    reason: row.reasonCode ?? row.reason,
                    partial: row.partial ?? false
                )
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code ?? "종목")
                return DashboardLogItem(
                    id: "exit-\(row.id)",
                    timestamp: row.createdAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: exitEventLogMessage(
                        instrumentName: displayName,
                        summary: row.summary,
                        reason: row.reasonCode ?? row.reason,
                        strategyLabel: row.strategyDisplayName,
                        partial: row.partial ?? false
                    ),
                    kind: .exit,
                    code: row.code,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: "sell",
                    status: row.reasonCode ?? row.reason,
                    sourceSignalReference: row.sourceSignalReference
                )
            }
        )
        items.append(
            contentsOf: store.recentFills.map { row in
                let style = EventVisualStyleResolver.fill(side: row.side)
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code)
                return DashboardLogItem(
                    id: "fill-\(row.fillId)",
                    timestamp: row.filledAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: "\(displayName) \(DisplayFormatters.number(row.filledQty))주 \(row.sideText) 체결 @ \(DisplayFormatters.number(row.filledPrice))",
                    kind: .fill,
                    code: row.code,
                    orderId: row.orderId,
                    sourceOrderId: nil,
                    side: row.side,
                    status: nil,
                    sourceSignalReference: nil
                )
            }
        )
        items.append(
            contentsOf: store.recentOrders.map { row in
                let style = EventVisualStyleResolver.order(side: row.side, status: row.status)
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code)
                return DashboardLogItem(
                    id: "order-\(row.orderId)-\(row.updatedAt.timeIntervalSince1970)",
                    timestamp: row.updatedAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: orderLogMessage(
                        instrumentName: displayName,
                        side: row.side,
                        status: row.status,
                        executionReason: row.executionReason
                    ),
                    kind: .order,
                    code: row.code,
                    orderId: row.orderId,
                    sourceOrderId: nil,
                    side: row.side,
                    status: row.status,
                    sourceSignalReference: row.sourceSignalReference
                )
            }
        )
        items.append(
            contentsOf: store.recentStrategyEvents.map { row in
                let style = EventVisualStyleResolver.risk(
                    decision: "blocked",
                    reason: row.reasonCode ?? row.reason ?? "",
                    signalType: row.signalType
                )
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code ?? "종목")
                return DashboardLogItem(
                    id: "strategy-event-\(row.id)",
                    timestamp: row.createdAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: strategyEventLogMessage(
                        instrumentName: displayName,
                        summary: row.summary,
                        reason: row.reasonCode ?? row.reason,
                        strategyLabel: row.strategyDisplayName
                    ),
                    kind: .risk,
                    code: row.code,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: row.signalType.map(signalSide),
                    status: row.reasonCode ?? row.reason,
                    sourceSignalReference: nil
                )
            }
        )
        items.append(
            contentsOf: store.recentRiskDecisions.map { row in
                let style = EventVisualStyleResolver.risk(
                    decision: row.decision,
                    reason: row.reasonCode ?? row.reason,
                    signalType: row.signalType
                )
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code ?? "종목")
                return DashboardLogItem(
                    id: "risk-\(row.id)",
                    timestamp: row.createdAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: riskLogMessage(
                        instrumentName: displayName,
                        decision: row.decision,
                        reason: row.reasonCode ?? row.reason,
                        signalType: row.signalType,
                        summary: row.summary,
                        strategyLabel: row.strategyDisplayName
                    ),
                    kind: .risk,
                    code: row.code,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: row.signalType.map(signalSide),
                    status: row.decision,
                    sourceSignalReference: nil
                )
            }
        )
        items.append(
            contentsOf: store.recentSignals.map { row in
                let style = EventVisualStyleResolver.signal(signalType: row.signalType)
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code)
                return DashboardLogItem(
                    id: "signal-\(row.id)",
                    timestamp: row.createdAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: signalLogMessage(
                        instrumentName: displayName,
                        signalType: row.signalType,
                        summary: row.summary,
                        strategyLabel: row.strategyDisplayName
                    ),
                    kind: .signal,
                    code: row.code,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: nil,
                    status: row.signalType,
                    sourceSignalReference: nil
                )
            }
        )
        items.append(
            contentsOf: store.recentClosedPositions.map { row in
                let style = EventVisualStyleResolver.close(reason: row.reasonCode ?? row.reason, realizedPnl: row.realizedPnl)
                let reasonText = closeReasonText(row.reasonCode ?? row.reason, summary: row.summary)
                let displayName = instrumentName(symbol: row.symbol, code: row.code, fallback: row.code ?? "종목")
                return DashboardLogItem(
                    id: "closed-\(row.id)",
                    timestamp: row.createdAt,
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: "\(displayName) \(reasonText)",
                    kind: .close,
                    code: row.code,
                    orderId: nil,
                    sourceOrderId: row.sourceOrderId,
                    side: "sell",
                    status: row.reasonCode ?? row.reason,
                    sourceSignalReference: row.sourceSignalReference,
                    trailingAmount: "(\(DisplayFormatters.pnl(row.realizedPnl)))",
                    trailingAmountColor: EventVisualStyleResolver.amountColor(forPnL: row.realizedPnl)
                )
            }
        )
        items.append(
            contentsOf: store.recentErrorItems.enumerated().map { idx, value in
                let style = EventVisualStyleResolver.risk(decision: "blocked", reason: value, signalType: nil)
                return DashboardLogItem(
                    id: "err-\(idx)",
                    timestamp: store.lastUpdatedAt ?? Date(),
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    message: value,
                    kind: .error,
                    code: nil,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: nil,
                    status: nil,
                    sourceSignalReference: nil
                )
            }
        )
        let sortedItems = items.sorted(by: { $0.timestamp > $1.timestamp })
        let candidates = sortedItems.map { item in
            ResultFeedEventCandidate(
                id: item.id,
                timestamp: item.timestamp,
                kind: item.kind,
                code: item.code,
                side: item.side,
                status: item.status,
                orderId: item.orderId,
                sourceOrderId: item.sourceOrderId,
                sourceSignalReference: item.sourceSignalReference
            )
        }
        let visibleIDs = ResultFeedReducer.visibleEventIDs(for: candidates)
        return sortedItems.filter { visibleIDs.contains($0.id) }
    }

    private func scannerScore(for row: MarketRow) -> Int {
        let rankScore: Double
        if let rank = row.rank {
            rankScore = max(0, 100 - (Double(rank) * 3.0))
        } else {
            rankScore = 50
        }
        let changeScore = min(max((row.changePct ?? 0) * 3.0, -20), 20)
        return max(0, min(100, Int((rankScore + changeScore).rounded())))
    }

    private var accountSummary: AccountSummarySnapshot? {
        store.runtime?.accountSummary
    }

    private var totalEvaluationValue: Double? {
        accountSummary?.totalAccountValue
    }

    private var totalEvaluationText: String { DisplayFormatters.krw(totalEvaluationValue) }

    private var totalEvaluationChangeValue: Double? { accountSummary?.unrealizedPnlTotal }

    private var totalEvaluationChangeText: String? {
        guard let totalEvaluationChangeValue else { return nil }
        return "평가손익 \(DisplayFormatters.pnl(totalEvaluationChangeValue))"
    }

    private var cashText: String { DisplayFormatters.krw(accountSummary?.cashBalance) }

    private var valuationPnLText: String { DisplayFormatters.pnl(accountSummary?.unrealizedPnlTotal) }

    private var valuationPnLChangeText: String? {
        guard let pnl = accountSummary?.unrealizedPnlTotal else { return nil }
        guard let total = totalEvaluationValue, total > 0 else { return nil }
        return DisplayFormatters.percent((pnl / total) * 100.0)
    }

    private var winRateValue: Double? {
        let closed = weeklyClosedPositionsForCurrentMode.compactMap(\.realizedPnl)
        guard !closed.isEmpty else { return nil }
        let wins = closed.filter { $0 > 0 }.count
        return (Double(wins) / Double(closed.count)) * 100.0
    }

    private var winRateText: String {
        guard let value = winRateValue else { return "-" }
        return DisplayFormatters.percent(value)
    }

    private var winRateChangeText: String? {
        guard winRateValue != nil else { return nil }
        return "기준: \(currentOrderModeLabel) · 최근 7일"
    }

    private var currentOrderModeForWinRate: String {
        let mode = (store.runtime?.orderMode ?? "paper").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return mode == "live" ? "live" : "paper"
    }

    private var currentOrderModeLabel: String {
        currentOrderModeForWinRate.uppercased()
    }

    private var weeklyClosedPositionsForCurrentMode: [ClosedPositionSnapshotItem] {
        let cutoff = Date().addingTimeInterval(-(7 * 24 * 60 * 60))
        return store.recentClosedPositions.filter { row in
            guard row.createdAt >= cutoff else { return false }
            let rowMode = (row.orderMode ?? row.executionMode ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            return rowMode == currentOrderModeForWinRate
        }
    }

    private var lastScanText: String {
        guard let last = store.lastUpdatedAt else { return "대기 중" }
        let delta = max(Int(Date().timeIntervalSince(last)), 0)
        if delta < 10 { return "방금 전" }
        if delta < 60 { return "\(delta)초 전" }
        if delta < 3600 { return "\(delta / 60)분 전" }
        return "\(delta / 3600)시간 전"
    }

    private func trendForValue(_ value: Double?) -> DashboardTrend {
        guard let value else { return .flat }
        if value > 0 { return .up }
        if value < 0 { return .down }
        return .flat
    }

    private func actionTone(_ action: DashboardSignalAction) -> StatusTone {
        switch action {
        case .buy:
            return .danger
        case .sell:
            return .info
        }
    }

    private func statusTone(_ status: DashboardSignalStatus) -> StatusTone {
        switch status {
        case .executed:
            return .success
        case .pending:
            return .warning
        case .monitoring:
            return .neutral
        case .blocked:
            return .warning
        }
    }

    private func instrumentName(symbol: String?, code: String?, fallback: String) -> String {
        if let symbol, !symbol.isEmpty {
            return symbol
        }
        if let code, !code.isEmpty, let mapped = symbolByCode[code] {
            return mapped
        }
        if let code, !code.isEmpty {
            return code
        }
        return fallback
    }

    private func signalRowSecondaryText(_ item: DashboardSignalSummaryRow) -> String {
        guard let strategyLabel = item.strategyLabel, !strategyLabel.isEmpty else {
            return item.summary
        }
        return "\(strategyLabel) · \(item.summary)"
    }

    private func closeReasonText(_ reason: String?, summary: String?) -> String {
        if let summary, !summary.isEmpty {
            return summary
        }
        let normalized = (reason ?? "").lowercased()
        if normalized.contains("first_take_profit_partial") { return "1차 익절 분할청산" }
        if normalized.contains("initial_stop") { return "초기 손절 청산" }
        if normalized.contains("hard_time_stop") { return "하드 시간청산" }
        if normalized.contains("soft_time_stop") { return "소프트 시간청산" }
        if normalized.contains("market_close_exit") { return "장마감 강제청산" }
        if normalized.contains("take_profit") || normalized.contains("익절") { return "익절 청산" }
        if normalized.contains("stop_loss") || normalized.contains("손절") { return "손절 청산" }
        if normalized.contains("market_close") || normalized.contains("장마감") { return "장마감 청산" }
        if normalized.contains("max_holding") || normalized.contains("holding") || normalized.contains("time") { return "보유시간 만료 청산" }
        return "포지션 청산"
    }

    private func signalSide(_ signalType: String) -> String {
        let normalized = signalType.lowercased()
        if normalized.contains("sell") || normalized.contains("exit") {
            return "sell"
        }
        return "buy"
    }

    private func signalLogMessage(
        instrumentName: String,
        signalType: String,
        summary: String?,
        strategyLabel: String?
    ) -> String {
        if let summary, !summary.isEmpty {
            if let strategyLabel, !strategyLabel.isEmpty {
                return "\(instrumentName) \(strategyLabel) · \(summary)"
            }
            return "\(instrumentName) \(summary)"
        }
        let normalized = signalType.lowercased()
        if normalized.contains("watch") || normalized.contains("maintained") || normalized.contains("wait") || normalized.contains("hold") || normalized.contains("관망") {
            return "\(instrumentName) 관망 신호"
        }
        if normalized.contains("sell") || normalized.contains("exit") {
            return "\(instrumentName) 매도 신호 생성"
        }
        return "\(instrumentName) 매수 신호 생성"
    }

    private func orderLogMessage(
        instrumentName: String,
        side: String,
        status: String,
        executionReason: String?
    ) -> String {
        if side.lowercased() == "sell", let executionReason, !executionReason.isEmpty {
            return "\(instrumentName) \(closeReasonText(executionReason, summary: nil))"
        }
        return "\(instrumentName) \(side.lowercased() == "buy" ? "매수" : "매도") 주문 \(status)"
    }

    private func strategyEventLogMessage(
        instrumentName: String,
        summary: String?,
        reason: String?,
        strategyLabel: String?
    ) -> String {
        let base = summary ?? closeReasonText(reason, summary: nil)
        if let strategyLabel, !strategyLabel.isEmpty {
            return "\(instrumentName) \(strategyLabel) · \(base)"
        }
        return "\(instrumentName) \(base)"
    }

    private func exitEventLogMessage(
        instrumentName: String,
        summary: String?,
        reason: String?,
        strategyLabel: String?,
        partial: Bool
    ) -> String {
        let base = summary ?? closeReasonText(reason, summary: nil)
        let normalizedBase = partial && !base.contains("부분") ? "부분청산 · \(base)" : base
        if let strategyLabel, !strategyLabel.isEmpty {
            return "\(instrumentName) \(strategyLabel) · \(normalizedBase)"
        }
        return "\(instrumentName) \(normalizedBase)"
    }

    private func riskLogMessage(
        instrumentName: String,
        decision: String,
        reason: String,
        signalType: String?,
        summary: String?,
        strategyLabel: String?
    ) -> String {
        if let summary, !summary.isEmpty {
            if let strategyLabel, !strategyLabel.isEmpty {
                return "\(instrumentName) \(strategyLabel) · \(summary)"
            }
            return "\(instrumentName) \(summary)"
        }
        let normalizedDecision = decision.lowercased()
        let normalizedReason = reason.lowercased()
        let normalizedSignalType = signalType?.lowercased() ?? ""

        if normalizedDecision == "approved" {
            if normalizedSignalType.contains("sell") || normalizedSignalType.contains("exit") {
                return "\(instrumentName) 청산 승인"
            }
            return "\(instrumentName) 진입 승인"
        }

        if normalizedReason.contains("daily_trade_limit_reached") {
            return "\(instrumentName) 일일 거래 한도로 차단"
        }
        if normalizedReason.contains("daily_loss_limit_reached") {
            return "\(instrumentName) 일일 손실 한도로 차단"
        }
        if normalizedReason.contains("max_concurrent") {
            return "\(instrumentName) 동시 보유 한도로 차단"
        }
        if normalizedReason.contains("already_holding") || normalizedReason.contains("position_exists") || normalizedReason.contains("block_when_position_exists") {
            return "\(instrumentName) 보유 중으로 진입 보류"
        }
        if normalizedReason.contains("cooldown") || normalizedReason.contains("recent") {
            return "\(instrumentName) 재진입 대기 중"
        }
        return "\(instrumentName) 리스크 규칙으로 차단"
    }

}

private enum DashboardScannerColumns {
    static let rowMinHeight: CGFloat = 32
    static let scoreWidth: CGFloat = 42
    static let priceChangeWidth: CGFloat = 112
    static let metricWidth: CGFloat = 80
}

private enum DashboardSignalColumns {
    static let actionWidth: CGFloat = 56
    static let statusWidth: CGFloat = 74
}

private struct ScannerItem: Identifiable {
    let code: String
    let name: String
    let score: Int
    let price: Double?
    let changePct: Double?
    let metricText: String
    var id: String { code }
}

private struct HoldingItem: Identifiable {
    let code: String
    let name: String
    let qty: Double?
    let avgPrice: Double?
    let currentPrice: Double?
    let pnl: Double?
    let pnlPercent: Double?
    var id: String { code }
}

private struct OpenOrderItem: Identifiable {
    let id: Int
    let name: String
    let qty: Double?
    let typeText: String
    let priceText: String
    let iconName: String
    let iconColor: Color
    let statusText: String
    let statusTone: StatusTone
}

private struct DashboardLogItem: Identifiable {
    let id: String
    let timestamp: Date
    let iconName: String
    let iconColor: Color
    let message: String
    let kind: ResultFeedEventKind
    let code: String?
    let orderId: Int?
    let sourceOrderId: Int?
    let side: String?
    let status: String?
    let sourceSignalReference: String?
    let trailingAmount: String?
    let trailingAmountColor: Color?

    init(
        id: String,
        timestamp: Date,
        iconName: String,
        iconColor: Color,
        message: String,
        kind: ResultFeedEventKind,
        code: String?,
        orderId: Int?,
        sourceOrderId: Int?,
        side: String?,
        status: String?,
        sourceSignalReference: String?,
        trailingAmount: String? = nil,
        trailingAmountColor: Color? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.iconName = iconName
        self.iconColor = iconColor
        self.message = message
        self.kind = kind
        self.code = code
        self.orderId = orderId
        self.sourceOrderId = sourceOrderId
        self.side = side
        self.status = status
        self.sourceSignalReference = sourceSignalReference
        self.trailingAmount = trailingAmount
        self.trailingAmountColor = trailingAmountColor
    }
}

private enum DashboardTrend {
    case up
    case down
    case flat

    var color: Color {
        switch self {
        case .up:
            return DesignTokens.Colors.profit
        case .down:
            return DesignTokens.Colors.loss
        case .flat:
            return DesignTokens.Colors.textTertiary
        }
    }
}

private extension FillSnapshotItem {
    var sideText: String {
        switch side.lowercased() {
        case "buy":
            return "매수"
        case "sell":
            return "매도"
        default:
            return side
        }
    }
}

private extension OrderSnapshotItem {
    var sideText: String {
        switch side.lowercased() {
        case "buy":
            return "매수"
        case "sell":
            return "매도"
        default:
            return side
        }
    }
}

private func timeString(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ko_KR")
    formatter.dateFormat = "HH:mm:ss"
    return formatter.string(from: date)
}

#Preview("Dashboard") {
    DashboardView()
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
