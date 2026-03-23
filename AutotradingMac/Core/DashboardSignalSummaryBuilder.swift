//
//  DashboardSignalSummaryBuilder.swift
//  AutotradingMac
//

import Foundation

enum DashboardSignalAction: String {
    case buy
    case sell

    var label: String {
        switch self {
        case .buy:
            return "매수"
        case .sell:
            return "매도"
        }
    }
}

enum DashboardSignalStatus: String {
    case executed
    case pending
    case monitoring
    case blocked

    var label: String {
        switch self {
        case .executed:
            return "실행됨"
        case .pending:
            return "대기중"
        case .monitoring:
            return "모니터링"
        case .blocked:
            return "차단됨"
        }
    }
}

struct DashboardSignalSummaryRow: Identifiable {
    let code: String
    let name: String
    let summary: String
    let action: DashboardSignalAction
    let status: DashboardSignalStatus
    let timestamp: Date

    var id: String { code }
}

enum DashboardSignalSummaryBuilder {
    private static let flowCoalescingWindow: TimeInterval = 180

    static func build(
        signals: [SignalSnapshotItem],
        riskDecisions: [RiskDecisionSnapshotItem],
        orders: [OrderSnapshotItem],
        fills: [FillSnapshotItem],
        closedPositions: [ClosedPositionSnapshotItem],
        symbolByCode: [String: String],
        limit: Int = 6
    ) -> [DashboardSignalSummaryRow] {
        var candidatesByCode: [String: [Candidate]] = [:]

        func append(_ candidate: Candidate?) {
            guard let candidate else { return }
            candidatesByCode[candidate.code, default: []].append(candidate)
        }

        signals.forEach { row in
            guard ResultFeedReducer.isActionableSignalType(row.signalType) else { return }
            append(
                Candidate(
                    code: row.code,
                    name: instrumentName(symbol: row.symbol, code: row.code, symbolByCode: symbolByCode),
                    summary: signalSummary(signalType: row.signalType),
                    action: action(forSignalType: row.signalType),
                    status: .monitoring,
                    timestamp: row.createdAt,
                    priority: 10
                )
            )
        }

        riskDecisions.forEach { row in
            let decision = normalize(row.decision)
            let signalType = row.signalType ?? ""
            let code = normalizedCode(row.code)
            guard let code else { return }

            if decision == "approved", ResultFeedReducer.isActionableSignalType(signalType) {
                append(
                    Candidate(
                        code: code,
                        name: instrumentName(symbol: row.symbol, code: code, symbolByCode: symbolByCode),
                        summary: approvedSummary(signalType: signalType),
                        action: action(forSignalType: signalType),
                        status: .pending,
                        timestamp: row.createdAt,
                        priority: 20
                    )
                )
                return
            }

            guard decision == "blocked", shouldIncludeBlocked(reason: row.reason, signalType: signalType) else { return }
            append(
                Candidate(
                    code: code,
                    name: instrumentName(symbol: row.symbol, code: code, symbolByCode: symbolByCode),
                    summary: blockedSummary(reason: row.reason),
                    action: action(forSignalType: signalType),
                    status: .blocked,
                    timestamp: row.createdAt,
                    priority: 30
                )
            )
        }

        orders.forEach { row in
            let status = normalize(row.status)
            let name = instrumentName(symbol: row.symbol, code: row.code, symbolByCode: symbolByCode)
            if status == "submitted" || status == "created" || status == "partially_filled" {
                append(
                    Candidate(
                        code: row.code,
                        name: name,
                        summary: orderSummary(status: status),
                        action: action(forSide: row.side),
                        status: .pending,
                        timestamp: row.updatedAt,
                        priority: 40
                    )
                )
            } else if status == "rejected" {
                append(
                    Candidate(
                        code: row.code,
                        name: name,
                        summary: "주문 거부",
                        action: action(forSide: row.side),
                        status: .blocked,
                        timestamp: row.updatedAt,
                        priority: 35
                    )
                )
            }
        }

        fills.forEach { row in
            append(
                Candidate(
                    code: row.code,
                    name: instrumentName(symbol: row.symbol, code: row.code, symbolByCode: symbolByCode),
                    summary: fillSummary(side: row.side),
                    action: action(forSide: row.side),
                    status: .executed,
                    timestamp: row.filledAt,
                    priority: 50
                )
            )
        }

        closedPositions.forEach { row in
            guard let code = normalizedCode(row.code) else { return }
            append(
                Candidate(
                    code: code,
                    name: instrumentName(symbol: row.symbol, code: code, symbolByCode: symbolByCode),
                    summary: closeSummary(reason: row.reason),
                    action: .sell,
                    status: .executed,
                    timestamp: row.createdAt,
                    priority: 60
                )
            )
        }

        return candidatesByCode.values
            .compactMap { candidates in
                candidates.max(by: isLessImportant)
            }
            .sorted(by: { $0.timestamp > $1.timestamp })
            .prefix(limit)
            .map {
                DashboardSignalSummaryRow(
                    code: $0.code,
                    name: $0.name,
                    summary: $0.summary,
                    action: $0.action,
                    status: $0.status,
                    timestamp: $0.timestamp
                )
            }
    }

