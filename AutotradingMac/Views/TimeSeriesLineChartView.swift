//
//  TimeSeriesLineChartView.swift
//  AutotradingMac
//

import SwiftUI

struct TimeSeriesLineChartView: View {
    let points: [ChartPoint]
    let timeframe: ChartTimeframeOption
    let lineColor: Color

    fileprivate enum Layout {
        static let leftAxisWidth: CGFloat = 64
        static let rightPadding: CGFloat = 62
        static let topPadding: CGFloat = 10
        static let bottomAxisHeight: CGFloat = 26
        static let yTickCount: Int = 4
        static let xTickMaxCount: Int = 5
    }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let chart = ChartGeometry(points: points, size: size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(DesignTokens.Colors.surface1)

                if !points.isEmpty {
                    yAxisGrid(chart: chart)
                    xAxis(chart: chart)
                    currentPriceGuide(chart: chart)
                    area(chart: chart)
                    line(chart: chart)
                    lastPointMarker(chart: chart)
                    highLowMarkers(chart: chart)
                    currentPriceLabel(chart: chart)
                }
            }
        }
    }

    @ViewBuilder
    private func yAxisGrid(chart: ChartGeometry) -> some View {
        ForEach(Array(chart.yTickValues.enumerated()), id: \.offset) { index, tickValue in
            let y = chart.yPosition(for: tickValue)
            Path { path in
                path.move(to: CGPoint(x: chart.plotRect.minX, y: y))
                path.addLine(to: CGPoint(x: chart.plotRect.maxX, y: y))
            }
            .stroke(
                DesignTokens.Colors.borderMedium.opacity(index == 0 || index == (chart.yTickValues.count - 1) ? 0.40 : 0.26),
                style: StrokeStyle(lineWidth: 1, dash: [4, 4])
            )

            Text(DisplayFormatters.krw(tickValue))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .frame(width: Layout.leftAxisWidth - 8, alignment: .trailing)
                .position(x: (Layout.leftAxisWidth - 8) / 2, y: y)
        }
    }

    @ViewBuilder
    private func xAxis(chart: ChartGeometry) -> some View {
        Path { path in
            path.move(to: CGPoint(x: chart.plotRect.minX, y: chart.plotRect.maxY))
            path.addLine(to: CGPoint(x: chart.plotRect.maxX, y: chart.plotRect.maxY))
        }
        .stroke(DesignTokens.Colors.borderSubtle.opacity(0.75), lineWidth: 1)

        ForEach(chart.xTickIndices, id: \.self) { index in
            let x = chart.xPosition(for: index)
            let ts = points[index].ts
            Text(timeLabel(for: ts))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .position(x: x, y: chart.plotRect.maxY + 12)
        }
    }

    @ViewBuilder
    private func area(chart: ChartGeometry) -> some View {
        if points.count > 1 {
            chart.areaPath()
                .fill(
                    LinearGradient(
                        colors: [lineColor.opacity(0.24), lineColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
    }

    @ViewBuilder
    private func line(chart: ChartGeometry) -> some View {
        if points.count > 1 {
            chart.linePath()
                .stroke(
                    lineColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
        } else if points.count == 1 {
            let x = chart.xPosition(for: 0)
            let y = chart.yPosition(for: points[0].close)
            Circle()
                .fill(lineColor)
                .frame(width: 6, height: 6)
                .position(x: x, y: y)
        }
    }

    @ViewBuilder
    private func currentPriceGuide(chart: ChartGeometry) -> some View {
        guard let current = points.last?.close else { return }
        let y = chart.yPosition(for: current)
        Path { path in
            path.move(to: CGPoint(x: chart.plotRect.minX, y: y))
            path.addLine(to: CGPoint(x: chart.plotRect.maxX, y: y))
        }
        .stroke(
            lineColor.opacity(0.32),
            style: StrokeStyle(lineWidth: 1, dash: [3, 3])
        )
    }

    @ViewBuilder
    private func lastPointMarker(chart: ChartGeometry) -> some View {
        guard let last = points.last else { return }
        let index = points.count - 1
        let x = chart.xPosition(for: index)
        let y = chart.yPosition(for: last.close)
        Circle()
            .fill(lineColor)
            .frame(width: 6, height: 6)
            .position(x: x, y: y)
    }

    @ViewBuilder
    private func currentPriceLabel(chart: ChartGeometry) -> some View {
        guard let current = points.last?.close else { return }
        let y = chart.yPosition(for: current)
        let clampedY = min(max(y, chart.plotRect.minY + 10), chart.plotRect.maxY - 10)
        Text("현재 \(DisplayFormatters.integer(Int(current.rounded())))")
            .font(.caption2.monospacedDigit().weight(.semibold))
            .foregroundStyle(lineColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(DesignTokens.Colors.surface2.opacity(0.92))
            )
            .overlay(
                Capsule()
                    .stroke(lineColor.opacity(0.35), lineWidth: 1)
            )
            .position(x: chart.plotRect.maxX + 34, y: clampedY)
    }

    @ViewBuilder
    private func highLowMarkers(chart: ChartGeometry) -> some View {
        guard let highIndex = chart.highIndex, let lowIndex = chart.lowIndex else { return }
        let highX = chart.xPosition(for: highIndex)
        let lowX = chart.xPosition(for: lowIndex)
        let highY = chart.yPosition(for: points[highIndex].high)
        let lowY = chart.yPosition(for: points[lowIndex].low)
        let verticalDistance = abs(highY - lowY)
        let highYOffset: CGFloat = verticalDistance < 28 ? -20 : -14
        let lowYOffset: CGFloat = verticalDistance < 28 ? 20 : 14

        marker(
            title: "고 \(DisplayFormatters.integer(Int(points[highIndex].high.rounded())))",
            x: highX,
            y: highY + highYOffset,
            tone: DesignTokens.Colors.profit.opacity(0.92),
            chart: chart
        )
        marker(
            title: "저 \(DisplayFormatters.integer(Int(points[lowIndex].low.rounded())))",
            x: lowX,
            y: lowY + lowYOffset,
            tone: DesignTokens.Colors.loss.opacity(0.92),
            chart: chart
        )
    }

    @ViewBuilder
    private func marker(
        title: String,
        x: CGFloat,
        y: CGFloat,
        tone: Color,
        chart: ChartGeometry
    ) -> some View {
        let clampedX = min(max(x, chart.plotRect.minX + 48), chart.plotRect.maxX - 48)
        let clampedY = min(max(y, chart.plotRect.minY + 10), chart.plotRect.maxY - 10)
        Text(title)
            .font(.caption2.monospacedDigit())
            .foregroundStyle(tone)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignTokens.Colors.surface2.opacity(0.90))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(tone.opacity(0.35), lineWidth: 1)
            )
            .position(x: clampedX, y: clampedY)
    }

    private func timeLabel(for date: Date) -> String {
        switch timeframe {
        case .minute1, .minute5:
            return Self.hmFormatter.string(from: date)
        case .day1:
            return Self.mdFormatter.string(from: date)
        case .week1:
            return Self.weekFormatter.string(from: date)
        }
    }

    private static let hmFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private static let mdFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "MM-dd"
        return formatter
    }()

    private static let weekFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.timeZone = TimeZone(identifier: "Asia/Seoul")
        formatter.dateFormat = "yy-MM"
        return formatter
    }()
}

