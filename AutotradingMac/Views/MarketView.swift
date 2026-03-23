//
//  MarketView.swift
//  AutotradingMac
//

import SwiftUI

private enum ScannerLayout {
    static let paneSpacing: CGFloat = 16
    static let leftPaneWidth: CGFloat = 660
    static let rightPaneWidth: CGFloat = 440
    static let paneHeight: CGFloat = 520
    static let contentPadding: CGFloat = 16
    static let paneCornerRadius: CGFloat = 14

    static let columnSpacing: CGFloat = 2
    static let rankColumnWidth: CGFloat = 44
    static let priceColumnWidth: CGFloat = 88
    static let changeColumnWidth: CGFloat = 78
    static let metricColumnWidth: CGFloat = 88

    static let rowHeight: CGFloat = 38
    static let rowSpacing: CGFloat = 4
    static let visibleRows: CGFloat = 10
    static let listViewportHeight: CGFloat = (visibleRows * rowHeight) + ((visibleRows - 1) * rowSpacing)
}

struct MarketView: View {
    @EnvironmentObject private var store: MonitoringStore
    @State private var scanMode: ScannerMode = .turnover

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            scannerHeader

            if candidates.isEmpty {
                if store.scannerIsLoading(mode: scanMode.rawValue) {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("스캔 종목 로딩 중...")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                ContentUnavailableView(
                    "스캔 데이터가 없습니다",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("snapshot 또는 websocket market 이벤트 수신 후 후보가 표시됩니다.")
                )
                }
            } else {
                HStack(alignment: .top, spacing: ScannerLayout.paneSpacing) {
                    scannerListPane
                        .frame(width: ScannerLayout.leftPaneWidth, height: ScannerLayout.paneHeight, alignment: .topLeading)
                    scannerDetailPane
                        .frame(width: ScannerLayout.rightPaneWidth, height: ScannerLayout.paneHeight, alignment: .topLeading)
                }
                .frame(
                    width: ScannerLayout.leftPaneWidth + ScannerLayout.rightPaneWidth + ScannerLayout.paneSpacing,
                    height: ScannerLayout.paneHeight,
                    alignment: .topLeading
                )
            }
        }
        .padding(ScannerLayout.contentPadding)
        .onAppear {
            Task {
                await store.activateScannerMode(scanMode.rawValue)
                syncSelection()
                await store.refreshSelectedChartSeries(force: false)
            }
        }
        .onChange(of: candidateCodes) { _ in
            syncSelection()
        }
        .onChange(of: scanMode) { _ in
            Task {
                await store.activateScannerMode(scanMode.rawValue)
                syncSelection()
            }
        }
        .frame(
            width: ScannerLayout.leftPaneWidth + ScannerLayout.rightPaneWidth + ScannerLayout.paneSpacing + (ScannerLayout.contentPadding * 2),
            height: ScannerLayout.paneHeight + 92,
            alignment: .topLeading
        )
    }

    private var scannerHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text("종목 스캔")
                    .font(DesignTokens.Typography.title)

                HStack(spacing: 14) {
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.Colors.success)
                        Text("자동 갱신")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                        Text("최근 스캔: \(lastScanRelativeText)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                }
            }

            Spacer(minLength: 12)

            AppSegmentedControl(
                options: scannerModeOptions,
                selection: $scanMode,
                minSegmentWidth: 104,
                height: 34
            )
            .frame(width: 252)
        }
            .padding(.horizontal, DesignTokens.Layout.panelInnerPadding)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: ScannerLayout.paneCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                            DesignTokens.Colors.surface2.opacity(0.62),
                            DesignTokens.Colors.surface1.opacity(0.40),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: ScannerLayout.paneCornerRadius, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.85), lineWidth: 0.9)
        )
    }

    private var scannerListPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("스캔 후보")
                    .font(DesignTokens.Typography.sectionTitle)
                Spacer()
                Text(scanMode.shortDescription)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            VStack(spacing: 0) {
                scannerTableHeader
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(DesignTokens.Colors.surface1, in: RoundedRectangle(cornerRadius: 8))

                ScrollView {
                    LazyVStack(spacing: ScannerLayout.rowSpacing) {
                        ForEach(candidates) { candidate in
                            let isLastRow = candidate.id == candidates.last?.id
                            Button {
                                store.setSelectedScannerCode(candidate.code)
                            } label: {
                                ScannerCandidateRowView(
                                    candidate: candidate,
                                    isSelected: candidate.code == selectedCandidate?.code
                                )
                            }
                            .buttonStyle(.plain)
                            .frame(height: ScannerLayout.rowHeight)
                            .onAppear {
                                guard isLastRow else { return }
                                Task {
                                    await store.loadMoreScannerRanksIfNeeded(mode: scanMode.rawValue)
                                }
                            }
                        }

                        if store.scannerIsLoading(mode: scanMode.rawValue) {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("추가 종목 불러오는 중...")
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                        } else if !store.scannerCanLoadMore(mode: scanMode.rawValue), !candidates.isEmpty {
                            Text("최대 30위까지 표시됨")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Colors.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 8)
                        }

                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
                .frame(height: ScannerLayout.listViewportHeight)
            }
            .frame(maxHeight: .infinity)
        }
        .padding(DesignTokens.Layout.panelInnerPadding)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .scannerPaneStyle()
    }

    private var scannerDetailPane: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let selectedCandidate {
                detailPanel(for: selectedCandidate)
                    .frame(maxHeight: .infinity, alignment: .top)
            } else {
                ContentUnavailableView(
                    "선택된 종목이 없습니다",
                    systemImage: "cursorarrow.click",
                    description: Text("좌측 후보에서 종목을 선택하면 상세가 표시됩니다.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(DesignTokens.Layout.panelInnerPadding)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .scannerPaneStyle()
    }

    private func detailPanel(for candidate: ScannerCandidate) -> some View {
        let series = store.chartSeries(for: candidate.code, timeframe: store.selectedChartTimeframe)
        let chartPoints = series?.points ?? []
        let changeMetrics = TimeframeChangeCalculator.calculate(
            points: chartPoints,
            fallbackCurrentPrice: candidate.row.price,
            fallbackChangePercent: candidate.row.changePct
        )
        let trend = TrendDirection.from(changePercent: changeMetrics.changePercent)
        let signal = latestSignal(for: candidate.code)
        let holding = isHolding(code: candidate.code)
        let metrics = chartMetrics(
            from: chartPoints,
            fallbackCurrentPrice: changeMetrics.currentPrice ?? candidate.row.price,
            fallbackChangePct: changeMetrics.changePercent ?? candidate.row.changePct
        )
        let score = candidate.score
        let scoreTone: StatusTone = score >= 75 ? .success : (score >= 50 ? .warning : .neutral)
        let isLoadingChart = store.isChartLoading(for: candidate.code, timeframe: store.selectedChartTimeframe)
        let chartError = store.chartErrorMessage(for: candidate.code, timeframe: store.selectedChartTimeframe)

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.displayName)
                            .font(DesignTokens.Typography.title)
                        Text(candidate.code)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("스캔 점수")
                            .font(.caption2)
                            .foregroundStyle(DesignTokens.Colors.textSecondary)
                        Text("\(score)")
                            .font(.title3.monospacedDigit().weight(.semibold))
                            .foregroundStyle(scoreTone.foreground)
                    }
                }

                HStack(alignment: .center, spacing: 10) {
                    Text(DisplayFormatters.krw(changeMetrics.currentPrice ?? candidate.row.price))
                        .font(.title2.monospacedDigit().weight(.semibold))

                    HStack(spacing: 6) {
                        if trend == .up {
                            Image(systemName: "arrow.up.right")
                        } else if trend == .down {
                            Image(systemName: "arrow.down.right")
                        }
                        Text("\(DisplayFormatters.signedPercent(changeMetrics.changePercent))")
                        Text("(\(DisplayFormatters.signedNumber(changeMetrics.changeValue)))")
                    }
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                    .foregroundStyle(trend.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(trend == .up ? DesignTokens.Colors.profit.opacity(0.15) : (trend == .down ? DesignTokens.Colors.loss.opacity(0.15) : DesignTokens.Colors.surface2))
                    )
                }

                HStack(spacing: 8) {
                    StatusBadge(text: holding ? "보유 중" : "미보유", tone: holding ? .warning : .neutral)
                    if let signal, !signal.isEmpty {
                        StatusBadge(text: "최근 신호 \(signal)", tone: .fromStatus(signal))
                    }
                }
            }
            .padding(14)

            Divider().opacity(0.5)

            HStack {
                Text("차트")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
                Spacer()
                HStack(spacing: 6) {
                    if showsClosedIntradayHint {
                        ClosedIntradayHintIcon()
                    }

                    AppSegmentedControl(
                        options: chartTimeframeOptions,
                        selection: chartTimeframe,
                        minSegmentWidth: 48,
                        height: 34
                    )
                    .frame(width: 252)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            ZStack {
                TimeSeriesLineChartView(
                    points: chartPoints,
                    timeframe: store.selectedChartTimeframe,
                    lineColor: trend.color
                )
                    .frame(minHeight: 220, maxHeight: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)

                if isLoadingChart {
                    ProgressView("차트 로딩 중...")
                        .padding(10)
                        .appPanelStyle()
                } else if let chartError {
                    ContentUnavailableView(
                        "차트 조회 실패",
                        systemImage: "exclamationmark.triangle",
                        description: Text(chartError)
                    )
                    .padding(.horizontal, 16)
                } else if chartPoints.isEmpty {
                    ContentUnavailableView(
                        "차트 데이터 없음",
                        systemImage: "chart.xyaxis.line",
                        description: Text("해당 종목/구간의 시계열 데이터가 없습니다.")
                    )
                    .padding(.horizontal, 16)
                }
            }

            Divider().opacity(0.5)
            ChartMetricSummaryRow(items: chartSummaryItems(metrics))
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .appSurfaceStyle()
    }

    private var chartTimeframe: Binding<ChartTimeframeOption> {
        Binding(
            get: { store.selectedChartTimeframe },
            set: { store.setSelectedChartTimeframe($0) }
        )
    }

    private var scannerModeOptions: [AppSegmentedOption<ScannerMode>] {
        ScannerMode.allCases.map { .init(value: $0, title: $0.title) }
    }

    private var chartTimeframeOptions: [AppSegmentedOption<ChartTimeframeOption>] {
        ChartTimeframeOption.allCases.map { .init(value: $0, title: $0.title) }
    }

    private var showsClosedIntradayHint: Bool {
        MarketSessionResolver.shouldShowClosedIntradayHint(
            timeframe: store.selectedChartTimeframe,
            runtime: store.runtime
        )
    }

    private func chartSummaryItems(_ metrics: ScannerChartMetrics) -> [ChartMetricSummaryItem] {
        [
            .init(title: "시가", value: DisplayFormatters.krw(metrics.open), valueColor: DesignTokens.Colors.textPrimary),
            .init(title: "고가", value: DisplayFormatters.krw(metrics.high), valueColor: DesignTokens.Colors.profit.opacity(0.92)),
            .init(title: "저가", value: DisplayFormatters.krw(metrics.low), valueColor: DesignTokens.Colors.loss.opacity(0.92)),
            .init(title: "전일종가", value: DisplayFormatters.krw(metrics.prevClose), valueColor: DesignTokens.Colors.textPrimary),
            .init(title: "변동성", value: DisplayFormatters.percent(metrics.volatility), valueColor: DesignTokens.Colors.textSecondary),
        ]
    }

    private var candidates: [ScannerCandidate] {
        let scannerRows = store.scannerRows(for: scanMode.rawValue)
        return scannerRows.enumerated().map { index, row in
            let displayRank = index + 1
            return ScannerCandidate(
                row: row,
                displayRank: displayRank,
                score: score(for: row, index: index, total: scannerRows.count),
                reason: reasonText(for: row, rank: displayRank)
            )
        }
    }

    private var scannerTableHeader: some View {
        HStack(spacing: ScannerLayout.columnSpacing) {
            Text("순위")
                .font(.caption.weight(.semibold))
                .frame(width: ScannerLayout.rankColumnWidth, alignment: .center)

            Text("종목명")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("현재가")
                .font(.caption.weight(.semibold))
                .frame(width: ScannerLayout.priceColumnWidth, alignment: .trailing)

            Text("등락률")
                .font(.caption.weight(.semibold))
                .frame(width: ScannerLayout.changeColumnWidth, alignment: .trailing)

            Text("거래대금")
                .font(.caption.weight(.semibold))
                .frame(width: ScannerLayout.metricColumnWidth, alignment: .trailing)
        }
        .foregroundStyle(DesignTokens.Colors.textSecondary)
    }

    private var candidateCodes: [String] {
        candidates.map(\.code)
    }

    private var selectedCandidate: ScannerCandidate? {
        guard let selectedCode = store.selectedScannerCode else {
            return candidates.first
        }
        return candidates.first(where: { $0.code == selectedCode }) ?? candidates.first
    }

    private func syncSelection() {
        guard let first = candidates.first else {
            store.setSelectedScannerCode(nil)
            return
        }
        if let selected = store.selectedScannerCode, candidates.contains(where: { $0.code == selected }) {
            return
        }
        store.setSelectedScannerCode(first.code)
    }

    private func score(for row: MarketRow, index: Int, total: Int) -> Int {
        let divisor = max(total - 1, 1)
        let rankNorm = 1.0 - (Double(index) / Double(divisor))
        let rankScore = rankNorm * 40.0

        let changeNorm = min(max(((row.changePct ?? 0) + 5.0) / 20.0, 0.0), 1.0)
        let metricNorm = min(max(log10((row.metric ?? 0) + 1) / 11.0, 0.0), 1.0)

        let weighted: Double
        switch scanMode {
        case .turnover:
            weighted = rankScore + (metricNorm * 45.0) + (changeNorm * 15.0)
        case .surge:
            weighted = rankScore + (changeNorm * 45.0) + (metricNorm * 15.0)
        }
        return max(0, min(Int(weighted.rounded()), 100))
    }

    private func reasonText(for row: MarketRow, rank: Int) -> String {
        switch scanMode {
        case .turnover:
            return "거래대금 순위 \(rank) 기준으로 노출 중입니다. 거래대금 \(DisplayFormatters.metricKorean(row.metric)), 등락률 \(DisplayFormatters.signedPercent(row.changePct))."
        case .surge:
            return "급등률 순위 \(rank) 기준으로 노출 중입니다. 등락률 \(DisplayFormatters.signedPercent(row.changePct)), 거래대금 \(DisplayFormatters.metricKorean(row.metric))."
        }
    }

    private func chartMetrics(from points: [ChartPoint], fallbackCurrentPrice: Double?, fallbackChangePct: Double?) -> ScannerChartMetrics {
        let open = points.first?.open
        let high = points.map(\.high).max()
        let low = points.map(\.low).min()
        let current = fallbackCurrentPrice ?? points.last?.close

        let prevClose: Double?
        if points.count >= 2 {
            prevClose = points[points.count - 2].close
        } else if let current, let fallbackChangePct {
            let denominator = 1.0 + (fallbackChangePct / 100.0)
            if abs(denominator) > 0.0001 {
                prevClose = current / denominator
            } else {
                prevClose = nil
            }
        } else {
            prevClose = open
        }

        let volatility: Double?
        if points.count > 1 {
            let closes = points.map(\.close)
            let mean = closes.reduce(0, +) / Double(closes.count)
            let variance = closes.reduce(0) { partial, point in
                partial + pow(point - mean, 2.0)
            } / Double(points.count)
            volatility = mean > 0 ? sqrt(variance) / mean * 100.0 : nil
        } else {
            volatility = nil
        }

        return ScannerChartMetrics(
            open: open,
            high: high,
            low: low,
            prevClose: prevClose,
            volatility: volatility
        )
    }

    private func latestSignal(for code: String) -> String? {
        store.recentSignals.first(where: { $0.code == code })?.signalType
    }

    private func isHolding(code: String) -> Bool {
        store.currentPositions.contains(where: { $0.code == code && $0.qty > 0 })
    }

    private var lastScanRelativeText: String {
        guard let last = store.lastUpdatedAt else { return "대기 중" }
        let delta = max(Int(Date().timeIntervalSince(last)), 0)
        if delta < 10 { return "방금 전" }
        if delta < 60 { return "\(delta)초 전" }
        if delta < 3600 { return "\(delta / 60)분 전" }
        return "\(delta / 3600)시간 전"
    }
}

