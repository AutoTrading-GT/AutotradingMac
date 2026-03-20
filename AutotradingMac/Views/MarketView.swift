//
//  MarketView.swift
//  AutotradingMac
//

import SwiftUI

private enum ScannerLayout {
    static let paneSpacing: CGFloat = 16
    static let leftPaneWidth: CGFloat = 660
    static let rightPaneWidth: CGFloat = 440
    static let paneHeight: CGFloat = 660
    static let contentPadding: CGFloat = 16

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
    @State private var chartTimeframe: ChartTimeframe = .minute1

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            scannerHeader

            if candidates.isEmpty {
                ContentUnavailableView(
                    "스캔 데이터가 없습니다",
                    systemImage: "chart.line.uptrend.xyaxis",
                    description: Text("snapshot 또는 websocket market 이벤트 수신 후 후보가 표시됩니다.")
                )
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
            syncSelection()
        }
        .onChange(of: candidateCodes) { _ in
            syncSelection()
        }
        .onChange(of: scanMode) { _ in
            syncSelection()
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

            Picker("", selection: $scanMode) {
                ForEach(ScannerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 220)
        }
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
        .padding()
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .appPanelStyle()
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
        .padding()
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .appPanelStyle()
    }

    private func detailPanel(for candidate: ScannerCandidate) -> some View {
        let trend = TrendDirection.from(changePercent: candidate.row.changePct)
        let signal = latestSignal(for: candidate.code)
        let holding = isHolding(code: candidate.code)
        let points = chartPoints(for: candidate)
        let metrics = chartMetrics(from: points, currentPrice: candidate.row.price, changePct: candidate.row.changePct)
        let score = candidate.score
        let scoreTone: StatusTone = score >= 75 ? .success : (score >= 50 ? .warning : .neutral)

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
                    Text(DisplayFormatters.krw(candidate.row.price))
                        .font(.title2.monospacedDigit().weight(.semibold))

                    HStack(spacing: 6) {
                        if trend == .up {
                            Image(systemName: "arrow.up.right")
                        } else if trend == .down {
                            Image(systemName: "arrow.down.right")
                        }
                        Text("\(DisplayFormatters.signedPercent(candidate.row.changePct))")
                        Text("(\(DisplayFormatters.signedNumber(changeValue(for: candidate.row))))")
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
                HStack {
                    Picker("", selection: $chartTimeframe) {
                        ForEach(ChartTimeframe.allCases) { timeframe in
                            Text(timeframe.title).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 260)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().opacity(0.5)

            ScannerLineChartView(points: points, trend: trend)
                .frame(minHeight: 220, maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)

            Divider().opacity(0.5)
            chartSupportInfoRow(metrics: metrics)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
        }
        .appSurfaceStyle()
    }

    private func chartSupportInfoRow(metrics: ScannerChartMetrics) -> some View {
        HStack(spacing: 0) {
            chartSupportInfoItem(title: "시가", value: DisplayFormatters.krw(metrics.open), valueColor: DesignTokens.Colors.textPrimary)
            Divider()
            chartSupportInfoItem(title: "고가", value: DisplayFormatters.krw(metrics.high), valueColor: DesignTokens.Colors.profit.opacity(0.92))
            Divider()
            chartSupportInfoItem(title: "저가", value: DisplayFormatters.krw(metrics.low), valueColor: DesignTokens.Colors.loss.opacity(0.92))
            Divider()
            chartSupportInfoItem(title: "전일종가", value: DisplayFormatters.krw(metrics.prevClose), valueColor: DesignTokens.Colors.textPrimary)
            Divider()
            chartSupportInfoItem(title: "변동성", value: DisplayFormatters.percent(metrics.volatility), valueColor: DesignTokens.Colors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func chartSupportInfoItem(title: String, value: String, valueColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var candidates: [ScannerCandidate] {
        let sortedRows = store.marketRows.sorted { lhs, rhs in
            switch scanMode {
            case .turnover:
                let lMetric = lhs.metric ?? .leastNormalMagnitude
                let rMetric = rhs.metric ?? .leastNormalMagnitude
                if lMetric != rMetric {
                    return lMetric > rMetric
                }
                let lRank = lhs.rank ?? Int.max
                let rRank = rhs.rank ?? Int.max
                if lRank != rRank {
                    return lRank < rRank
                }
                return lhs.code < rhs.code
            case .surge:
                let lChange = lhs.changePct ?? -Double.greatestFiniteMagnitude
                let rChange = rhs.changePct ?? -Double.greatestFiniteMagnitude
                if lChange != rChange {
                    return lChange > rChange
                }
                let lMetric = lhs.metric ?? .leastNormalMagnitude
                let rMetric = rhs.metric ?? .leastNormalMagnitude
                if lMetric != rMetric {
                    return lMetric > rMetric
                }
                return lhs.code < rhs.code
            }
        }

        return sortedRows.enumerated().map { index, row in
            let displayRank = index + 1
            return ScannerCandidate(
                row: row,
                displayRank: displayRank,
                score: score(for: row, index: index, total: sortedRows.count),
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

    private func chartPoints(for candidate: ScannerCandidate) -> [Double] {
        let base = max(candidate.row.price ?? 10_000, 100)
        let count = chartTimeframe.sampleCount
        let drift = (candidate.row.changePct ?? 0) / 100.0
        let seed = Double(candidate.row.code.unicodeScalars.map { Int($0.value) }.reduce(0, +) % 97) / 97.0

        var points: [Double] = []
        points.reserveCapacity(count)

        for index in 0..<count {
            let progress = Double(index) / Double(max(count - 1, 1))
            let waveA = sin((progress * .pi * Double(chartTimeframe.waveCycle)) + (seed * 2.1))
            let waveB = cos((progress * .pi * Double(chartTimeframe.waveCycle * 2)) + (seed * 3.4)) * 0.35
            let trend = base * (drift * progress * 0.35)
            let amplitude = base * (0.0015 + (seed * 0.0012))
            let value = max(1, base + trend + (waveA + waveB) * amplitude)
            points.append(value)
        }

        if !points.isEmpty, let price = candidate.row.price {
            points[points.count - 1] = price
        }
        return points
    }

    private func chartMetrics(from points: [Double], currentPrice: Double?, changePct: Double?) -> ScannerChartMetrics {
        let open = points.first
        let high = points.max()
        let low = points.min()
        let current = currentPrice ?? points.last

        let prevClose: Double?
        if let current, let changePct {
            let denominator = 1.0 + (changePct / 100.0)
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
            let mean = points.reduce(0, +) / Double(points.count)
            let variance = points.reduce(0) { partial, point in
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

    private func changeValue(for row: MarketRow) -> Double? {
        guard let price = row.price, let changePct = row.changePct else { return nil }
        let denominator = 1.0 + (changePct / 100.0)
        guard abs(denominator) > 0.0001 else { return nil }
        let previousClose = price / denominator
        return price - previousClose
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

private enum ChartTimeframe: String, CaseIterable, Identifiable {
    case minute1
    case minute5
    case day
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minute1:
            return "1분"
        case .minute5:
            return "5분"
        case .day:
            return "일"
        case .week:
            return "주"
        }
    }

    var sampleCount: Int {
        switch self {
        case .minute1:
            return 50
        case .minute5:
            return 55
        case .day:
            return 45
        case .week:
            return 40
        }
    }

    var waveCycle: Int {
        switch self {
        case .minute1:
            return 8
        case .minute5:
            return 5
        case .day:
            return 3
        case .week:
            return 2
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

private struct ScannerLineChartView: View {
    let points: [Double]
    let trend: TrendDirection

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let minValue = points.min() ?? 0
            let maxValue = points.max() ?? 0
            let range = max(maxValue - minValue, 0.0001)

            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Colors.surface1)

                Path { path in
                    for index in 1...4 {
                        let y = size.height * CGFloat(Double(index) / 5.0)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(DesignTokens.Colors.borderMedium, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if points.count > 1 {
                    areaPath(size: size, minValue: minValue, range: range)
                        .fill(
                            LinearGradient(
                                colors: [trend.color.opacity(0.3), trend.color.opacity(0.02)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    linePath(size: size, minValue: minValue, range: range)
                        .stroke(trend.color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }

    private func linePath(size: CGSize, minValue: Double, range: Double) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let x = size.width * CGFloat(Double(index) / Double(max(points.count - 1, 1)))
                let yRatio = (point - minValue) / range
                let y = size.height * (1 - CGFloat(yRatio))
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    private func areaPath(size: CGSize, minValue: Double, range: Double) -> Path {
        var path = linePath(size: size, minValue: minValue, range: range)
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
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