    static func shouldIncludeBlocked(reason: String, signalType: String?) -> Bool {
        let normalizedReason = normalize(reason)
        let normalizedSignalType = normalize(signalType)

        if normalizedReason.contains("already_holding") || normalizedReason.contains("position_exists") || normalizedReason.contains("block_when_position_exists") {
            return false
        }
        if normalizedReason.contains("cooldown") || normalizedReason.contains("recent") {
            return false
        }
        if normalizedReason.contains("signal_type_not_allowed") {
            return false
        }
        if normalizedSignalType.contains("watch") || normalizedSignalType.contains("maintained") || normalizedSignalType.contains("wait") || normalizedSignalType.contains("관망") {
            return false
        }
        return true
    }

    private static func signalSummary(signalType: String) -> String {
        let normalized = normalize(signalType)
        if normalized.contains("jump") || normalized.contains("break") || normalized.contains("momentum") {
            return "모멘텀 돌파, 거래량 증가"
        }
        if normalized.contains("new_entry") || normalized.contains("entry") {
            return "순위권 진입, 진입 후보"
        }
        if normalized.contains("sell") || normalized.contains("exit") {
            return "청산 신호 감지"
        }
        return "매매 신호 감지"
    }

    private static func approvedSummary(signalType: String) -> String {
        let normalized = normalize(signalType)
        if normalized.contains("sell") || normalized.contains("exit") {
            return "청산 조건 확인, 주문 대기"
        }
        return "진입 조건 확인, 주문 대기"
    }

    private static func blockedSummary(reason: String) -> String {
        let normalized = normalize(reason)
        if normalized.contains("daily_trade_limit_reached") {
            return "일일 거래 한도 도달"
        }
        if normalized.contains("daily_loss_limit_reached") {
            return "일일 손실 한도 도달"
        }
        if normalized.contains("daily_loss_limit_account_value_unavailable") {
            return "계좌 기준값 미확보"
        }
        if normalized.contains("position_size_too_small_for_price") {
            return "주문 가능 수량 부족"
        }
        if normalized.contains("position_size_price_unavailable") {
            return "기준 가격 없음"
        }
        if normalized.contains("position_size_account_value_unavailable") {
            return "계좌 기준값 없음"
        }
        if normalized.contains("max_concurrent") {
            return "동시 보유 한도 초과"
        }
        if normalized.contains("stop_loss") {
            return "손절 보호 규칙"
        }
        if normalized.contains("take_profit") {
            return "익절 보호 규칙"
        }
        return "리스크 제한으로 차단"
    }

    private static func orderSummary(status: String) -> String {
        if status == "partially_filled" {
            return "부분 체결 진행 중"
        }
        return "주문 접수 후 대기"
    }

    private static func fillSummary(side: String) -> String {
        action(forSide: side) == .sell ? "매도 주문 체결 완료" : "매수 주문 체결 완료"
    }

    private static func closeSummary(reason: String?) -> String {
        let normalized = normalize(reason)
        if normalized.contains("take_profit") || normalized.contains("익절") {
            return "목표 수익 도달"
        }
        if normalized.contains("stop_loss") || normalized.contains("손절") {
            return "손절 기준 도달"
        }
        if normalized.contains("market_close") || normalized.contains("장마감") {
            return "장 마감 청산"
        }
        if normalized.contains("max_holding") || normalized.contains("holding") || normalized.contains("time") {
            return "보유 시간 만료"
        }
        return "청산 완료"
    }

    private static func action(forSignalType signalType: String) -> DashboardSignalAction {
        let normalized = normalize(signalType)
        if normalized.contains("sell") || normalized.contains("exit") {
            return .sell
        }
        return .buy
    }

    private static func action(forSide side: String) -> DashboardSignalAction {
        normalize(side) == "sell" ? .sell : .buy
    }

    private static func instrumentName(symbol: String?, code: String, symbolByCode: [String: String]) -> String {
        if let symbol, !symbol.isEmpty {
            return symbol
        }
        if let mapped = symbolByCode[code] {
            return mapped
        }
        return code
    }

    private static func normalizedCode(_ value: String?) -> String? {
        let normalized = normalize(value).uppercased()
        guard !normalized.isEmpty, normalized != "-" else { return nil }
        return normalized
    }

    private static func normalize(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isLessImportant(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.action == rhs.action {
            let delta = abs(lhs.timestamp.timeIntervalSince(rhs.timestamp))
            if delta <= flowCoalescingWindow, lhs.priority != rhs.priority {
                return lhs.priority < rhs.priority
            }
        }

        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp < rhs.timestamp
        }
        return lhs.priority < rhs.priority
    }

    private struct Candidate {
        let code: String
        let name: String
        let summary: String
        let action: DashboardSignalAction
        let status: DashboardSignalStatus
        let timestamp: Date
        let priority: Int
    }
}
