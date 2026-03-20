//
//  ChartView.swift
//  AutotradingMac
//

import SwiftUI

struct ChartView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            header

            if let code = selectedCode {
                chartContent(code: code)
            } else {
                ContentUnavailableView(
                    "차트 대상 종목이 없습니다",
                    systemImage: "chart.xyaxis.line",
                    description: Text("Scanner에서 종목을 선택하면 Chart에서도 동일 종목을 표시합니다.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(DesignTokens.Layout.pagePadding)
        .onAppear {
            Task {
                await store.refreshSelectedChartSeries(force: false)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("시계열 차트")
                .font(DesignTokens.Typography.title)

            if !store.marketRows.isEmpty {
                Picker("종목", selection: selectedSymbolBinding) {
                    ForEach(store.marketRows) { row in
                        Text(row.symbol.isEmpty || row.symbol == "-" ? row.code : "\(row.symbol) (\(row.code))")
                            .tag(Optional(row.code))
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 280)
            }

            Spacer()

            Picker("", selection: timeframeBinding) {
                ForEach(ChartTimeframeOption.allCases) { timeframe in
                    Text(timeframe.title).tag(timeframe)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 240)
        }
    }

    @ViewBuilder
    private func chartContent(code: String) -> some View {
        let series = store.chartSeries(for: code, timeframe: store.selectedChartTimeframe)
        let points = series?.points ?? []
        let loading = store.isChartLoading(for: code, timeframe: store.selectedChartTimeframe)
        let errorMessage = store.chartErrorMessage(for: code, timeframe: store.selectedChartTimeframe)
        let trend = trendDirection(points: points)
        let metrics = chartMetrics(points: points)

        VStack(alignment: .leading, spacing: DesignTokens.Layout.sectionGap) {
            HStack {
                Text("\(code) · \(store.selectedChartTimeframe.title)")
                    .font(DesignTokens.Typography.sectionTitle)
                Spacer()
                Text(series?.source ?? "source: -")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }

            ZStack {
                ChartLinePanel(points: points, trend: trend)
                    .frame(minHeight: 360)

                if loading {
                    ProgressView("차트 로딩 중...")
                        .padding(10)
                        .appPanelStyle()
                } else if let errorMessage {
                    ContentUnavailableView(
                        "차트 조회 실패",
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if points.isEmpty {
                    ContentUnavailableView(
                        "차트 데이터 없음",
                        systemImage: "chart.line.uptrend.xyaxis",
                        description: Text("해당 종목/타임프레임에서 조회 가능한 시계열이 없습니다.")
                    )
                }
            }

            chartSupportInfoRow(metrics: metrics)
        }
        .padding(DesignTokens.Layout.panelInnerPadding)
        .appPanelStyle()
        .frame(maxHeight: .infinity, alignment: .topLeading)
    }

    private var selectedCode: String? {
        if let selected = store.selectedScannerCode {
            return selected
        }
        return store.marketRows.first?.code
    }

    private var selectedSymbolBinding: Binding<String?> {
        Binding(
            get: { selectedCode },
            set: { value in
                store.setSelectedScannerCode(value)
            }
        )
    }

    private var timeframeBinding: Binding<ChartTimeframeOption> {
        Binding(
            get: { store.selectedChartTimeframe },
            set: { timeframe in
                store.setSelectedChartTimeframe(timeframe)
            }
        )
    }

    private func trendDirection(points: [ChartPoint]) -> TrendDirection {
        guard points.count >= 2 else { return .unknown }
        let prev = points[points.count - 2].close
        let last = points[points.count - 1].close
        guard prev != 0 else { return .unknown }
        return TrendDirection.from(changePercent: ((last - prev) / prev) * 100.0)
    }

    private func chartMetrics(points: [ChartPoint]) -> ChartMetrics {
        let open = points.first?.open
        let high = points.map(\.high).max()
        let low = points.map(\.low).min()
        let prevClose = points.count >= 2 ? points[points.count - 2].close : nil

        let volatility: Double?
        if points.count > 1 {
            let closes = points.map(\.close)
            let mean = closes.reduce(0, +) / Double(closes.count)
            let variance = closes.reduce(0) { partial, value in
                partial + pow(value - mean, 2.0)
            } / Double(closes.count)
            volatility = mean > 0 ? sqrt(variance) / mean * 100.0 : nil
        } else {
            volatility = nil
        }
        return ChartMetrics(
            open: open,
            high: high,
            low: low,
            prevClose: prevClose,
            volatility: volatility
        )
    }

    private func chartSupportInfoRow(metrics: ChartMetrics) -> some View {
        HStack(spacing: 0) {
            supportInfoItem(title: "시가", value: DisplayFormatters.krw(metrics.open), valueColor: DesignTokens.Colors.textPrimary)
            Divider()
            supportInfoItem(title: "고가", value: DisplayFormatters.krw(metrics.high), valueColor: DesignTokens.Colors.profit.opacity(0.92))
            Divider()
            supportInfoItem(title: "저가", value: DisplayFormatters.krw(metrics.low), valueColor: DesignTokens.Colors.loss.opacity(0.92))
            Divider()
            supportInfoItem(title: "전일종가", value: DisplayFormatters.krw(metrics.prevClose), valueColor: DesignTokens.Colors.textPrimary)
            Divider()
            supportInfoItem(title: "변동성", value: DisplayFormatters.percent(metrics.volatility), valueColor: DesignTokens.Colors.textSecondary)
        }
        .padding(.vertical, 2)
    }

    private func supportInfoItem(title: String, value: String, valueColor: Color) -> some View {
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
}

private struct ChartLinePanel: View {
    let points: [ChartPoint]
    let trend: TrendDirection

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let minValue = points.map(\.close).min() ?? 0
            let maxValue = points.map(\.close).max() ?? 0
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
                let yRatio = (point.close - minValue) / range
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

    var color: Color {
        switch self {
        case .up:
            return DesignTokens.Colors.profit
        case .down:
            return DesignTokens.Colors.loss
        case .flat, .unknown:
            return DesignTokens.Colors.textSecondary
        }
    }
}

#Preview("Chart") {
    ChartView()
        .environmentObject(MonitoringStore())
        .frame(width: 1148, height: 612)
        .background(AppTheme.contentBackground)
}
