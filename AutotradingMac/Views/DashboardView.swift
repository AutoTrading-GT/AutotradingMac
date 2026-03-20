//
//  DashboardView.swift
//  AutotradingMac
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                metricsRow
                contentColumns
            }
            .padding(16)
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 12) {
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
                label: "승률",
                value: winRateText,
                change: winRateChangeText,
                trend: trendForValue(winRateDelta),
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
                        .foregroundStyle(.secondary)
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignTokens.Colors.bgPanel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private var contentColumns: some View {
        HStack(alignment: .top, spacing: 18) {
            VStack(alignment: .leading, spacing: 18) {
                scannerPanel
                holdingsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 18) {
                signalsPanel
                openOrdersPanel
                recentLogsPanel
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
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
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(item.code)
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                                }
                                Spacer(minLength: 8)
                                scoreBadge(item.score)
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(DisplayFormatters.number(item.price))
                                        .font(.subheadline.monospacedDigit())
                                    Text(DisplayFormatters.signedPercent(item.changePct))
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(trendForValue(item.changePct).color)
                                }
                                Text(item.metricText)
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    .frame(minWidth: 72, alignment: .trailing)
                            }
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
                panelEmptyState("최근 생성된 매매신호가 없습니다.")
            } else {
                VStack(spacing: 0) {
                    ForEach(signalItems) { item in
                        dashboardRow {
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.subheadline.weight(.medium))
                                        .lineLimit(1)
                                    Text(item.reason)
                                        .font(.caption2)
                                        .foregroundStyle(DesignTokens.Colors.textQuaternary)
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 8)
                                signalBadge(item.signalLabel, tone: item.signalTone)
                                StatusBadge(text: item.statusText, tone: item.statusTone)
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
                    ForEach(Array(logItems.prefix(8)), id: \.id) { (item: DashboardLogItem) in
                        dashboardRow {
                            HStack(spacing: 10) {
                                Text(timeString(item.timestamp))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(DesignTokens.Colors.textTertiary)
                                    .frame(width: 62, alignment: .leading)
                                Circle()
                                    .fill(item.tone.foreground)
                                    .frame(width: 7, height: 7)
                                Text(item.message)
                                    .font(.callout)
                                    .lineLimit(1)
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
                    .font(.headline)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(DesignTokens.Colors.textTertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            Divider().opacity(0.35)

            if noPadding {
                content()
            } else {
                content().padding(12)
            }
        }
        .background(DesignTokens.Colors.bgPanel, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private func dashboardRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            Divider().opacity(0.22)
        }
    }

    private func panelEmptyState(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
    }

    private func scoreBadge(_ value: Int) -> some View {
        Text("\(value)")
            .font(.caption.weight(.semibold))
            .foregroundStyle(value >= 85 ? DesignTokens.Colors.success : DesignTokens.Colors.info)
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(value >= 85 ? DesignTokens.Colors.successBackground : DesignTokens.Colors.infoBackground)
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
                    .fill(tone.background.opacity(0.9))
            )
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
                name: (row.symbol ?? "-").isEmpty ? row.code : (row.symbol ?? row.code),
                qty: row.qty,
                avgPrice: row.avgPrice,
                currentPrice: price,
                pnl: pnl,
                pnlPercent: percent
            )
        }
    }

    private var signalItems: [SignalItem] {
        Array(store.recentSignals.prefix(6)).map { row in
            let label: String
            if row.signalType.contains("buy") || row.signalType.contains("entry") {
                label = "매수"
            } else if row.signalType.contains("sell") || row.signalType.contains("exit") {
                label = "매도"
            } else {
                label = "관망"
            }

            let reason = row.signalType
            return SignalItem(
                id: row.id,
                name: row.symbol ?? row.code,
                signalLabel: label,
                signalTone: toneForSignalLabel(label),
                reason: reason,
                statusText: "모니터링",
                statusTone: .neutral
            )
        }
    }

    private var openOrderItems: [OpenOrderItem] {
        store.recentOrders
            .filter { row in
                let state = row.status.lowercased()
                return state != "filled" && state != "rejected" && state != "cancelled"
            }
            .prefix(6)
            .map { row in
                OpenOrderItem(
                    id: row.orderId,
                    name: row.symbol ?? row.code,
                    qty: row.orderQty,
                    typeText: row.side == "buy" ? "매수 주문" : "매도 주문",
                    priceText: DisplayFormatters.number(row.orderPrice),
                    statusText: row.status,
                    statusTone: .fromStatus(row.status)
                )
            }
    }

    private var logItems: [DashboardLogItem] {
        var items: [DashboardLogItem] = []
        items.append(
            contentsOf: store.recentFills.map { row in
                DashboardLogItem(
                    id: "fill-\(row.fillId)",
                    timestamp: row.filledAt,
                    tone: .success,
                    message: "\(row.symbol ?? row.code) \(DisplayFormatters.number(row.filledQty))주 \(row.sideText) 체결 @ \(DisplayFormatters.number(row.filledPrice))"
                )
            }
        )
        items.append(
            contentsOf: store.recentOrders.map { row in
                DashboardLogItem(
                    id: "order-\(row.orderId)-\(row.updatedAt.timeIntervalSince1970)",
                    timestamp: row.updatedAt,
                    tone: .fromStatus(row.status),
                    message: "\(row.symbol ?? row.code) \(row.sideText) 주문 \(row.status)"
                )
            }
        )
        items.append(
            contentsOf: store.recentSignals.map { row in
                DashboardLogItem(
                    id: "signal-\(row.id)",
                    timestamp: row.createdAt,
                    tone: .info,
                    message: "\(row.symbol ?? row.code) \(row.signalType) 신호 생성"
                )
            }
        )
        items.append(
            contentsOf: store.recentErrorItems.enumerated().map { idx, value in
                DashboardLogItem(
                    id: "err-\(idx)",
                    timestamp: store.lastUpdatedAt ?? Date(),
                    tone: .danger,
                    message: value
                )
            }
        )
        return items.sorted(by: { $0.timestamp > $1.timestamp })
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

    private var totalEvaluationValue: Double? {
        guard !store.currentPositions.isEmpty else { return nil }
        return store.currentPositions.reduce(0.0) { partial, row in
            let referencePrice = row.markPrice ?? row.avgPrice ?? 0.0
            return partial + (row.qty * referencePrice)
        }
    }

    private var totalEvaluationText: String { DisplayFormatters.number(totalEvaluationValue) }

    private var totalEvaluationChangeValue: Double? { store.pnlSummary.unrealizedPnlTotal }

    private var totalEvaluationChangeText: String? {
        guard totalEvaluationChangeValue != nil else { return nil }
        return DisplayFormatters.pnl(totalEvaluationChangeValue)
    }

    private var cashText: String { "-" }

    private var valuationPnLText: String { DisplayFormatters.pnl(store.pnlSummary.unrealizedPnlTotal) }

    private var valuationPnLChangeText: String? {
        guard let pnl = store.pnlSummary.unrealizedPnlTotal else { return nil }
        guard let total = totalEvaluationValue, total > 0 else { return nil }
        return DisplayFormatters.percent((pnl / total) * 100.0)
    }

    private var winRateValue: Double? {
        let closed = store.recentClosedPositions.compactMap(\.realizedPnl)
        guard !closed.isEmpty else { return nil }
        let wins = closed.filter { $0 > 0 }.count
        return (Double(wins) / Double(closed.count)) * 100.0
    }

    private var winRateText: String {
        guard let value = winRateValue else { return "-" }
        return DisplayFormatters.percent(value)
    }

    private var winRateDelta: Double? {
        guard let value = winRateValue else { return nil }
        return value - 50.0
    }

    private var winRateChangeText: String? {
        guard let delta = winRateDelta else { return nil }
        let sign = delta >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f%%", delta))"
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

    private func toneForSignalLabel(_ label: String) -> StatusTone {
        switch label {
        case "매수":
            return .success
        case "매도":
            return .danger
        default:
            return .neutral
        }
    }
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

private struct SignalItem: Identifiable {
    let id: String
    let name: String
    let signalLabel: String
    let signalTone: StatusTone
    let reason: String
    let statusText: String
    let statusTone: StatusTone
}

private struct OpenOrderItem: Identifiable {
    let id: Int
    let name: String
    let qty: Double?
    let typeText: String
    let priceText: String
    let statusText: String
    let statusTone: StatusTone
}

private struct DashboardLogItem: Identifiable {
    let id: String
    let timestamp: Date
    let tone: StatusTone
    let message: String
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