private struct ChartGeometry {
    let points: [ChartPoint]
    let size: CGSize
    let plotRect: CGRect
    let minValue: Double
    let maxValue: Double
    let valueRange: Double
    let yTickValues: [Double]
    let xTickIndices: [Int]
    let highIndex: Int?
    let lowIndex: Int?

    init(points: [ChartPoint], size: CGSize) {
        self.points = points
        self.size = size
        self.plotRect = CGRect(
            x: TimeSeriesLineChartView.Layout.leftAxisWidth,
            y: TimeSeriesLineChartView.Layout.topPadding,
            width: max(size.width - TimeSeriesLineChartView.Layout.leftAxisWidth - TimeSeriesLineChartView.Layout.rightPadding, 1),
            height: max(size.height - TimeSeriesLineChartView.Layout.bottomAxisHeight - TimeSeriesLineChartView.Layout.topPadding, 1)
        )

        let maxHigh = points.map(\.high).max() ?? 1
        let minLow = points.map(\.low).min() ?? 0
        if maxHigh <= minLow {
            let base = max(maxHigh, 1.0)
            self.minValue = base * 0.995
            self.maxValue = base * 1.005
        } else {
            let pad = (maxHigh - minLow) * 0.04
            self.minValue = minLow - pad
            self.maxValue = maxHigh + pad
        }
        self.valueRange = max(self.maxValue - self.minValue, 0.0001)
        self.yTickValues = Self.makeYTicks(minValue: self.minValue, maxValue: self.maxValue, count: TimeSeriesLineChartView.Layout.yTickCount)
        self.xTickIndices = Self.makeXTickIndices(count: points.count, maxLabels: TimeSeriesLineChartView.Layout.xTickMaxCount)
        self.highIndex = points.indices.max(by: { points[$0].high < points[$1].high })
        self.lowIndex = points.indices.max(by: { points[$0].low > points[$1].low })
    }

    func xPosition(for index: Int) -> CGFloat {
        guard points.count > 1 else { return plotRect.midX }
        let ratio = CGFloat(Double(index) / Double(points.count - 1))
        return plotRect.minX + (plotRect.width * ratio)
    }

    func yPosition(for value: Double) -> CGFloat {
        let ratio = CGFloat((value - minValue) / valueRange)
        return plotRect.maxY - (plotRect.height * ratio)
    }

    func linePath() -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let x = xPosition(for: index)
                let y = yPosition(for: point.close)
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    func areaPath() -> Path {
        var path = linePath()
        path.addLine(to: CGPoint(x: plotRect.maxX, y: plotRect.maxY))
        path.addLine(to: CGPoint(x: plotRect.minX, y: plotRect.maxY))
        path.closeSubpath()
        return path
    }

    private static func makeYTicks(minValue: Double, maxValue: Double, count: Int) -> [Double] {
        guard count > 1 else { return [maxValue] }
        let step = (maxValue - minValue) / Double(count - 1)
        return (0..<count).map { index in
            maxValue - (Double(index) * step)
        }
    }

    private static func makeXTickIndices(count: Int, maxLabels: Int) -> [Int] {
        guard count > 0 else { return [] }
        if count == 1 { return [0] }
        let labelCount = max(2, min(maxLabels, count))
        let interval = Double(count - 1) / Double(labelCount - 1)
        let indices = (0..<labelCount).map { idx in
            Int((Double(idx) * interval).rounded())
        }
        return Array(Set(indices)).sorted()
    }
}