private extension View {
    func scannerPaneStyle() -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: ScannerLayout.paneCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.bgPanel.opacity(0.94),
                                DesignTokens.Colors.bgElevated.opacity(0.88),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: ScannerLayout.paneCornerRadius, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.82), lineWidth: 0.9)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: ScannerLayout.paneCornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.04), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 34)
                    .clipShape(
                        RoundedRectangle(cornerRadius: ScannerLayout.paneCornerRadius, style: .continuous)
                    )
            }
            .shadow(color: DesignTokens.Shadows.cardBase.opacity(0.22), radius: 6, x: 0, y: 2)
    }
}

private enum ScannerMode: String, CaseIterable, Identifiable {
    case turnover
    case surge

    var id: String { rawValue }

    var title: String {
        switch self {
        case .turnover:
            return "거래대금 순위"
        case .surge:
            return "급등률 순위"
        }
    }

    var shortDescription: String {
        switch self {
        case .turnover:
            return "거래대금 상위 종목"
        case .surge:
            return "등락률 상위 종목"
        }
    }
}

private struct ScannerCandidate: Identifiable {
    let row: MarketRow
    let displayRank: Int
    let score: Int
    let reason: String

    var id: String { row.id }
    var code: String { row.code }
    var displayName: String { row.symbol.isEmpty || row.symbol == "-" ? row.code : row.symbol }
}

