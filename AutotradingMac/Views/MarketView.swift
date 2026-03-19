//
//  MarketView.swift
//  AutotradingMac
//

import SwiftUI

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
                HStack(alignment: .top, spacing: 16) {
                    scannerListPane
                        .frame(minWidth: 500, idealWidth: 540, maxWidth: 560, maxHeight: .infinity, alignment: .topLeading)
                    scannerDetailPane
                        .frame(minWidth: 700, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .padding()
        .onAppear {
            syncSelection()
        }
        .onChange(of: candidateCodes) { _ in
            syncSelection()
        }
        .onChange(of: scanMode) { _ in
            syncSelection()
        }
        .frame(minWidth: 1260, minHeight: 760, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var scannerHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer()

            Text("마지막 갱신 \(DisplayFormatters.dateTime(store.lastUpdatedAt))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var scannerListPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("스캔 후보")
                    .font(.headline)
                Spacer()
                Text(scanMode.shortDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $scanMode) {
                ForEach(ScannerMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(minWidth: 420, maxWidth: .infinity)

            VStack(spacing: 0) {
                scannerTableHeader
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))

                ScrollView {
                    LazyVStack(spacing: 6) {
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
                        }
                    }
                    .padding(.top, 6)
                    .padding(.horizontal, 2)
                    .padding(.bottom, 2)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(maxHeight: .infinity)
        }
        .padding()
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var scannerDetailPane: some View {
        Group {
            if let selectedCandidate {
                VStack(alignment: .leading, spacing: 14) {
                    summaryCard(for: selectedCandidate)
                    chartCard(for: selectedCandidate)
                    Spacer(minLength: 0)
                }
            } else {
                ContentUnavailableView(
                    "선택된 종목이 없습니다",
                    systemImage: "cursorarrow.click",
                    description: Text("좌측 후보에서 종목을 선택하면 상세가 표시됩니다.")
                )
            }
        }
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private func summaryCard(for candidate: ScannerCandidate) -> some View {
        let trend = TrendDirection.from(changePercent: candidate.row.changePct)
        let signal = latestSignal(for: candidate.code)
        let holding = isHolding(code: candidate.code)
        let scoreText = "\(candidate.score)점"
        let scoreTone: StatusTone = candidate.score >= 75 ? .success : (candidate.score >= 50 ? .warning : .neutral)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(candidate.displayName)
                        .font(.title3.weight(.semibold))
                    Text(candidate.code)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(DisplayFormatters.krw(candidate.row.price))
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 6) {
                        Text("\(trend.symbol) \(DisplayFormatters.signedPercent(candidate.row.changePct))")
                        Text("(\(DisplayFormatters.signedNumber(changeValue(for: candidate.row))))")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(trend.color)
                }
            }

            HStack(spacing: 8) {
                StatusBadge(text: holding ? "보유 중" : "미보유", tone: holding ? .warning : .neutral)
                if let signal, !signal.isEmpty {
                    StatusBadge(text: "최근 신호 \(signal)", tone: .fromStatus(signal))
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("스캔 점수")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    StatusBadge(text: scoreText, tone: scoreTone)
                }
                ProgressView(value: Double(candidate.score), total: 100)
                    .tint(scoreTone.foreground)
                Text("거래대금/등락률/순위를 100점 기준으로 단순 가중치 환산한 관찰용 점수입니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func chartCard(for candidate: ScannerCandidate) -> some View {
        let points = chartPoints(for: candidate)
        let trend = TrendDirection.from(changePercent: candidate.row.changePct)
        let metrics = chartMetrics(from: points, currentPrice: candidate.row.price, changePct: candidate.row.changePct)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                Picker("", selection: $chartTimeframe) {
                    ForEach(ChartTimeframe.allCases) { timeframe in
                        Text(timeframe.title).tag(timeframe)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
            }

            ScannerLineChartView(points: points, trend: trend)
                .frame(height: 260)

            HStack(spacing: 10) {
                chartMetricCard(title: "시가", value: DisplayFormatters.krw(metrics.open))
                chartMetricCard(title: "고가", value: DisplayFormatters.krw(metrics.high))
                chartMetricCard(title: "저가", value: DisplayFormatters.krw(metrics.low))
                chartMetricCard(title: "전일종가", value: DisplayFormatters.krw(metrics.prevClose))
                chartMetricCard(title: "변동성", value: DisplayFormatters.percent(metrics.volatility))
            }

            Text(candidate.reason)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private func chartMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
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
        HStack(spacing: 4) {
            Text("순위")
                .font(.caption.weight(.semibold))
                .frame(width: 48, alignment: .center)

            Text("종목명")
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("현재가")
                .font(.caption.weight(.semibold))
                .frame(width: 102, alignment: .trailing)

            Text("등락률")
                .font(.caption.weight(.semibold))
                .frame(width: 90, alignment: .trailing)

            Text("거래대금")
                .font(.caption.weight(.semibold))
                .frame(width: 108, alignment: .trailing)
        }
        .foregroundStyle(.secondary)
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

        HStack(spacing: 4) {
            rankBox
                .frame(width: 48, alignment: .center)

            VStack(alignment: .leading, spacing: 2) {
                Text(candidate.displayName)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            Text(DisplayFormatters.krw(candidate.row.price))
                .font(.subheadline.monospacedDigit())
                .frame(width: 102, alignment: .trailing)

            Text("\(trend.symbol) \(DisplayFormatters.signedPercent(candidate.row.changePct))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(trend.color)
                .lineLimit(1)
                .frame(width: 90, alignment: .trailing)

            Text(DisplayFormatters.metricKorean(candidate.row.metric))
                .font(.caption.monospacedDigit())
                .frame(width: 108, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isSelected ? Color.accentColor.opacity(0.20) : Color.black.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor.opacity(0.85) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var rankBox: some View {
        Text("\(candidate.displayRank)")
            .font(.subheadline.monospacedDigit().weight(.bold))
            .frame(width: 34, height: 26)
            .background(rankBackgroundColor, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(rankBorderColor, lineWidth: 1)
            )
    }

    private var rankBackgroundColor: Color {
        switch candidate.displayRank {
        case 1:
            return Color.blue.opacity(0.34)
        case 2:
            return Color.blue.opacity(0.26)
        case 3:
            return Color.blue.opacity(0.18)
        default:
            return Color.black.opacity(0.20)
        }
    }

    private var rankBorderColor: Color {
        switch candidate.displayRank {
        case 1...3:
            return Color.blue.opacity(0.50)
        default:
            return Color.white.opacity(0.14)
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
                    .fill(.black.opacity(0.16))

                Path { path in
                    for index in 1...4 {
                        let y = size.height * CGFloat(Double(index) / 5.0)
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                    }
                }
                .stroke(.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

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
            return .red
        case .down:
            return .blue
        case .flat:
            return .secondary
        case .unknown:
            return .secondary
        }
    }
}
