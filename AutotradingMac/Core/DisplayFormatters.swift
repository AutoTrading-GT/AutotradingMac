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

    private static let krwFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ko_KR")
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₩"
        formatter.maximumFractionDigits = 0
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

    static func krw(_ value: Double?) -> String {
        guard let value else { return "-" }
        return krwFormatter.string(from: NSNumber(value: value)) ?? "-"
    }

    static func signedNumber(_ value: Double?) -> String {
        guard let value else { return "-" }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(number(value))"
    }

    static func signedPercent(_ value: Double?) -> String {
        guard let value else { return "-" }
        let sign = value > 0 ? "+" : ""
        return "\(sign)\(percent(value))"
    }

    static func metricKorean(_ value: Double?) -> String {
        guard let value else { return "-" }
        guard value.isFinite else { return "-" }

        let eokUnit = 100_000_000.0
        let eokPerJo = 10_000
        let absValue = abs(value)
        let sign = value < 0 ? "-" : ""
        let eokValue = absValue / eokUnit

        let roundedEokOneDecimal = (eokValue * 10).rounded() / 10
        if roundedEokOneDecimal >= Double(eokPerJo) {
            let totalEokRounded = Int(eokValue.rounded())
            let jo = totalEokRounded / eokPerJo
            let remainderEok = totalEokRounded % eokPerJo
            return "\(sign)\(jo)조 \(String(format: "%4d", remainderEok))억"
        }

        return "\(sign)\(String(format: "%.1f", roundedEokOneDecimal))억"
    }
}

enum MarketSessionResolver {
    static let intradayClosedTooltip = "휴장 중입니다. 분봉 차트는 마지막 거래일 기준으로 표시됩니다."

    static func shouldShowClosedIntradayHint(
        timeframe: ChartTimeframeOption,
        runtime: RuntimeStatusSnapshot?,
        now: Date = Date()
    ) -> Bool {
        guard timeframe == .minute1 || timeframe == .minute5 else {
            return false
        }
        return !isMarketOpen(runtime: runtime, now: now)
    }

    private static func isMarketOpen(runtime: RuntimeStatusSnapshot?, now: Date) -> Bool {
        if let runtimeValue = runtimeMarketOpen(runtime) {
            return runtimeValue
        }
        return calendarFallbackIsOpen(now: now)
    }

    private static func runtimeMarketOpen(_ runtime: RuntimeStatusSnapshot?) -> Bool? {
        guard let worker = runtime?.workers.workers["market_data"] else {
            return nil
        }

        if let isOpen = worker["is_market_open"]?.boolValue {
            return isOpen
        }

        let rawStatus =
            worker["market_status"]?.stringValue ??
            worker["market_session_status"]?.stringValue ??
            worker["session_status"]?.stringValue ??
            worker["trading_session_status"]?.stringValue

        guard let rawStatus else {
            return nil
        }
        let normalized = rawStatus.lowercased()
        if normalized.contains("open") || normalized.contains("trading") || normalized.contains("장중") {
            return true
        }
        if normalized.contains("close") || normalized.contains("closed") || normalized.contains("휴장") || normalized.contains("마감") {
            return false
        }
        return nil
    }

    private static func calendarFallbackIsOpen(now: Date) -> Bool {
        let seoul = TimeZone(identifier: "Asia/Seoul") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul

        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 {
            return false
        }

        let open = marketDate(hour: 9, minute: 0, base: now, calendar: calendar)
        let close = marketDate(hour: 15, minute: 30, base: now, calendar: calendar)
        return now >= open && now < close
    }

    private static func marketDate(hour: Int, minute: Int, base: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: base)
        return calendar.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: hour,
            minute: minute
        )) ?? base
    }
}
