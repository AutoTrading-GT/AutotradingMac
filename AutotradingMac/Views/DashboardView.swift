//
//  DashboardView.swift
//  AutotradingMac
//

import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                kpiRow
                bodyColumns
            }
            .padding()
        }
    }

    private var kpiRow: some View {
        HStack(spacing: 12) {
            kpiCard(
                title: "총 평가금액",
                value: totalEvaluationText,
                helper: totalEvaluationHelper,
                tone: .neutral
            )
            kpiCard(
                title: "예수금",
                value: cashText,
                helper: "계좌 현금 데이터 연동 전",
                tone: .neutral
            )
            kpiCard(
                title: "평가손익",
                value: valuationPnLText,
                helper: "PnL summary 기반",
                tone: toneForPnL(store.pnlSummary.unrealizedPnlTotal)
            )
            kpiCard(
                title: "승률",
                value: winRateText,
                helper: winRateHelper,
                tone: toneForWinRate
            )
        }
    }

    private func kpiCard(title: String, value: String, helper: String, tone: StatusTone) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
            HStack {
                StatusBadge(text: value, tone: tone)
                Spacer()
            }
            Text(helper)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var bodyColumns: some View {
        HStack(alignment: .top, spacing: 16) {
            leftColumn
                .frame(maxWidth: .infinity, alignment: .topLeading)

            rightColumn
                .frame(minWidth: 360, maxWidth: 440, alignment: .topLeading)
        }
    }

    private var leftColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            scannerSection
            holdingsSection
        }
    }

    private var rightColumn: some View {
        VStack(alignment: .leading, spacing: 16) {
            signalsSection
            openOrdersSection
            recentLogsSection
            systemSummarySection
        }
    }

    private var scannerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("스캔종목")
            if scannerRows.isEmpty {
                emptyState("표시 가능한 스캔 종목이 없습니다.")
            } else {
                Table(scannerRows) {
                    TableColumn("코드", value: \.code)
                    TableColumn("종목", value: \.symbol)
                    TableColumn("순위") { row in
                        Text(DisplayFormatters.integer(row.rank))
                    }
                    TableColumn("현재가") { row in
                        Text(DisplayFormatters.number(row.price))
                    }
                    TableColumn("거래대금") { row in
                        Text(DisplayFormatters.metric(row.metric))
                    }
                }
                .frame(minHeight: 220)
            }
        }
        .dashboardPanel()
    }

    private var holdingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("보유종목")
            if store.currentPositions.isEmpty {
                emptyState("현재 보유 종목이 없습니다.")
            } else {
                Table(store.currentPositions) {
                    TableColumn("코드", value: \.code)
                    TableColumn("종목") { row in
                        Text(row.symbol ?? "-")
                    }
                    TableColumn("수량") { row in
                        Text(DisplayFormatters.number(row.qty))
                    }
                    TableColumn("평균단가") { row in
                        Text(DisplayFormatters.number(row.avgPrice))
                    }
                    TableColumn("평가손익") { row in
                        Text(DisplayFormatters.pnl(row.unrealizedPnl))
                            .foregroundStyle(colorForPnL(row.unrealizedPnl))
                    }
                }
                .frame(minHeight: 220)
            }
        }
        .dashboardPanel()
    }

    private var signalsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("매매신호")
            if store.recentSignals.isEmpty {
                emptyState("최근 생성된 매매신호가 없습니다.")
            } else {
                Table(Array(store.recentSignals.prefix(12))) {
                    TableColumn("시간") { row in
                        Text(DisplayFormatters.dateTime(row.createdAt))
                    }
                    TableColumn("코드", value: \.code)
                    TableColumn("타입", value: \.signalType)
                }
                .frame(minHeight: 190)
            }
        }
        .dashboardPanel()
    }

    private var openOrdersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("미체결주문")
            if openOrders.isEmpty {
                emptyState("미체결 주문이 없습니다.")
            } else {
                Table(openOrders) {
                    TableColumn("시간") { row in
                        Text(DisplayFormatters.dateTime(row.updatedAt))
                    }
                    TableColumn("코드", value: \.code)
                    TableColumn("구분", value: \.side)
                    TableColumn("수량") { row in
                        Text(DisplayFormatters.number(row.orderQty))
                    }
                    TableColumn("상태") { row in
                        StatusBadge(text: row.status, tone: .fromStatus(row.status))
                    }
                }
                .frame(minHeight: 190)
            }
        }
        .dashboardPanel()
    }

    private var recentLogsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("최근로그")
            if logLines.isEmpty {
                emptyState("표시할 최근 로그가 없습니다.")
            } else {
                ForEach(logLines.prefix(12), id: \.id) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(DisplayFormatters.dateTime(line.timestamp))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                        StatusBadge(text: line.category, tone: .fromStatus(line.status))
                        Text(line.message)
                            .font(.callout)
                            .lineLimit(1)
                    }
                }
            }
        }
        .dashboardPanel()
    }

    private var systemSummarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("시스템 요약")
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
                GridRow {
                    Text("앱 상태").foregroundStyle(.secondary)
                    Text(store.runtime?.appStatus ?? "-")
                }
                GridRow {
                    Text("실행 모드").foregroundStyle(.secondary)
                    Text(store.runtime?.executionMode ?? "-")
                }
                GridRow {
                    Text("워커 상태").foregroundStyle(.secondary)
                    Text(workerHealthSummary)
                }
                GridRow {
                    Text("에러 개수").foregroundStyle(.secondary)
                    Text("\(store.recentErrorItems.count)")
                }
            }
        }
        .dashboardPanel()
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline)
    }

    private func emptyState(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private var scannerRows: [MarketRow] {
        Array(store.marketRows.prefix(20))
    }

    private var openOrders: [OrderSnapshotItem] {
        store.recentOrders.filter { order in
            let state = order.status.lowercased()
            return state != "filled" && state != "rejected" && state != "cancelled"
        }
    }

    private var totalEvaluationValue: Double? {
        guard !store.currentPositions.isEmpty else { return nil }
        return store.currentPositions.reduce(0.0) { partial, row in
            let referencePrice = row.markPrice ?? row.avgPrice ?? 0.0
            return partial + (row.qty * referencePrice)
        }
    }

    private var totalEvaluationText: String {
        DisplayFormatters.number(totalEvaluationValue)
    }

    private var totalEvaluationHelper: String {
        guard totalEvaluationValue != nil else { return "보유종목 데이터 없음" }
        return "보유 수량 x 평가가격 기준"
    }

    private var cashText: String {
        "-"
    }

    private var valuationPnLText: String {
        DisplayFormatters.pnl(store.pnlSummary.unrealizedPnlTotal)
    }

    private var winRateValue: Double? {
        let closed = store.recentClosedPositions.compactMap(\.realizedPnl)
        guard !closed.isEmpty else { return nil }
        let wins = closed.filter { $0 > 0 }.count
        return (Double(wins) / Double(closed.count)) * 100.0
    }

    private var winRateText: String {
        guard let winRateValue else { return "-" }
        return DisplayFormatters.percent(winRateValue)
    }

    private var winRateHelper: String {
        guard winRateValue != nil else { return "종료 포지션 데이터 없음" }
        return "최근 종료 포지션 기준"
    }

    private var toneForWinRate: StatusTone {
        guard let value = winRateValue else { return .neutral }
        if value >= 50.0 { return .success }
        return .warning
    }

    private func toneForPnL(_ value: Double?) -> StatusTone {
        guard let value else { return .neutral }
        if value > 0 { return .success }
        if value < 0 { return .danger }
        return .neutral
    }

    private func colorForPnL(_ value: Double?) -> Color {
        guard let value else { return .secondary }
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    private var workerHealthSummary: String {
        guard let summary = store.runtime?.workers.summary else { return "-" }
        return "\(summary.running)/\(summary.count) running"
    }

    private var logLines: [DashboardLogLine] {
        var lines: [DashboardLogLine] = []
        lines.append(
            contentsOf: store.recentSignals.map {
                DashboardLogLine(
                    id: "sig-\($0.id)",
                    timestamp: $0.createdAt,
                    category: "signal",
                    status: $0.signalType,
                    message: "\($0.code) \($0.signalType)"
                )
            }
        )
        lines.append(
            contentsOf: store.recentRiskDecisions.map {
                DashboardLogLine(
                    id: "risk-\($0.id)",
                    timestamp: $0.createdAt,
                    category: "risk",
                    status: $0.decision,
                    message: "\($0.code ?? "-") \($0.reason)"
                )
            }
        )
        lines.append(
            contentsOf: store.recentOrders.map {
                DashboardLogLine(
                    id: "ord-\($0.orderId)-\($0.updatedAt.timeIntervalSince1970)",
                    timestamp: $0.updatedAt,
                    category: "order",
                    status: $0.status,
                    message: "\($0.code) \($0.side) qty=\(DisplayFormatters.number($0.orderQty))"
                )
            }
        )
        lines.append(
            contentsOf: store.recentFills.map {
                DashboardLogLine(
                    id: "fill-\($0.fillId)",
                    timestamp: $0.filledAt,
                    category: "fill",
                    status: $0.side,
                    message: "\($0.code) qty=\(DisplayFormatters.number($0.filledQty)) @ \(DisplayFormatters.number($0.filledPrice))"
                )
            }
        )
        lines.append(
            contentsOf: store.recentErrorItems.enumerated().map { index, item in
                DashboardLogLine(
                    id: "err-\(index)",
                    timestamp: store.lastUpdatedAt ?? Date(),
                    category: "error",
                    status: "error",
                    message: item
                )
            }
        )
        return lines.sorted(by: { $0.timestamp > $1.timestamp })
    }
}

private struct DashboardLogLine: Identifiable {
    let id: String
    let timestamp: Date
    let category: String
    let status: String
    let message: String
}

private extension View {
    func dashboardPanel() -> some View {
        self
            .padding()
            .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }
}
