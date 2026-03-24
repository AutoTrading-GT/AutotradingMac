//
//  LogsView.swift
//  AutotradingMac
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: MonitoringStore
    @State private var selectedLogID: String?
    @State private var modeFilter: LogsModeFilter = .all

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            HStack(spacing: 10) {
                Text("좌측에서 최근 이벤트를 선택하고, 우측 패널에서 상세 정보를 확인합니다.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Spacer(minLength: 8)
                AppSegmentedControl(
                    options: LogsModeFilter.options,
                    selection: $modeFilter,
                    minSegmentWidth: 62,
                    height: 30
                )
                .frame(width: 290)
            }

            if logEntries.isEmpty {
                ContentUnavailableView("No recent events", systemImage: "tray")
            } else {
                HStack(spacing: 0) {
                    listPane

                    Divider()
                        .overlay(DesignTokens.Colors.borderSubtle)

                    detailPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .appPanelStyle()
            }
        }
        .padding()
        .onAppear {
            syncSelection()
        }
        .onChange(of: logEntryIDs) { _ in
            syncSelection()
        }
    }

    private var listPane: some View {
        List(logEntries, selection: $selectedLogID) { entry in
            LogFeedRow(
                entry: entry,
                isSelected: selectedLogID == entry.id
            )
                .tag(entry.id)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                .listRowBackground(Color.clear)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(DesignTokens.Colors.surface1.opacity(0.7))
        .frame(minWidth: 430, maxWidth: 510, maxHeight: .infinity)
    }

    private var detailPane: some View {
        Group {
            if let selectedEntry {
                LogDetailPanel(entry: selectedEntry)
            } else {
                ContentUnavailableView(
                    "로그를 선택하세요",
                    systemImage: "text.cursor",
                    description: Text("좌측 목록에서 이벤트를 선택하면 상세 정보가 표시됩니다.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(DesignTokens.Layout.panelInnerPadding)
        .background(DesignTokens.Colors.surface1.opacity(0.52))
    }

    private var selectedEntry: LogEntry? {
        guard let selectedLogID else { return nil }
        return logEntries.first(where: { $0.id == selectedLogID })
    }

    private var logEntryIDs: [String] {
        logEntries.map(\.id)
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

        store.recentSignals.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentStrategyEvents.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentRiskDecisions.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentOrders.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentFills.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.currentPositions.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.recentClosedPositions.forEach { merge(code: $0.code, symbol: $0.symbol) }
        store.marketRows.forEach { merge(code: $0.code, symbol: $0.symbol) }
        return map
    }

    private func syncSelection() {
        if logEntries.isEmpty {
            selectedLogID = nil
            return
        }

        if let selectedLogID, logEntries.contains(where: { $0.id == selectedLogID }) {
            return
        }

        selectedLogID = logEntries.first?.id
    }

    private var allLogEntries: [LogEntry] {
        var rows: [LogEntry] = []
        let ordersByID = Dictionary(uniqueKeysWithValues: store.recentOrders.map { ($0.orderId, $0) })
        let latestFillByOrderID = Dictionary(
            grouping: store.recentFills,
            by: \.orderId
        ).compactMapValues { group in
            group.max(by: { $0.filledAt < $1.filledAt })
        }

        rows.append(
            contentsOf: store.recentSignals.map { signal in
                let title = instrumentTitle(symbol: signal.symbol, code: signal.code)
                let displayName = instrumentDisplayName(symbol: signal.symbol, code: signal.code)
                let style = EventVisualStyleResolver.signal(signalType: signal.signalType)
                return LogEntry(
                    id: "signal-\(signal.id)",
                    timestamp: signal.createdAt,
                    eventType: "signal.generated",
                    code: signal.code,
                    symbol: signal.symbol,
                    title: title,
                    summary: signal.summary ?? "signal=\(signal.signalType) confidence=\(DisplayFormatters.number(signal.confidence))",
                    feedMessage: signalFeedMessage(
                        instrumentName: displayName,
                        signalType: signal.signalType,
                        confidence: signal.confidence,
                        summary: signal.summary,
                        strategyLabel: signal.strategyDisplayName
                    ),
                    status: signal.signalType,
                    executionMode: normalizeExecutionMode(signal.executionMode ?? signal.orderMode),
                    source: "strategy",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: signalMetaPairs(signal),
                    eventKind: .signal,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: nil
                )
            }
        )

        rows.append(
            contentsOf: store.recentStrategyEvents.map { event in
                let title = instrumentTitle(symbol: event.symbol, code: event.code)
                let displayName = instrumentDisplayName(symbol: event.symbol, code: event.code)
                let style = EventVisualStyleResolver.risk(
                    decision: "blocked",
                    reason: event.reasonCode ?? event.reason ?? "",
                    signalType: event.signalType
                )
                return LogEntry(
                    id: "strategy-event-\(event.id)",
                    timestamp: event.createdAt,
                    eventType: event.eventType,
                    code: event.code ?? "-",
                    symbol: event.symbol,
                    title: title,
                    summary: event.summary ?? event.reason ?? "-",
                    feedMessage: strategyEventFeedMessage(
                        instrumentName: displayName,
                        summary: event.summary,
                        reason: event.reasonCode ?? event.reason,
                        strategyLabel: event.strategyDisplayName
                    ),
                    status: event.reasonCode ?? event.reason,
                    executionMode: normalizeExecutionMode(event.executionMode ?? event.orderMode),
                    source: "strategy",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: strategyEventMetaPairs(event),
                    eventKind: .risk,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: event.signalType
                )
            }
        )

        rows.append(
            contentsOf: store.recentRiskDecisions.map { risk in
                let title = instrumentTitle(symbol: risk.symbol, code: risk.code)
                let displayName = instrumentDisplayName(symbol: risk.symbol, code: risk.code)
                let style = EventVisualStyleResolver.risk(
                    decision: risk.decision,
                    reason: risk.reasonCode ?? risk.reason,
                    signalType: risk.signalType
                )
                return LogEntry(
                    id: "risk-\(risk.id)",
                    timestamp: risk.createdAt,
                    eventType: "risk.\(risk.decision)",
                    code: risk.code ?? "-",
                    symbol: risk.symbol,
                    title: title,
                    summary: risk.summary ?? risk.reason,
                    feedMessage: riskFeedMessage(
                        instrumentName: displayName,
                        decision: risk.decision,
                        reason: risk.reason,
                        signalType: risk.signalType,
                        summary: risk.summary,
                        strategyLabel: risk.strategyDisplayName
                    ),
                    status: risk.decision,
                    executionMode: normalizeExecutionMode(risk.executionMode ?? risk.orderMode),
                    source: "risk",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: riskMetaPairs(risk),
                    eventKind: .risk,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: nil
                )
            }
        )

        rows.append(
            contentsOf: store.recentOrders.map { order in
                let title = instrumentTitle(symbol: order.symbol, code: order.code)
                let displayName = instrumentDisplayName(symbol: order.symbol, code: order.code)
                let style = EventVisualStyleResolver.order(side: order.side, status: order.status)
                return LogEntry(
                    id: "order-\(order.orderId)-\(order.updatedAt.timeIntervalSince1970)",
                    timestamp: order.updatedAt,
                    eventType: "order.updated",
                    code: order.code,
                    symbol: order.symbol,
                    title: title,
                    summary: order.executionReason ?? "\(order.side) qty=\(DisplayFormatters.number(order.orderQty)) status=\(order.status)",
                    feedMessage: orderFeedMessage(
                        instrumentName: displayName,
                        side: order.side,
                        qty: order.orderQty,
                        price: order.orderPrice,
                        status: order.status,
                        executionReason: order.executionReason
                    ),
                    status: order.status,
                    executionMode: normalizeExecutionMode(order.executionMode ?? order.orderMode),
                    source: order.orderMode ?? order.executionMode ?? "execution",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: orderMetaPairs(order),
                    eventKind: .order,
                    orderId: order.orderId,
                    sourceOrderId: nil,
                    side: order.side
                )
            }
        )

        rows.append(
            contentsOf: store.recentFills.map { fill in
                let title = instrumentTitle(symbol: fill.symbol, code: fill.code)
                let displayName = instrumentDisplayName(symbol: fill.symbol, code: fill.code)
                let style = EventVisualStyleResolver.fill(side: fill.side)
                return LogEntry(
                    id: "fill-\(fill.fillId)",
                    timestamp: fill.filledAt,
                    eventType: "fill.received",
                    code: fill.code,
                    symbol: fill.symbol,
                    title: title,
                    summary: "\(fill.side) qty=\(DisplayFormatters.number(fill.filledQty)) @ \(DisplayFormatters.number(fill.filledPrice))",
                    feedMessage: fillFeedMessage(
                        instrumentName: displayName,
                        side: fill.side,
                        qty: fill.filledQty,
                        price: fill.filledPrice
                    ),
                    status: fill.side,
                    executionMode: normalizeExecutionMode(fill.executionMode ?? fill.orderMode),
                    source: fill.orderMode ?? fill.executionMode ?? "execution",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: [
                        .init(key: "fill_id", value: "\(fill.fillId)"),
                        .init(key: "order_id", value: "\(fill.orderId)"),
                        .init(key: "side", value: fill.side),
                        .init(key: "filled_qty", value: DisplayFormatters.number(fill.filledQty)),
                        .init(key: "filled_price", value: DisplayFormatters.number(fill.filledPrice)),
                        .init(key: "order_mode", value: fill.orderMode ?? fill.executionMode ?? "-")
                    ],
                    eventKind: .fill,
                    orderId: fill.orderId,
                    sourceOrderId: nil,
                    side: fill.side
                )
            }
        )

        rows.append(
            contentsOf: store.currentPositions.map { position in
                let title = instrumentTitle(symbol: position.symbol, code: position.code)
                let displayName = instrumentDisplayName(symbol: position.symbol, code: position.code)
                let style = EventVisualStyleResolver.position(pnl: position.unrealizedPnl)
                return LogEntry(
                    id: "position-updated-\(position.id)-\(position.updatedAt.timeIntervalSince1970)",
                    timestamp: position.updatedAt,
                    eventType: "position.updated",
                    code: position.code,
                    symbol: position.symbol,
                    title: title,
                    summary: "qty=\(DisplayFormatters.number(position.qty)) unrealized=\(DisplayFormatters.pnl(position.unrealizedPnl))",
                    feedMessage: positionUpdateFeedMessage(
                        instrumentName: displayName,
                        pnl: position.unrealizedPnl
                    ),
                    status: position.side,
                    executionMode: "unknown",
                    source: position.markPriceSource ?? "execution",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: [
                        .init(key: "side", value: position.side),
                        .init(key: "qty", value: DisplayFormatters.number(position.qty)),
                        .init(key: "avg_price", value: DisplayFormatters.number(position.avgPrice)),
                        .init(key: "mark_price", value: DisplayFormatters.number(position.markPrice)),
                        .init(key: "mark_price_source", value: position.markPriceSource ?? "-"),
                        .init(key: "unrealized_pnl", value: DisplayFormatters.pnl(position.unrealizedPnl)),
                        .init(key: "unrealized_pnl_pct", value: DisplayFormatters.percent(position.unrealizedPnlPct))
                    ],
                    eventKind: .position,
                    orderId: nil,
                    sourceOrderId: nil,
                    side: position.side
                )
            }
        )

        rows.append(
            contentsOf: store.recentClosedPositions.map { closed in
                let title = instrumentTitle(symbol: closed.symbol, code: closed.code)
                let displayName = instrumentDisplayName(symbol: closed.symbol, code: closed.code)
                let style = EventVisualStyleResolver.close(reason: closed.reasonCode ?? closed.reason, realizedPnl: closed.realizedPnl)
                let relatedOrder = closed.sourceOrderId.flatMap { ordersByID[$0] }
                let relatedFill = closed.sourceOrderId.flatMap { latestFillByOrderID[$0] }
                var closeMetaPairs: [LogMetaPair] = [
                    .init(key: "position_id", value: optionalInt(closed.positionId)),
                    .init(key: "closed_qty", value: DisplayFormatters.number(closed.closedQty)),
                    .init(key: "avg_entry_price", value: DisplayFormatters.number(closed.avgEntryPrice)),
                    .init(key: "exit_price", value: DisplayFormatters.number(closed.exitPrice)),
                    .init(key: "realized_pnl", value: DisplayFormatters.pnl(closed.realizedPnl)),
                    .init(key: "realized_pnl_pct", value: DisplayFormatters.percent(closed.realizedPnlPct)),
                    .init(key: "reason", value: closed.reason ?? "-"),
                    .init(key: "reason_code", value: closed.reasonCode ?? "-"),
                    .init(key: "summary", value: closed.summary ?? "-"),
                    .init(key: "signal_type", value: closed.signalType ?? "-"),
                    .init(key: "strategy_id", value: closed.strategyId ?? "-"),
                    .init(key: "strategy_display_name", value: closed.strategyDisplayName ?? "-"),
                    .init(key: "holding_seconds", value: DisplayFormatters.number(closed.holdingSeconds))
                ]
                closeMetaPairs.append(
                    contentsOf: closeFlowMetaPairs(
                        sourceOrderId: closed.sourceOrderId,
                        sourceSignalReference: closed.sourceSignalReference,
                        order: relatedOrder,
                        fill: relatedFill
                    )
                )
                return LogEntry(
                    id: "position-closed-\(closed.id)",
                    timestamp: closed.createdAt,
                    eventType: "position.closed",
                    code: closed.code ?? "-",
                    symbol: closed.symbol,
                    title: title,
                    summary: closed.summary ?? "realized_pnl=\(DisplayFormatters.pnl(closed.realizedPnl)) reason=\(closed.reason ?? "-")",
                    feedMessage: positionClosedFeedMessage(
                        instrumentName: displayName,
                        reason: closed.reasonCode ?? closed.reason,
                        summary: closed.summary,
                        realizedPnl: closed.realizedPnl
                    ),
                    status: closed.reasonCode ?? closed.reason,
                    executionMode: normalizeExecutionMode(closed.executionMode ?? closed.orderMode),
                    source: "execution",
                    iconName: style.iconName,
                    iconColor: style.iconColor,
                    iconTone: style.tone,
                    metaPairs: closeMetaPairs,
                    eventKind: .close,
                    orderId: nil,
                    sourceOrderId: closed.sourceOrderId,
                    side: "sell"
                )
            }
        )

        let sorted = rows.sorted(by: { $0.timestamp > $1.timestamp })
        let candidates = sorted.map { entry in
            ResultFeedEventCandidate(
                id: entry.id,
                timestamp: entry.timestamp,
                kind: entry.eventKind,
                code: entry.code,
                side: entry.side,
                status: entry.status,
                orderId: entry.orderId,
                sourceOrderId: entry.sourceOrderId
            )
        }
        let visibleIDs = ResultFeedReducer.visibleEventIDs(for: candidates)
        return sorted.filter { visibleIDs.contains($0.id) }
            .prefix(120)
            .map { $0 }
    }

    private var logEntries: [LogEntry] {
        allLogEntries.filter { entry in
            switch modeFilter {
            case .all:
                return true
            case .paper:
                return entry.executionMode == "paper"
            case .live:
                return entry.executionMode == "live"
            case .unknown:
                return entry.executionMode == "unknown"
            }
        }
    }

    private func instrumentTitle(symbol: String?, code: String?) -> String {
        let codeText = code ?? "-"
        guard let resolvedSymbol = resolvedSymbol(symbol: symbol, code: code) else { return codeText }
        return "\(resolvedSymbol) (\(codeText))"
    }

    private func instrumentDisplayName(symbol: String?, code: String?) -> String {
        if let resolvedSymbol = resolvedSymbol(symbol: symbol, code: code) {
            return resolvedSymbol
        }
        if let code, !code.isEmpty {
            return code
        }
        return "종목"
    }

    private func resolvedSymbol(symbol: String?, code: String?) -> String? {
        if let symbol, !symbol.isEmpty {
            return symbol
        }
        guard let code, !code.isEmpty else { return nil }
        return symbolByCode[code]
    }

    private func optionalInt(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
    }

    private func optionalBool(_ value: Bool?) -> String {
        guard let value else { return "-" }
        return value ? "true" : "false"
    }

    private func normalizeExecutionMode(_ raw: String?) -> String {
        let normalized = (raw ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "paper" || normalized == "live" {
            return normalized
        }
        return "unknown"
    }

    private func closeFlowMetaPairs(
        sourceOrderId: Int?,
        sourceSignalReference: String?,
        order: OrderSnapshotItem?,
        fill: FillSnapshotItem?
    ) -> [LogMetaPair] {
        var pairs: [LogMetaPair] = [
            .init(key: "source_order_id", value: optionalInt(sourceOrderId)),
            .init(key: "source_signal_reference", value: sourceSignalReference ?? "-")
        ]

        if let order {
            pairs.append(.init(key: "related_order_status", value: order.status))
            pairs.append(.init(key: "related_order_side", value: order.side))
            pairs.append(.init(key: "related_order_qty", value: DisplayFormatters.number(order.orderQty)))
            pairs.append(.init(key: "related_order_price", value: DisplayFormatters.number(order.orderPrice)))
            pairs.append(.init(key: "related_order_updated_at", value: DisplayFormatters.dateTime(order.updatedAt)))
        } else {
            pairs.append(.init(key: "related_order_status", value: "-"))
        }

        if let fill {
            pairs.append(.init(key: "related_fill_qty", value: DisplayFormatters.number(fill.filledQty)))
            pairs.append(.init(key: "related_fill_price", value: DisplayFormatters.number(fill.filledPrice)))
            pairs.append(.init(key: "related_fill_at", value: DisplayFormatters.dateTime(fill.filledAt)))
        } else {
            pairs.append(.init(key: "related_fill_qty", value: "-"))
        }

        if sourceOrderId != nil || order != nil || fill != nil {
            pairs.append(.init(key: "compaction_note", value: "기본 목록에서는 주문/체결 단계를 청산 결과에 흡수해 표시"))
        }
        return pairs
    }

    private func signalMetaPairs(_ signal: SignalSnapshotItem) -> [LogMetaPair] {
        var pairs: [LogMetaPair] = [
            .init(key: "signal_type", value: signal.signalType),
            .init(key: "strategy_id", value: signal.strategyId ?? "-"),
            .init(key: "strategy_display_name", value: signal.strategyDisplayName ?? "-"),
            .init(key: "summary", value: signal.summary ?? "-"),
            .init(key: "confidence", value: DisplayFormatters.number(signal.confidence)),
            .init(key: "selection_mode", value: signal.selectionMode ?? "-"),
            .init(key: "rank_current", value: optionalInt(signal.rankCurrent)),
            .init(key: "rank_previous", value: optionalInt(signal.rankPrevious)),
            .init(key: "source_snapshot_id", value: optionalInt(signal.sourceSnapshotId)),
            .init(key: "previous_snapshot_id", value: optionalInt(signal.previousSnapshotId)),
        ]
        if let payload = signal.payload {
            pairs.append(.init(key: "open_impulse_return_pct", value: DisplayFormatters.percent(payload["open_impulse_return_pct"]?.doubleValue)))
            pairs.append(.init(key: "pullback_retrace_pct", value: DisplayFormatters.percent(payload["pullback_retrace_pct"]?.doubleValue)))
            pairs.append(.init(key: "pullback_bars", value: payload["pullback_bars"]?.intValue.map(String.init) ?? "-"))
            pairs.append(.init(key: "reentry_volume_ratio", value: DisplayFormatters.number(payload["reentry_volume_ratio"]?.doubleValue)))
            pairs.append(.init(key: "vwap_condition_met", value: payload["vwap_condition_met"]?.boolValue.map { $0 ? "true" : "false" } ?? "-"))
        }
        return pairs
    }

    private func strategyEventMetaPairs(_ event: StrategyEventSnapshotItem) -> [LogMetaPair] {
        [
            .init(key: "strategy_id", value: event.strategyId ?? "-"),
            .init(key: "strategy_display_name", value: event.strategyDisplayName ?? "-"),
            .init(key: "signal_type", value: event.signalType ?? "-"),
            .init(key: "stage", value: event.stage ?? "-"),
            .init(key: "reason", value: event.reason ?? "-"),
            .init(key: "reason_code", value: event.reasonCode ?? "-"),
            .init(key: "summary", value: event.summary ?? "-"),
            .init(key: "selection_mode", value: event.selectionMode ?? "-"),
            .init(key: "rank_current", value: optionalInt(event.rankCurrent)),
            .init(key: "source_snapshot_id", value: optionalInt(event.sourceSnapshotId)),
            .init(key: "candidate_metric", value: DisplayFormatters.number(event.candidateMetric)),
            .init(key: "details", value: jsonObjectText(event.details)),
        ]
    }

    private func riskMetaPairs(_ risk: RiskDecisionSnapshotItem) -> [LogMetaPair] {
        var pairs: [LogMetaPair] = [
            .init(key: "decision", value: risk.decision),
            .init(key: "blocked", value: optionalBool(risk.blocked)),
            .init(key: "reason", value: risk.reason),
            .init(key: "reason_code", value: risk.reasonCode ?? "-"),
            .init(key: "summary", value: risk.summary ?? "-"),
            .init(key: "strategy_id", value: risk.strategyId ?? "-"),
            .init(key: "strategy_display_name", value: risk.strategyDisplayName ?? "-"),
            .init(key: "signal_type", value: risk.signalType ?? "-"),
            .init(key: "signal_id", value: optionalInt(risk.signalId)),
            .init(key: "related_signal_reference", value: risk.relatedSignalReference ?? "-"),
        ]
        if let context = risk.context {
            pairs.append(.init(key: "selection_mode", value: context["selection_mode"]?.stringValue ?? "-"))
            pairs.append(.init(key: "rule", value: context["rule"]?.stringValue ?? context["rule_context"]?.objectValue?["rule"]?.stringValue ?? "-"))
            pairs.append(.init(key: "today_trade_count", value: context["rule_context"]?.objectValue?["today_trade_count"]?.intValue.map(String.init) ?? "-"))
        }
        return pairs
    }

    private func orderMetaPairs(_ order: OrderSnapshotItem) -> [LogMetaPair] {
        [
            .init(key: "order_id", value: "\(order.orderId)"),
            .init(key: "side", value: order.side),
            .init(key: "order_qty", value: DisplayFormatters.number(order.orderQty)),
            .init(key: "order_price", value: DisplayFormatters.number(order.orderPrice)),
            .init(key: "status", value: order.status),
            .init(key: "execution_reason", value: order.executionReason ?? "-"),
            .init(key: "signal_type", value: order.signalType ?? "-"),
            .init(key: "strategy_id", value: order.strategyId ?? "-"),
            .init(key: "strategy_display_name", value: order.strategyDisplayName ?? "-"),
            .init(key: "order_mode", value: order.orderMode ?? order.executionMode ?? "-"),
            .init(key: "source_signal_reference", value: order.sourceSignalReference ?? "-"),
            .init(key: "broker_order_id", value: order.brokerOrderId ?? "-"),
        ]
    }

    private func jsonObjectText(_ object: [String: JSONValue]?) -> String {
        guard let object, !object.isEmpty else { return "-" }
        return object
            .sorted(by: { $0.key < $1.key })
            .map { key, value in "\(key)=\(value.displayText)" }
            .joined(separator: ", ")
    }

    private func signalFeedMessage(
        instrumentName: String,
        signalType: String,
        confidence: Double?,
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
        let scoreText = confidenceScoreText(confidence)

        let base: String
        if normalized.contains("sell") || normalized.contains("exit") {
            base = "\(instrumentName) 매도 신호 생성"
        } else if normalized.contains("maintained") || normalized.contains("watch") || normalized.contains("wait") {
            base = "\(instrumentName) 관망 신호"
        } else {
            base = "\(instrumentName) 매수 신호 생성"
        }

        let reason: String
        if normalized.contains("jump") || normalized.contains("break") || normalized.contains("momentum") {
            reason = "모멘텀 돌파"
        } else if normalized.contains("new_entry") || normalized.contains("entry") {
            reason = "순위권 진입"
        } else if normalized.contains("maintained") {
            reason = "횡보 지속"
        } else if normalized.contains("resistance") {
            reason = "저항선 도달"
        } else {
            reason = ""
        }

        var suffix: [String] = []
        if !scoreText.isEmpty {
            suffix.append("점수: \(scoreText)")
        }
        if !reason.isEmpty {
            suffix.append(reason)
        }

        if suffix.isEmpty {
            return base
        }
        return "\(base) (\(suffix.joined(separator: ", ")))"
    }

    private func strategyEventFeedMessage(
        instrumentName: String,
        summary: String?,
        reason: String?,
        strategyLabel: String?
    ) -> String {
        let message = summary ?? "전략 조건 미충족으로 신호 제외"
        if let strategyLabel, !strategyLabel.isEmpty {
            return "\(instrumentName) \(strategyLabel) · \(message)"
        }
        if let reason, !reason.isEmpty {
            return "\(instrumentName) \(message) (\(reason))"
        }
        return "\(instrumentName) \(message)"
    }

    private func riskFeedMessage(
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
            return "\(instrumentName) 진입 승인"
        }

        if normalizedReason.contains("already_holding") || normalizedReason.contains("position") {
            return "\(instrumentName) 보유 중 종목으로 진입 보류"
        }
        if normalizedReason.contains("cooldown") || normalizedReason.contains("recent") {
            return "\(instrumentName) 재진입 대기 중으로 진입 보류"
        }
        if normalizedReason.contains("max_concurrent") {
            return "\(instrumentName) 동시 진입 한도 초과로 진입 보류"
        }
        if normalizedReason.contains("signal_type_not_allowed") || normalizedSignalType.contains("maintained") {
            return "\(instrumentName) 관망 신호로 진입 보류"
        }
        if normalizedReason.contains("stop_loss") {
            return "\(instrumentName) 손절 보호 규칙으로 진입 보류"
        }
        if normalizedReason.contains("take_profit") {
            return "\(instrumentName) 익절 보호 규칙으로 진입 보류"
        }
        return "\(instrumentName) 리스크 규칙으로 진입 보류"
    }

    private func orderFeedMessage(
        instrumentName: String,
        side: String,
        qty: Double?,
        price: Double?,
        status: String,
        executionReason: String?
    ) -> String {
        if side.lowercased() == "sell", let executionReason, !executionReason.isEmpty {
            return "\(instrumentName) \(localizedExitReason(executionReason))"
        }
        let sideText = sideTextKo(side)
        let qtyText = quantityText(qty)
        let orderTypeText = (price ?? 0) > 0 ? "지정가" : "시장가"
        let statusKey = status.lowercased()

        if statusKey == "submitted" || statusKey == "created" {
            return "\(instrumentName) \(orderTypeText) \(sideText) 주문 접수"
        }
        if statusKey == "rejected" {
            return "\(instrumentName) \(sideText) 주문 거부"
        }
        if statusKey == "cancelled" {
            return "\(instrumentName) \(sideText) 주문 취소"
        }
        if statusKey == "partially_filled" {
            return "\(instrumentName) \(sideText) 주문 부분 체결 진행"
        }
        if statusKey == "filled" {
            if !qtyText.isEmpty {
                return "\(instrumentName) \(qtyText) \(sideText) 주문 체결 완료"
            }
            return "\(instrumentName) \(sideText) 주문 체결 완료"
        }
        return "\(instrumentName) 주문 상태 업데이트"
    }

    private func fillFeedMessage(instrumentName: String, side: String, qty: Double?, price: Double?) -> String {
        let sideText = sideTextKo(side)
        let qtyText = quantityText(qty)
        let priceText = currencyText(price)

        if !qtyText.isEmpty && !priceText.isEmpty {
            return "\(instrumentName) \(qtyText) \(sideText) 체결 @ \(priceText)"
        }
        if !qtyText.isEmpty {
            return "\(instrumentName) \(qtyText) \(sideText) 체결"
        }
        return "\(instrumentName) \(sideText) 체결"
    }

    private func positionUpdateFeedMessage(instrumentName: String, pnl: Double?) -> String {
        if let pnl, pnl != 0 {
            return "\(instrumentName) 포지션 갱신, 평가손익 \(DisplayFormatters.pnl(pnl))"
        }
        return "\(instrumentName) 포지션 갱신"
    }

    private func positionClosedFeedMessage(
        instrumentName: String,
        reason: String?,
        summary: String?,
        realizedPnl: Double?
    ) -> String {
        if let summary, !summary.isEmpty {
            return "\(instrumentName) \(summary) (\(DisplayFormatters.pnl(realizedPnl)))"
        }
        let normalizedReason = reason?.lowercased() ?? ""
        let pnlText = DisplayFormatters.pnl(realizedPnl)

        if normalizedReason.contains("stop_loss") {
            return "\(instrumentName) 손절 청산 완료 (\(pnlText))"
        }
        if normalizedReason.contains("take_profit") {
            return "\(instrumentName) 익절 청산 완료 (\(pnlText))"
        }
        if normalizedReason.contains("time") || normalizedReason.contains("holding") {
            return "\(instrumentName) 보유시간 만료로 청산 (\(pnlText))"
        }
        return "\(instrumentName) 포지션 종료 (\(pnlText))"
    }

    private func localizedExitReason(_ reason: String) -> String {
        let normalized = reason.lowercased()
        if normalized.contains("first_take_profit_partial") {
            return "1차 익절 분할청산 주문"
        }
        if normalized.contains("initial_stop") || normalized.contains("stop_loss") {
            return "손절 청산 주문"
        }
        if normalized.contains("hard_time_stop") {
            return "하드 시간청산 주문"
        }
        if normalized.contains("soft_time_stop") {
            return "소프트 시간청산 주문"
        }
        if normalized.contains("market_close_exit") || normalized.contains("market_close") {
            return "장마감 청산 주문"
        }
        return "매도 주문"
    }

    private func confidenceScoreText(_ confidence: Double?) -> String {
        guard let confidence else { return "" }
        let score = confidence <= 1.0 ? confidence * 100.0 : confidence
        return "\(Int(score.rounded()))"
    }

    private func sideTextKo(_ side: String) -> String {
        let normalized = side.lowercased()
        if normalized == "buy" { return "매수" }
        if normalized == "sell" { return "매도" }
        return "주문"
    }

    private func quantityText(_ qty: Double?) -> String {
        guard let qty, qty > 0 else { return "" }
        let isInteger = abs(qty.rounded() - qty) < 0.000001
        if isInteger {
            return "\(Int(qty.rounded()))주"
        }
        return "\(DisplayFormatters.number(qty))주"
    }

    private func currencyText(_ price: Double?) -> String {
        guard let price, price > 0 else { return "" }
        return "\(DisplayFormatters.number(price))원"
    }
}

private struct LogMetaPair: Identifiable {
    var id: String { key }
    let key: String
    let value: String
}

private struct LogEntry: Identifiable {
    let id: String
    let timestamp: Date
    let eventType: String
    let code: String
    let symbol: String?
    let title: String
    let summary: String
    let feedMessage: String
    let status: String?
    let executionMode: String
    let source: String
    let iconName: String
    let iconColor: Color
    let iconTone: StatusTone
    let metaPairs: [LogMetaPair]
    let eventKind: ResultFeedEventKind
    let orderId: Int?
    let sourceOrderId: Int?
    let side: String?
}

private struct LogFeedRow: View {
    let entry: LogEntry
    let isSelected: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(displayTime(entry.timestamp))
                .font(.caption.monospacedDigit())
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: 76, alignment: .leading)

            Image(systemName: entry.iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(entry.iconColor)
                .frame(width: 16)

            Text(entry.feedMessage)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            StatusBadge(text: entry.executionMode.uppercased(), tone: modeTone(entry.executionMode))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    isSelected
                    ? DesignTokens.Colors.accentMuted.opacity(0.95)
                    : DesignTokens.Colors.surface1.opacity(0.40)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(
                    isSelected
                    ? DesignTokens.Colors.accent.opacity(0.55)
                    : DesignTokens.Colors.borderSubtle.opacity(0.35),
                    lineWidth: 0.8
                )
        )
    }

    private func displayTime(_ value: Date) -> String {
        let full = DisplayFormatters.dateTime(value)
        return String(full.suffix(8))
    }

    private func modeTone(_ mode: String) -> StatusTone {
        switch mode {
        case "paper":
            return .info
        case "live":
            return .warning
        default:
            return .neutral
        }
    }
}

private struct LogDetailPanel: View {
    let entry: LogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: entry.iconName)
                        .foregroundStyle(entry.iconColor)
                    Text("Log Detail")
                        .font(.title3.bold())
                    Spacer()
                    StatusBadge(
                        text: entry.eventType,
                        tone: .fromStatus(entry.status ?? entry.eventType)
                    )
                }

                detailRow(label: "timestamp", value: DisplayFormatters.dateTime(entry.timestamp))
                detailRow(label: "event_type", value: entry.eventType)
                detailRow(label: "code", value: entry.code)
                if let symbol = entry.symbol, !symbol.isEmpty {
                    detailRow(label: "symbol", value: symbol)
                }
                detailRow(label: "source", value: entry.source)
                detailRow(label: "execution_mode", value: entry.executionMode.uppercased())
                if let status = entry.status {
                    detailRow(label: "status", value: status)
                }
                detailRow(label: "summary", value: entry.summary, multiline: true)

                Divider()

                Text("Payload / Meta")
                    .font(.headline)

                ForEach(entry.metaPairs) { pair in
                    detailRow(label: pair.key, value: pair.value, multiline: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, multiline: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Text(value)
                .font(multiline ? .system(.body, design: .monospaced) : .body)
                .lineLimit(multiline ? nil : 1)
                .fixedSize(horizontal: false, vertical: multiline)
                .textSelection(.enabled)
        }
    }
}

private enum LogsModeFilter: String, Hashable {
    case all
    case paper
    case live
    case unknown

    static var options: [AppSegmentedOption<LogsModeFilter>] {
        [
            .init(value: .all, title: "전체"),
            .init(value: .paper, title: "PAPER"),
            .init(value: .live, title: "LIVE"),
            .init(value: .unknown, title: "UNKNOWN"),
        ]
    }
}

#Preview("Logs") {
    LogsView()
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
