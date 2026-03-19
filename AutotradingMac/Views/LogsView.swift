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
            Text("Logs")
                .font(.title3.bold())
            Text("좌측에서 최근 이벤트를 선택하고, 우측 패널에서 상세 정보를 확인합니다.")
                .foregroundStyle(.secondary)

            if logEntries.isEmpty {
                ContentUnavailableView("No recent events", systemImage: "tray")
            } else {
                HStack(spacing: 0) {
                    listPane

                    Divider()

                    detailPane
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .navigationTitle("Logs")
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
        .background(Color.black.opacity(0.08))
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
                return LogEntry(
                    id: "signal-\(signal.id)",
                    timestamp: signal.createdAt,
                    eventType: "signal.generated",
                    code: signal.code,
                    symbol: signal.symbol,
                    title: title,
                    summary: "signal=\(signal.signalType) confidence=\(DisplayFormatters.number(signal.confidence))",
                    feedMessage: "\(title) 신호 발생 (\(signal.signalType))",
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
                return LogEntry(
                    id: "risk-\(risk.id)",
                    timestamp: risk.createdAt,
                    eventType: "risk.\(risk.decision)",
                    code: risk.code ?? "-",
                    symbol: risk.symbol,
                    title: title,
                    summary: risk.reason,
                    feedMessage: risk.decision.lowercased() == "blocked"
                        ? "\(title) 신호가 리스크 규칙으로 차단됨"
                        : "\(title) 신호가 리스크 규칙을 통과함",
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
                return LogEntry(
                    id: "order-\(order.orderId)-\(order.updatedAt.timeIntervalSince1970)",
                    timestamp: order.updatedAt,
                    eventType: "order.updated",
                    code: order.code,
                    symbol: order.symbol,
                    title: title,
                    summary: "\(order.side) qty=\(DisplayFormatters.number(order.orderQty)) status=\(order.status)",
                    feedMessage: "\(title) \(order.side.uppercased()) 주문 상태: \(order.status)",
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
                return LogEntry(
                    id: "fill-\(fill.fillId)",
                    timestamp: fill.filledAt,
                    eventType: "fill.received",
                    code: fill.code,
                    symbol: fill.symbol,
                    title: title,
                    summary: "\(fill.side) qty=\(DisplayFormatters.number(fill.filledQty)) @ \(DisplayFormatters.number(fill.filledPrice))",
                    feedMessage: "\(title) \(fill.side.uppercased()) 체결 \(DisplayFormatters.number(fill.filledQty)) @ \(DisplayFormatters.number(fill.filledPrice))",
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
                return LogEntry(
                    id: "position-updated-\(position.id)-\(position.updatedAt.timeIntervalSince1970)",
                    timestamp: position.updatedAt,
                    eventType: "position.updated",
                    code: position.code,
                    symbol: position.symbol,
                    title: title,
                    summary: "qty=\(DisplayFormatters.number(position.qty)) unrealized=\(DisplayFormatters.pnl(position.unrealizedPnl))",
                    feedMessage: "\(title) 포지션 갱신, 평가손익 \(DisplayFormatters.pnl(position.unrealizedPnl))",
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
                return LogEntry(
                    id: "position-closed-\(closed.id)",
                    timestamp: closed.createdAt,
                    eventType: "position.closed",
                    code: closed.code ?? "-",
                    symbol: closed.symbol,
                    title: title,
                    summary: "realized_pnl=\(DisplayFormatters.pnl(closed.realizedPnl)) reason=\(closed.reason ?? "-")",
                    feedMessage: "\(title) 포지션 종료, 실현손익 \(DisplayFormatters.pnl(closed.realizedPnl))",
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
                    .foregroundStyle(.secondary)
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
                    ? Color.accentColor.opacity(0.26)
                    : Color.white.opacity(0.01),
                in: RoundedRectangle(cornerRadius: 8)
            )

            Rectangle()
                .fill(Color.white.opacity(0.08))
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
                        .foregroundStyle(.secondary)
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
                .foregroundStyle(.secondary)
            Text(value)
                .font(multiline ? .system(.body, design: .monospaced) : .body)
                .lineLimit(multiline ? nil : 1)
                .fixedSize(horizontal: false, vertical: multiline)
                .textSelection(.enabled)
        }
    }
}
