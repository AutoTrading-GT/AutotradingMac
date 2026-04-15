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
    let strategyLabel: String?
    let summary: String
    let action: DashboardSignalAction
    let status: DashboardSignalStatus
    let sellChangePct: Double?
    let timestamp: Date

    var id: String { code }
}

enum DashboardSignalSummaryBuilder {
    private static let flowCoalescingWindow: TimeInterval = 180

    static func build(
        signals: [SignalSnapshotItem],
        exitEvents: [ExitEventSnapshotItem],
        strategyEvents: [StrategyEventSnapshotItem],
        riskDecisions: [RiskDecisionSnapshotItem],
        orders: [OrderSnapshotItem],
        fills: [FillSnapshotItem],
        closedPositions: [ClosedPositionSnapshotItem],
        symbolByCode: [String: String],
        limit: Int = 6
    ) -> [DashboardSignalSummaryRow] {
        var candidatesByCode: [String: [Candidate]] = [:]
        let orderByID = Dictionary(uniqueKeysWithValues: orders.map { ($0.orderId, $0) })
        let latestExitPctByCode = latestSellPctByCode(
            rows: exitEvents,
            code: { $0.code },
            percent: { $0.unrealizedPnlPct }
        )
        let latestClosedPctByCode = latestSellPctByCode(
            rows: closedPositions,
            code: { $0.code },
            percent: { $0.realizedPnlPct }
        )

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
                    strategyLabel: row.strategyDisplayName,
                    summary: row.summary ?? signalSummary(signalType: row.signalType),
                    action: action(forSignalType: row.signalType),
                    status: .monitoring,
                    sellChangePct: sellChangePct(
                        code: row.code,
                        action: action(forSignalType: row.signalType),
                        latestExitPctByCode: latestExitPctByCode,
                        latestClosedPctByCode: latestClosedPctByCode
                    ),
                    timestamp: row.createdAt,
                    priority: 10
                )
            )
        }

        strategyEvents.forEach { row in
            guard let code = normalizedCode(row.code) else { return }
            let signalType = row.signalType ?? row.strategyId ?? ""
            append(
                Candidate(
                    code: code,
                    name: instrumentName(symbol: row.symbol, code: code, symbolByCode: symbolByCode),
                    strategyLabel: row.strategyDisplayName,
                    summary: row.summary ?? blockedSummary(reason: row.reasonCode ?? row.reason),
                    action: action(forSignalType: signalType),
                    status: .blocked,
                    sellChangePct: sellChangePct(
                        code: code,
                        action: action(forSignalType: signalType),
                        latestExitPctByCode: latestExitPctByCode,
                        latestClosedPctByCode: latestClosedPctByCode
                    ),
                    timestamp: row.createdAt,
                    priority: 25
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
                        strategyLabel: row.strategyDisplayName,
                        summary: row.summary ?? approvedSummary(signalType: signalType),
                        action: action(forSignalType: signalType),
                        status: .pending,
                        sellChangePct: sellChangePct(
                            code: code,
                            action: action(forSignalType: signalType),
                            latestExitPctByCode: latestExitPctByCode,
                            latestClosedPctByCode: latestClosedPctByCode
                        ),
                        timestamp: row.createdAt,
                        priority: 20
                    )
                )
                return
            }

            let blockedReason = row.reasonCode ?? row.reason
            guard decision == "blocked", shouldIncludeBlocked(reason: blockedReason, signalType: signalType) else { return }
            append(
                Candidate(
                    code: code,
                    name: instrumentName(symbol: row.symbol, code: code, symbolByCode: symbolByCode),
                    strategyLabel: row.strategyDisplayName,
                    summary: row.summary ?? blockedSummary(reason: blockedReason),
                    action: action(forSignalType: signalType),
                    status: .blocked,
                    sellChangePct: sellChangePct(
                        code: code,
                        action: action(forSignalType: signalType),
                        latestExitPctByCode: latestExitPctByCode,
                        latestClosedPctByCode: latestClosedPctByCode
                    ),
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
                        strategyLabel: row.strategyDisplayName,
                        summary: orderSummary(
                            status: status,
                            side: row.side,
                            executionReason: row.executionReason
                        ),
                        action: action(forSide: row.side),
                        status: .pending,
                        sellChangePct: sellChangePct(
                            code: row.code,
                            action: action(forSide: row.side),
                            latestExitPctByCode: latestExitPctByCode,
                            latestClosedPctByCode: latestClosedPctByCode
                        ),
                        timestamp: row.updatedAt,
                        priority: 40
                    )
                )
            } else if status == "rejected" {
                append(
                    Candidate(
                        code: row.code,
                        name: name,
                        strategyLabel: row.strategyDisplayName,
                        summary: row.executionReason.map { blockedSummary(reason: $0) } ?? "주문 거부",
                        action: action(forSide: row.side),
                        status: .blocked,
                        sellChangePct: sellChangePct(
                            code: row.code,
                            action: action(forSide: row.side),
                            latestExitPctByCode: latestExitPctByCode,
                            latestClosedPctByCode: latestClosedPctByCode
                        ),
                        timestamp: row.updatedAt,
                        priority: 35
                    )
                )
            }
        }

        fills.forEach { row in
            let relatedOrder = orderByID[row.orderId]
            append(
                Candidate(
                    code: row.code,
                    name: instrumentName(symbol: row.symbol, code: row.code, symbolByCode: symbolByCode),
                    strategyLabel: relatedOrder?.strategyDisplayName,
                    summary: fillSummary(side: row.side, executionReason: relatedOrder?.executionReason),
                    action: action(forSide: row.side),
                    status: .executed,
                    sellChangePct: sellChangePct(
                        code: row.code,
                        action: action(forSide: row.side),
                        latestExitPctByCode: latestExitPctByCode,
                        latestClosedPctByCode: latestClosedPctByCode
                    ),
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
                    strategyLabel: row.strategyDisplayName,
                    summary: row.summary ?? closeSummary(reason: row.reasonCode ?? row.reason),
                    action: .sell,
                    status: .executed,
                    sellChangePct: normalizedPnLPercent(row.realizedPnlPct),
                    timestamp: row.createdAt,
                    priority: 60
                )
            )
        }

        return candidatesByCode.values
            .compactMap { candidates in
                candidates.max(by: isLessImportant)
            }
            .sorted(by: isHigherPriorityForDisplay)
            .prefix(limit)
            .map {
                DashboardSignalSummaryRow(
                    code: $0.code,
                    name: $0.name,
                    strategyLabel: $0.strategyLabel,
                    summary: $0.summary,
                    action: $0.action,
                    status: $0.status,
                    sellChangePct: $0.sellChangePct,
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
        if normalizedReason.contains("cooldown") {
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

    private static func blockedSummary(reason: String?) -> String {
        let normalized = normalize(reason)
        if normalized.contains("daily_trade_limit_reached") {
            return "일일 거래 한도 도달"
        }
        if normalized.contains("daily_loss_limit_reached") {
            return "일일 손실 한도 도달"
        }
        if normalized.contains("time_window_outside") {
            return "진입 가능 시간대 밖이라 신호 제외"
        }
        if normalized.contains("open_impulse_not_qualified") {
            return "개장 초 상승 탄력이 기준에 못 미쳐 신호 제외"
        }
        if normalized.contains("pullback_invalid") {
            return "눌림 구조가 기준에 맞지 않아 신호 제외"
        }
        if normalized.contains("reentry_volume_insufficient") {
            return "재진입 거래량 부족으로 신호 제외"
        }
        if normalized.contains("vwap_condition_failed") {
            return "VWAP 조건 미충족으로 신호 제외"
        }
        if normalized.contains("recently_listed_excluded") {
            return "신규상장 초기 종목이라 진입 제외"
        }
        if normalized.contains("short_term_overheated_excluded") {
            return "단기과열 종목이라 진입 제외"
        }
        if normalized.contains("market_warning_excluded") {
            return "시장경보 종목이라 진입 제외"
        }
        if normalized.contains("recent_vi_excluded") {
            return "최근 VI 발동 종목이라 진입 제외"
        }
        if normalized.contains("spread_too_wide") {
            return "스프레드가 넓어 진입 제외"
        }
        if normalized.contains("orderbook_depth_insufficient") {
            return "호가잔량 부족으로 진입 제외"
        }
        if normalized.contains("orderbook_imbalance_exceeded") {
            return "호가 불균형이 커서 진입 제외"
        }
        if normalized.contains("spread_data_unavailable") {
            return "스프레드 데이터 미확보"
        }
        if normalized.contains("orderbook_data_unavailable") {
            return "호가 데이터 미확보"
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
        if normalized.contains("max_open_positions") {
            return "동시 보유 한도 초과"
        }
        if normalized.contains("max_entry_attempts_in_window") || normalized.contains("concurrent_candidate_limit") {
            return "최근 진입 시도 한도 초과"
        }
        if normalized.contains("stop_loss") {
            return "손절 보호 규칙"
        }
        if normalized.contains("take_profit") {
            return "익절 보호 규칙"
        }
        return "리스크 제한으로 차단"
    }

    private static func orderSummary(status: String, side: String, executionReason: String?) -> String {
        let sideAction = action(forSide: side)
        if sideAction == .sell, let executionReason, !executionReason.isEmpty {
            let executionSummary = closeSummary(reason: executionReason)
            if status == "partially_filled" {
                return "\(executionSummary) 진행 중"
            }
            if status == "submitted" || status == "created" {
                return "\(executionSummary) 주문 대기"
            }
            return executionSummary
        }
        if status == "partially_filled" {
            return "부분 체결 진행 중"
        }
        return "주문 접수 후 대기"
    }

    private static func fillSummary(side: String, executionReason: String?) -> String {
        if action(forSide: side) == .sell, let executionReason, !executionReason.isEmpty {
            return closeSummary(reason: executionReason)
        }
        return action(forSide: side) == .sell ? "매도 주문 체결 완료" : "매수 주문 체결 완료"
    }

    private static func closeSummary(reason: String?) -> String {
        let normalized = normalize(reason)
        if normalized.contains("first_take_profit_partial") {
            return "1차 익절 분할청산"
        }
        if normalized.contains("initial_stop") {
            return "초기 손절 청산"
        }
        if normalized.contains("hard_time_stop") {
            return "하드 시간청산"
        }
        if normalized.contains("soft_time_stop") {
            return "소프트 시간청산"
        }
        if normalized.contains("market_close_exit") {
            return "장마감 강제청산"
        }
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

    private static func normalizedPnLPercent(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        if abs(value) <= 1.5 {
            return value * 100.0
        }
        return value
    }

    private static func sellChangePct(
        code: String,
        action: DashboardSignalAction,
        latestExitPctByCode: [String: Double],
        latestClosedPctByCode: [String: Double]
    ) -> Double? {
        guard action == .sell else { return nil }
        let normalizedCode = normalizedCode(code)
        guard let normalizedCode else { return nil }
        return latestClosedPctByCode[normalizedCode] ?? latestExitPctByCode[normalizedCode]
    }

    private static func latestSellPctByCode<Row>(
        rows: [Row],
        code: (Row) -> String?,
        percent: (Row) -> Double?
    ) -> [String: Double] {
        var result: [String: Double] = [:]
        for row in rows {
            guard
                let normalizedCode = normalizedCode(code(row)),
                result[normalizedCode] == nil,
                let normalizedPct = normalizedPnLPercent(percent(row))
            else { continue }
            result[normalizedCode] = normalizedPct
        }
        return result
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

    private static func isHigherPriorityForDisplay(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp
        }
        if lhs.priority != rhs.priority {
            return lhs.priority > rhs.priority
        }
        if lhs.action != rhs.action {
            return lhs.action.rawValue < rhs.action.rawValue
        }
        if lhs.code != rhs.code {
            return lhs.code < rhs.code
        }
        return lhs.summary < rhs.summary
    }

    private struct Candidate {
        let code: String
        let name: String
        let strategyLabel: String?
        let summary: String
        let action: DashboardSignalAction
        let status: DashboardSignalStatus
        let sellChangePct: Double?
        let timestamp: Date
        let priority: Int
    }
}