private struct ScannerChartMetrics {
    let open: Double?
    let high: Double?
    let low: Double?
    let prevClose: Double?
    let volatility: Double?
}

private struct ScannerCandidateRowView: View {
    let candidate: ScannerCandidate
    let isSelected: Bool

    var body: some View {
        let trend = TrendDirection.from(changePercent: candidate.row.changePct)

        HStack(spacing: ScannerLayout.columnSpacing) {
            rankBox
                .frame(width: ScannerLayout.rankColumnWidth, alignment: .center)

            Text(candidate.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
                .layoutPriority(2)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(DisplayFormatters.krw(candidate.row.price))
                .font(.subheadline.monospacedDigit())
                .frame(width: ScannerLayout.priceColumnWidth, alignment: .trailing)

            Text("\(trend.symbol) \(DisplayFormatters.signedPercent(candidate.row.changePct))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .frame(width: ScannerLayout.changeColumnWidth, alignment: .trailing)

            Text(DisplayFormatters.metricKorean(candidate.row.metric))
                .font(.caption.monospacedDigit())
                .lineLimit(1)
                .frame(width: ScannerLayout.metricColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? DesignTokens.Colors.accentMuted : DesignTokens.Colors.surface1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private var rankBox: some View {
        Text("\(candidate.displayRank)")
            .font(.subheadline.monospacedDigit().weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .frame(width: 30, height: 24)
            .background(rankBackgroundColor, in: RoundedRectangle(cornerRadius: 7))
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(rankBorderColor, lineWidth: 1)
            )
    }

    private var rankBackgroundColor: Color {
        switch candidate.displayRank {
        case 1:
            return DesignTokens.Colors.accent.opacity(0.34)
        case 2:
            return DesignTokens.Colors.accent.opacity(0.26)
        case 3:
            return DesignTokens.Colors.accent.opacity(0.18)
        default:
            return DesignTokens.Colors.surface2
        }
    }

    private var rankBorderColor: Color {
        switch candidate.displayRank {
        case 1...3:
            return DesignTokens.Colors.accent.opacity(0.50)
        default:
            return DesignTokens.Colors.borderMedium
        }
    }
}

private enum TrendDirection {
    case up
    case down
    case flat
    case unknown

    static func from(changePercent: Double?) -> TrendDirection {
        guard let changePercent else { return .unknown }
        if changePercent > 0 { return .up }
        if changePercent < 0 { return .down }
        return .flat
    }

    var symbol: String {
        switch self {
        case .up:
            return "▲"
        case .down:
            return "▼"
        case .flat:
            return "•"
        case .unknown:
            return "-"
        }
    }

    var color: Color {
        switch self {
        case .up:
            return DesignTokens.Colors.profit
        case .down:
            return DesignTokens.Colors.loss
        case .flat:
            return DesignTokens.Colors.textSecondary
        case .unknown:
            return DesignTokens.Colors.textSecondary
        }
    }
}

#if DEBUG
private struct MarketViewPreviewContainer: View {
    @StateObject private var store = MonitoringStore(
        apiClient: MarketViewPreviewAPIClient()
    )

    var body: some View {
        MarketView()
            .environmentObject(store)
            .task {
                guard !store.snapshotLoaded, !store.isLoadingSnapshot else { return }
                await store.reloadSnapshot()
            }
            .background()
    }
}

private struct MarketViewPreviewAPIClient: MonitoringAPIClientProtocol {
    private static let previewSnapshot: MonitoringSnapshotResponse = {
        let json = """
        {
          "runtime": {
            "timestamp": "2026-03-20T09:10:00Z",
            "app_name": "autotrading-core",
            "app_version": "0.1.0",
            "env": "dev",
            "app_status": "ready",
            "order_mode": "paper",
            "account_mode": "paper",
            "engine_state": "running",
            "engine_available_actions": ["pause", "emergency_stop"],
            "engine_message": "engine running",
            "database_status": "connected",
            "database_connected": true,
            "readiness_status": "ready",
            "startup_ok": true,
            "startup_status": "ok",
            "active_ws_clients": 1,
            "account_summary": {
              "mode": "paper",
              "source": "paper_internal",
              "available": true,
              "account_label": "paper 내부계좌",
              "masked_account": "paper",
              "total_account_value": 100182400.0,
              "cash_balance": 95062400.0,
              "unrealized_pnl_total": 512000.0
            },
            "workers": {
              "summary": {
                "count": 4,
                "running": 4,
                "error": 0,
                "stopping": 0,
                "starting": 0,
                "stopped": 0
              },
              "workers": {
                "market_data": { "status": "running" },
                "strategy": { "status": "running" },
                "risk": { "status": "running" },
                "execution": { "status": "running" }
              }
            }
          },
          "market_top_ranks": [
            { "code": "005930", "symbol": "삼성전자", "rank": 1, "metric": 285000000000.0, "price": 71200.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "000660", "symbol": "SK하이닉스", "rank": 2, "metric": 232000000000.0, "price": 162500.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "005380", "symbol": "현대자동차", "rank": 3, "metric": 188000000000.0, "price": 251500.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "035420", "symbol": "NAVER", "rank": 4, "metric": 171500000000.0, "price": 214000.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "068270", "symbol": "셀트리온", "rank": 5, "metric": 158100000000.0, "price": 173000.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "005490", "symbol": "POSCO홀딩스", "rank": 6, "metric": 141600000000.0, "price": 359000.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "051910", "symbol": "LG화학", "rank": 7, "metric": 134200000000.0, "price": 402000.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "207940", "symbol": "삼성바이오로직스", "rank": 8, "metric": 120800000000.0, "price": 828000.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "003670", "symbol": "포스코퓨처엠", "rank": 9, "metric": 99800000000.0, "price": 259500.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" },
            { "code": "035720", "symbol": "카카오", "rank": 10, "metric": 88400000000.0, "price": 48700.0, "source": "preview.mock", "captured_at": "2026-03-20T09:09:58Z" }
          ],
          "recent_signals": [
            {
              "signal_id": 1102,
              "code": "005930",
              "symbol": "삼성전자",
              "signal_type": "new_entry",
              "confidence": 92.4,
              "source_snapshot_id": 8010,
              "previous_snapshot_id": 8008,
              "created_at": "2026-03-20T09:09:40Z"
            }
          ],
          "recent_risk_decisions": [],
          "recent_orders": [],
          "recent_fills": [],
          "current_positions": [
            {
              "position_id": 301,
              "code": "005930",
              "symbol": "삼성전자",
              "side": "buy",
              "qty": 120.0,
              "avg_price": 71200.0,
              "mark_price": 71900.0,
              "mark_price_source": "preview.mock",
              "unrealized_pnl": 84000.0,
              "unrealized_pnl_pct": 0.98,
              "updated_at": "2026-03-20T09:09:59Z"
            }
          ],
          "recent_closed_positions": [],
          "pnl_summary": {
            "open_positions": 1,
            "unrealized_pnl_total": 84000.0,
            "realized_pnl_recent_total": null,
            "recent_closed_count": 0
          },
          "limits": {
            "market_top_ranks": 50
          }
        }
        """

        do {
            return try MonitoringCoding.decoder().decode(
                MonitoringSnapshotResponse.self,
                from: Data(json.utf8)
            )
        } catch {
            fatalError("MarketView preview snapshot decode failed: \(error)")
        }
    }()

    func fetchSnapshot() async throws -> MonitoringSnapshotResponse {
        Self.previewSnapshot
    }

    func fetchRuntime() async throws -> RuntimeStatusSnapshot {
        Self.previewSnapshot.runtime
    }

    func fetchStrategySettings() async throws -> StrategySettingsResponseEnvelope {
        let snapshot = StrategySettingsSnapshot(
            scanner: ScannerSettingsSnapshot(
                modes: ["turnover", "surge"],
                defaultMode: "turnover",
                topN: 10,
                pageStep: 10,
                maxLimit: 30,
                candidateLimit: 30,
                rankingSource: "rank_snapshots",
                minTurnover: nil,
                minChangePct: nil,
                scoreDefinition: ScannerScoreDefinitionSnapshot(
                    name: "후보 우선순위 점수(관찰용)",
                    summary: "거래대금/등락률/상대순위를 조합한 스캐너 점수입니다.",
                    formulaBasis: "mode별 가중합",
                    weights: [
                        "turnover": ScannerScoreWeightsSnapshot(rank: 40, turnover: 45, changePct: 15),
                        "surge": ScannerScoreWeightsSnapshot(rank: 40, turnover: 15, changePct: 45),
                    ],
                    notes: []
                )
            ),
            signal: SignalSettingsSnapshot(
                topN: 10,
                rankJumpThreshold: 3,
                rankJumpWindowSeconds: 600,
                rankHoldTolerance: 1,
                enabledSignalTypes: ["new_entry", "rank_jump", "rank_maintained"]
            ),
            risk: RiskSettingsSnapshot(
                allowedSignalTypes: ["new_entry", "rank_jump"],
                maxConcurrentCandidates: 3,
                cooldownMinutes: 10,
                signalWindowMinutes: 10,
                concurrencyWindowMinutes: 15,
                blockWhenPositionExists: true
            )
        )
        return StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
    }

    func updateStrategySettings(_ payload: StrategySettingsUpdatePayload) async throws -> StrategySettingsResponseEnvelope {
        try await fetchStrategySettings()
    }

    func fetchAppSettings() async throws -> AppSettingsResponseEnvelope {
        let snapshot = AppSettingsSnapshot(
            notifications: NotificationSettingsSnapshot(
                tradeFillNotificationsEnabled: true,
                tradeSignalNotificationsEnabled: true,
                systemErrorNotificationsEnabled: false
            ),
            dataManagement: DataManagementSettingsSnapshot(
                autoBackupEnabled: true,
                logRetentionDays: 30,
                backupRetentionCount: 7,
                backupDirectory: "/tmp/autotrading-backups",
                storageUsageBytes: 25 * 1024 * 1024,
                storageUsageLabel: "25.0 MB"
            )
        )
        return AppSettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            updatedAt: Date()
        )
    }

    func updateAppSettings(_ payload: AppSettingsUpdatePayload) async throws -> AppSettingsUpdateResponseEnvelope {
        let response = try await fetchAppSettings()
        return AppSettingsUpdateResponseEnvelope(
            message: "preview app settings updated",
            data: response.data,
            defaults: response.defaults,
            updatedAt: response.updatedAt
        )
    }

    func fetchScannerRanks(mode: String, limit: Int) async throws -> ScannerRanksResponse {
        let normalized = mode.lowercased() == "surge" ? "surge" : "turnover"
        let all = Self.previewSnapshot.marketTopRanks
        let ranked: [MarketRankSnapshotItem]
        if normalized == "surge" {
            ranked = all.sorted { lhs, rhs in
                let l = lhs.changePct ?? -Double.greatestFiniteMagnitude
                let r = rhs.changePct ?? -Double.greatestFiniteMagnitude
                if l != r { return l > r }
                return (lhs.rank ?? Int.max) < (rhs.rank ?? Int.max)
            }
        } else {
            ranked = all.sorted { lhs, rhs in
                let l = lhs.metric ?? .leastNonzeroMagnitude
                let r = rhs.metric ?? .leastNonzeroMagnitude
                if l != r { return l > r }
                return (lhs.rank ?? Int.max) < (rhs.rank ?? Int.max)
            }
        }
        let boundedLimit = min(max(limit, 10), 50)
        return ScannerRanksResponse(
            mode: normalized,
            limit: boundedLimit,
            hasMore: ranked.count > boundedLimit,
            data: Array(ranked.prefix(boundedLimit)),
            count: min(ranked.count, boundedLimit)
        )
    }

    func fetchChartSeries(
        symbol: String,
        timeframe: ChartTimeframeOption,
        limit: Int
    ) async throws -> ChartSeriesResponse {
        let baseDate = Date()
        let points = (0..<max(limit, 20)).map { index -> ChartPoint in
            let ts = baseDate.addingTimeInterval(Double(index - max(limit, 20)) * 60)
            let close = 70_000.0 + (Double(index) * 12.0) + sin(Double(index) / 3.0) * 55.0
            return ChartPoint(
                ts: ts,
                open: close - 8.0,
                high: close + 15.0,
                low: close - 20.0,
                close: close,
                volume: 10_000 + Double(index * 120)
            )
        }
        return ChartSeriesResponse(
            symbol: symbol,
            timeframe: timeframe,
            source: "preview.mock.chart",
            timezone: "UTC",
            points: points
        )
    }

    func startEngine() async throws -> EngineControlCommandResponse {
        throw URLError(.unsupportedURL)
    }

    func pauseEngine() async throws -> EngineControlCommandResponse {
        throw URLError(.unsupportedURL)
    }

    func emergencyStopEngine() async throws -> EngineControlCommandResponse {
        throw URLError(.unsupportedURL)
    }

    func clearEmergencyStop() async throws -> EngineControlCommandResponse {
        throw URLError(.unsupportedURL)
    }

    func setOrderMode(_ mode: String, confirmLive: Bool) async throws -> EngineModeCommandResponse {
        throw URLError(.unsupportedURL)
    }

    func setAccountMode(_ mode: String) async throws -> EngineModeCommandResponse {
        throw URLError(.unsupportedURL)
    }
}

#Preview("Scanner / Mock Data") {
    MarketViewPreviewContainer()
}
#endif
