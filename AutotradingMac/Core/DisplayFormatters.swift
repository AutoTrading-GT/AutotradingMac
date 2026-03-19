//
//  DisplayFormatters.swift
//  AutotradingMac
//

import Foundation

enum DisplayFormatters {
    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    private static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    private static let percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    static func dateTime(_ value: Date?) -> String {
        guard let value else { return "-" }
        return dateTimeFormatter.string(from: value)
    }

    static func number(_ value: Double?) -> String {
        guard let value else { return "-" }
        return decimalFormatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func integer(_ value: Int?) -> String {
        guard let value else { return "-" }
        return integerFormatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func metric(_ value: Double?) -> String {
        guard let value else { return "-" }
        if abs(value) >= 1_000_000_000 {
            return String(format: "%.2fB", value / 1_000_000_000)
        }
        if abs(value) >= 1_000_000 {
            return String(format: "%.2fM", value / 1_000_000)
        }
        if abs(value) >= 1_000 {
            return String(format: "%.2fK", value / 1_000)
        }
        return number(value)
    }

    static func percent(_ value: Double?) -> String {
        guard let value else { return "-" }
        return percentFormatter.string(from: NSNumber(value: value / 100.0)) ?? "-"
    }

    static func pnl(_ value: Double?) -> String {
        guard let value else { return "-" }
        let sign = value > 0 ? "+" : ""
        let raw = decimalFormatter.string(from: NSNumber(value: value)) ?? "-"
        return "\(sign)\(raw)"
    }
}
