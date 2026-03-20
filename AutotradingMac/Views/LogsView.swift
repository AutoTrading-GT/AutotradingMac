//
//  LogsView.swift
//  AutotradingMac
//

import SwiftUI

struct LogsView: View {
    @EnvironmentObject private var store: MonitoringStore
    @State private var selectedLogID: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("좌측에서 최근 이벤트를 선택하고, 우측 패널에서 상세 정보를 확인합니다.")
                .foregroundStyle(DesignTokens.Colors.textSecondary)

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
        .background(DesignTokens.Colors.surface1)
        .frame(minWidth: 440, maxWidth: 520, maxHeight: .infinity)
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
        .padding()
    }

    private var selectedEntry: LogEntry? {
        guard let selectedLogID else { return nil }
        return logEntries.first(where: { $0.id == selectedLogID })
    }

    private var logEntryIDs: [String] {
        logEntries.map(\.id)
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

    private var logEntries: [LogEntry] {
        var rows: [LogEntry] = []

        rows.append(
            contentsOf: store.recentSignals.map { signal in
                let title = instrumentTitle(symbol: signal.symbol, code: signal.code)
                let displayName = instrumentDisplayName(symbol: signal.symbol, code: signal.code)
                return LogEntry(
                    id: "signal-\(signal.id)",
                    timestamp: signal.createdAt,
                    eventType: "signal.generated",
                    code: signal.code,
                    symbol: signal.symbol,
                    title: title,
                    summary: "signal=\(signal.signalType) confidence=\(DisplayFormatters.number(signal.confidence))",
                    feedMessage: signalFeedMessage(
                        instrumentName: displayName,
                        signalType: signal.signalType,
                        confidence: signal.confidence
                    ),
                    status: signal.signalType,
                    source: "strategy",
                    iconName: "dot.radiowaves.left.and.right",
                    iconTone: .info,
                    metaPairs: [
                        .init(key: "signal_type", value: signal.signalType),
                        .init(key: "confidence", value: DisplayFormatters.number(signal.confidence)),
                        .init(key: "source_snapshot_id", value: optionalInt(signal.sourceSnapshotId)),
                        .init(key: "previous_snapshot_id", value: optionalInt(signal.previousSnapshotId))
                    ]
                )
            }
        )

        rows.append(
            contentsOf: store.recentRiskDecisions.map { risk in
                let title = instrumentTitle(symbol: risk.symbol, code: risk.code)
                let displayName = instrumentDisplayName(symbol: risk.symbol, code: risk.code)
                return LogEntry(
                    id: "risk-\(risk.id)",
                    timestamp: risk.createdAt,
                    eventType: "risk.\(risk.decision)",
                    code: risk.code ?? "-",
                    symbol: risk.symbol,
                    title: title,
                    summary: risk.reason,
                    feedMessage: riskFeedMessage(
                        instrumentName: displayName,
                        decision: risk.decision,
                        reason: risk.reason,
                        signalType: risk.signalType
                    ),
                    status: risk.decision,
                    source: "risk",
                    iconName: risk.decision.lowercased() == "blocked" ? "exclamationmark.shield" : "checkmark.shield",
                    iconTone: risk.decision.lowercased() == "blocked" ? .danger : .success,
                    metaPairs: [
                        .init(key: "decision", value: risk.decision),
                        .init(key: "blocked", value: optionalBool(risk.blocked)),
                        .init(key: "reason", value: risk.reason),
                        .init(key: "signal_type", value: risk.signalType ?? "-"),
                        .init(key: "signal_id", value: optionalInt(risk.signalId)),
                        .init(key: "related_signal_reference", value: risk.relatedSignalReference ?? "-")
                    ]
                )
            }
        )

        rows.append(
            contentsOf: store.recentOrders.map { order in
                let title = instrumentTitle(symbol: order.symbol, code: order.code)
                let displayName = instrumentDisplayName(symbol: order.symbol, code: order.code)
                return LogEntry(
                    id: "order-\(order.orderId)-\(order.updatedAt.timeIntervalSince1970)",
                    timestamp: order.updatedAt,
                    eventType: "order.updated",
                    code: order.code,
                    symbol: order.symbol,
                    title: title,
                    summary: "\(order.side) qty=\(DisplayFormatters.number(order.orderQty)) status=\(order.status)",
                    feedMessage: orderFeedMessage(
                        instrumentName: displayName,
                        side: order.side,
                        qty: order.orderQty,
                        price: order.orderPrice,
                        status: order.status
                    ),
                    status: order.status,
                    source: order.executionMode ?? "execution",
                    iconName: order.status.lowercased() == "rejected" ? "xmark.circle" : "shippingbox",
                    iconTone: .fromStatus(order.status),
                    metaPairs: [
                        .init(key: "order_id", value: "\(order.orderId)"),
                        .init(key: "side", value: order.side),
                        .init(key: "order_qty", value: DisplayFormatters.number(order.orderQty)),
                        .init(key: "order_price", value: DisplayFormatters.number(order.orderPrice)),
                        .init(key: "status", value: order.status),
                        .init(key: "execution_mode", value: order.executionMode ?? "-"),
                        .init(key: "source_signal_reference", value: order.sourceSignalReference ?? "-"),
                        .init(key: "broker_order_id", value: order.brokerOrderId ?? "-")
                    ]
                )
            }
        )

        rows.append(
            contentsOf: store.recentFills.map { fill in
                let title = instrumentTitle(symbol: fill.symbol, code: fill.code)
                let displayName = instrumentDisplayName(symbol: fill.symbol, code: fill.code)
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
                    source: fill.executionMode ?? "execution",
                    iconName: "checkmark.circle.fill",
                    iconTone: .success,
                    metaPairs: [
                        .init(key: "fill_id", value: "\(fill.fillId)"),
                        .init(key: "order_id", value: "\(fill.orderId)"),
                        .init(key: "side", value: fill.side),
                        .init(key: "filled_qty", value: DisplayFormatters.number(fill.filledQty)),
                        .init(key: "filled_price", value: DisplayFormatters.number(fill.filledPrice)),
                        .init(key: "execution_mode", value: fill.executionMode ?? "-")
                    ]
                )
            }
        )

        rows.append(
            contentsOf: store.currentPositions.map { position in
                let title = instrumentTitle(symbol: position.symbol, code: position.code)
                let displayName = instrumentDisplayName(symbol: position.symbol, code: position.code)
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
                    source: position.markPriceSource ?? "execution",
                    iconName: "briefcase",
                    iconTone: .fromStatus(position.side),
                    metaPairs: [
                        .init(key: "side", value: position.side),
                        .init(key: "qty", value: DisplayFormatters.number(position.qty)),
                        .init(key: "avg_price", value: DisplayFormatters.number(position.avgPrice)),
                        .init(key: "mark_price", value: DisplayFormatters.number(position.markPrice)),
                        .init(key: "mark_price_source", value: position.markPriceSource ?? "-"),
                        .init(key: "unrealized_pnl", value: DisplayFormatters.pnl(position.unrealizedPnl)),
                        .init(key: "unrealized_pnl_pct", value: DisplayFormatters.percent(position.unrealizedPnlPct))
                    ]
                )
            }
        )

        rows.append(
            contentsOf: store.recentClosedPositions.map { closed in
                let title = instrumentTitle(symbol: closed.symbol, code: closed.code)
                let displayName = instrumentDisplayName(symbol: closed.symbol, code: closed.code)
                return LogEntry(
                    id: "position-closed-\(closed.id)",
                    timestamp: closed.createdAt,
                    eventType: "position.closed",
                    code: closed.code ?? "-",
                    symbol: closed.symbol,
                    title: title,
                    summary: "realized_pnl=\(DisplayFormatters.pnl(closed.realizedPnl)) reason=\(closed.reason ?? "-")",
                    feedMessage: positionClosedFeedMessage(
                        instrumentName: displayName,
                        reason: closed.reason,
                        realizedPnl: closed.realizedPnl
                    ),
                    status: closed.reason,
                    source: "execution",
                    iconName: "flag.checkered",
                    iconTone: toneForPnL(closed.realizedPnl),
                    metaPairs: [
                        .init(key: "position_id", value: optionalInt(closed.positionId)),
                        .init(key: "closed_qty", value: DisplayFormatters.number(closed.closedQty)),
                        .init(key: "avg_entry_price", value: DisplayFormatters.number(closed.avgEntryPrice)),
                        .init(key: "exit_price", value: DisplayFormatters.number(closed.exitPrice)),
                        .init(key: "realized_pnl", value: DisplayFormatters.pnl(closed.realizedPnl)),
                        .init(key: "realized_pnl_pct", value: DisplayFormatters.percent(closed.realizedPnlPct)),
                        .init(key: "reason", value: closed.reason ?? "-")
                    ]
                )
            }
        )

        return rows
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(120)
            .map { $0 }
    }

    private func instrumentTitle(symbol: String?, code: String?) -> String {
        let codeText = code ?? "-"
        guard let symbol, !symbol.isEmpty else { return codeText }
        return "\(symbol) (\(codeText))"
    }

    private func instrumentDisplayName(symbol: String?, code: String?) -> String {
        if let symbol, !symbol.isEmpty {
            return symbol
        }
        if let code, !code.isEmpty {
            return code
        }
        return "종목"
    }

    private func optionalInt(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
    }

    private func optionalBool(_ value: Bool?) -> String {
        guard let value else { return "-" }
        return value ? "true" : "false"
    }

    private func toneForPnL(_ value: Double?) -> StatusTone {
        guard let value else { return .neutral }
        if value > 0 { return .success }
        if value < 0 { return .danger }
        return .neutral
    }

    private func signalFeedMessage(instrumentName: String, signalType: String, confidence: Double?) -> String {
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

    private func riskFeedMessage(instrumentName: String, decision: String, reason: String, signalType: String?) -> String {
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
        status: String
    ) -> String {
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

    private func positionClosedFeedMessage(instrumentName: String, reason: String?, realizedPnl: Double?) -> String {
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
    let source: String
    let iconName: String
    let iconTone: StatusTone
    let metaPairs: [LogMetaPair]
}

private struct LogFeedRow: View {
    let entry: LogEntry
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                Text(displayTime(entry.timestamp))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                    .frame(width: 78, alignment: .leading)

                Image(systemName: entry.iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(entry.iconTone.foreground)
                    .frame(width: 18)

                Text(entry.feedMessage)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(
                isSelected
                    ? DesignTokens.Colors.accentMuted
                    : DesignTokens.Colors.surface1.opacity(0.55),
                in: RoundedRectangle(cornerRadius: 8)
            )

            Rectangle()
                .fill(DesignTokens.Colors.borderSubtle)
                .frame(height: 1)
                .padding(.leading, 8)
                .padding(.trailing, 4)
        }
    }

    private func displayTime(_ value: Date) -> String {
        let full = DisplayFormatters.dateTime(value)
        return String(full.suffix(8))
    }
}

private struct LogDetailPanel: View {
    let entry: LogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: entry.iconName)
                        .foregroundStyle(DesignTokens.Colors.textSecondary)
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
