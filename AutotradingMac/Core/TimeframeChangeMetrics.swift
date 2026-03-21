//
//  TimeframeChangeMetrics.swift
//  AutotradingMac
//

import Foundation

struct TimeframeChangeMetrics {
    let basePrice: Double?
    let currentPrice: Double?
    let changeValue: Double?
    let changePercent: Double?
}

enum TimeframeChangeCalculator {
    static func calculate(
        points: [ChartPoint],
        fallbackCurrentPrice: Double?,
        fallbackChangePercent: Double?
    ) -> TimeframeChangeMetrics {
        if let first = points.first, let last = points.last {
            let base = first.open != 0 ? first.open : first.close
            let current = last.close
            if base != 0 {
                let changeValue = current - base
                let changePercent = (changeValue / base) * 100.0
                return TimeframeChangeMetrics(
                    basePrice: base,
                    currentPrice: current,
                    changeValue: changeValue,
                    changePercent: changePercent
                )
            }
        }

        if
            let current = fallbackCurrentPrice,
            let changePercent = fallbackChangePercent
        {
            let denominator = 1.0 + (changePercent / 100.0)
            if abs(denominator) > 0.0001 {
                let base = current / denominator
                let changeValue = current - base
                return TimeframeChangeMetrics(
                    basePrice: base,
                    currentPrice: current,
                    changeValue: changeValue,
                    changePercent: changePercent
                )
            }
        }

        let current = points.last?.close ?? fallbackCurrentPrice
        return TimeframeChangeMetrics(
            basePrice: nil,
            currentPrice: current,
            changeValue: nil,
            changePercent: nil
        )
    }
}
