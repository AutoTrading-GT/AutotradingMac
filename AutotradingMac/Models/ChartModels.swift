//
//  ChartModels.swift
//  AutotradingMac
//

import Foundation

enum ChartTimeframeOption: String, CaseIterable, Identifiable, Codable {
    case minute1 = "1m"
    case minute5 = "5m"
    case day1 = "1d"
    case week1 = "1w"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .minute1:
            return "1분"
        case .minute5:
            return "5분"
        case .day1:
            return "일"
        case .week1:
            return "주"
        }
    }
}

struct ChartSeriesResponse: Decodable {
    let symbol: String
    let timeframe: ChartTimeframeOption
    let source: String
    let timezone: String
    let points: [ChartPoint]
}

struct ChartPoint: Decodable, Identifiable {
    var id: String { "\(ts.timeIntervalSince1970)-\(close)" }

    let ts: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let volume: Double?
}

struct ChartMetrics {
    let open: Double?
    let high: Double?
    let low: Double?
    let prevClose: Double?
    let volatility: Double?
}

