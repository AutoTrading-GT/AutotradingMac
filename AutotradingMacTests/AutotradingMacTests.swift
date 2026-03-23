//
//  AutotradingMacTests.swift
//  AutotradingMacTests
//
//  Created by 한규탁 on 3/19/26.
//

import XCTest
@testable import AutotradingMac

final class AutotradingMacTests: XCTestCase {
    func test_resultFeedReducer_prefersCloseOverOrderAndFillInSameFlow() {
        let now = Date()
        let candidates: [ResultFeedEventCandidate] = [
            .init(
                id: "order-101",
                timestamp: now.addingTimeInterval(-15),
                kind: .order,
                code: "005930",
                side: "sell",
                status: "filled",
                orderId: 101,
                sourceOrderId: nil
            ),
            .init(
                id: "fill-101",
                timestamp: now.addingTimeInterval(-10),
                kind: .fill,
                code: "005930",
                side: "sell",
                status: nil,
                orderId: 101,
                sourceOrderId: nil
            ),
            .init(
                id: "close-101",
                timestamp: now,
                kind: .close,
                code: "005930",
                side: "sell",
                status: "take_profit",
                orderId: nil,
                sourceOrderId: 101
            ),
        ]

        let visible = ResultFeedReducer.visibleEventIDs(for: candidates)
        XCTAssertTrue(visible.contains("close-101"))
        XCTAssertFalse(visible.contains("order-101"))
        XCTAssertFalse(visible.contains("fill-101"))
    }

    func test_resultFeedReducer_prefersFillWhenCloseMissing() {
        let now = Date()
        let candidates: [ResultFeedEventCandidate] = [
            .init(
                id: "order-202",
                timestamp: now.addingTimeInterval(-12),
                kind: .order,
                code: "000660",
                side: "buy",
                status: "filled",
                orderId: 202,
                sourceOrderId: nil
            ),
            .init(
                id: "fill-202",
                timestamp: now.addingTimeInterval(-8),
                kind: .fill,
                code: "000660",
                side: "buy",
                status: nil,
                orderId: 202,
                sourceOrderId: nil
            ),
        ]

        let visible = ResultFeedReducer.visibleEventIDs(for: candidates)
        XCTAssertTrue(visible.contains("fill-202"))
        XCTAssertFalse(visible.contains("order-202"))
    }

    func test_resultFeedReducer_keepsOrderWhenNoFillAndNoClose() {
        let candidate = ResultFeedEventCandidate(
            id: "order-303",
            timestamp: Date(),
            kind: .order,
            code: "035420",
            side: "buy",
            status: "submitted",
            orderId: 303,
            sourceOrderId: nil
        )

        let visible = ResultFeedReducer.visibleEventIDs(for: [candidate])
        XCTAssertTrue(visible.contains("order-303"))
    }

    func test_actionableSignalFilter_excludesWatchAndIncludesTradeSignals() {
        XCTAssertTrue(ResultFeedReducer.isActionableSignalType("new_entry"))
        XCTAssertTrue(ResultFeedReducer.isActionableSignalType("rank_jump"))
        XCTAssertTrue(ResultFeedReducer.isActionableSignalType("exit_signal"))
        XCTAssertFalse(ResultFeedReducer.isActionableSignalType("rank_maintained"))
        XCTAssertFalse(ResultFeedReducer.isActionableSignalType("watch"))
        XCTAssertFalse(ResultFeedReducer.isActionableSignalType("관망"))
    }

    func test_dashboardSignalSummary_usesLatestMeaningfulStatePerSymbol() {
        let now = Date()
        let rows = DashboardSignalSummaryBuilder.build(
            signals: [
                .init(
                    signalId: 1,
                    code: "005930",
                    symbol: "삼성전자",
                    signalType: "new_entry",
                    confidence: 0.91,
                    orderMode: "paper",
                    executionMode: "paper",
                    sourceSnapshotId: nil,
                    previousSnapshotId: nil,
                    createdAt: now.addingTimeInterval(-30)
                )
            ],
            riskDecisions: [
                .init(
                    riskEventId: 11,
                    code: "005930",
                    symbol: "삼성전자",
                    decision: "approved",
                    blocked: false,
                    reason: "ok",
                    orderMode: "paper",
                    executionMode: "paper",
                    signalId: 1,
                    signalType: "new_entry",
                    relatedSignalReference: "strategy_signal:1",
                    createdAt: now.addingTimeInterval(-20)
                )
            ],
            orders: [
                .init(
                    orderId: 21,
                    code: "005930",
                    symbol: "삼성전자",
                    side: "buy",
                    orderQty: 10,
                    orderPrice: 71200,
                    status: "submitted",
                    orderMode: "paper",
                    executionMode: "paper",
                    sourceSignalReference: "strategy_signal:1",
                    brokerOrderId: nil,
                    createdAt: now.addingTimeInterval(-15),
                    updatedAt: now.addingTimeInterval(-15)
                )
            ],
            fills: [
                .init(
                    fillId: 31,
                    orderId: 21,
                    code: "005930",
                    symbol: "삼성전자",
                    side: "buy",
                    filledQty: 10,
                    filledPrice: 71200,
                    orderMode: "paper",
                    executionMode: "paper",
                    filledAt: now
                )
            ],
            closedPositions: [],
            symbolByCode: ["005930": "삼성전자"]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.name, "삼성전자")
        XCTAssertEqual(rows.first?.action, .buy)
        XCTAssertEqual(rows.first?.status, .executed)
        XCTAssertEqual(rows.first?.summary, "매수 주문 체결 완료")
    }

    func test_dashboardSignalSummary_excludesWatchAndGenericHoldBlocked() {
        let now = Date()
        let rows = DashboardSignalSummaryBuilder.build(
            signals: [
                .init(
                    signalId: 1,
                    code: "000660",
                    symbol: "SK하이닉스",
                    signalType: "rank_maintained",
                    confidence: 0.7,
                    orderMode: "paper",
                    executionMode: "paper",
                    sourceSnapshotId: nil,
                    previousSnapshotId: nil,
                    createdAt: now.addingTimeInterval(-20)
                )
            ],
            riskDecisions: [
                .init(
                    riskEventId: 12,
                    code: "000660",
                    symbol: "SK하이닉스",
                    decision: "blocked",
                    blocked: true,
                    reason: "already_holding_position",
                    orderMode: "paper",
                    executionMode: "paper",
                    signalId: 1,
                    signalType: "rank_maintained",
                    relatedSignalReference: "strategy_signal:1",
                    createdAt: now
                )
            ],
            orders: [],
            fills: [],
            closedPositions: [],
            symbolByCode: ["000660": "SK하이닉스"]
        )

        XCTAssertTrue(rows.isEmpty)
    }

    func test_dashboardSignalSummary_keepsImportantBlockedState() {
        let now = Date()
        let rows = DashboardSignalSummaryBuilder.build(
            signals: [],
            riskDecisions: [
                .init(
                    riskEventId: 13,
                    code: "035420",
                    symbol: "NAVER",
                    decision: "blocked",
                    blocked: true,
                    reason: "daily_trade_limit_reached:3",
                    orderMode: "paper",
                    executionMode: "paper",
                    signalId: 2,
                    signalType: "new_entry",
                    relatedSignalReference: "strategy_signal:2",
                    createdAt: now
                )
            ],
            orders: [],
            fills: [],
            closedPositions: [],
            symbolByCode: ["035420": "NAVER"]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.action, .buy)
        XCTAssertEqual(rows.first?.status, .blocked)
        XCTAssertEqual(rows.first?.summary, "일일 거래 한도 도달")
    }

    func test_dashboardSignalSummary_prefersExecutedOverNearbyPendingInSameFlow() {
        let now = Date()
        let rows = DashboardSignalSummaryBuilder.build(
            signals: [],
            riskDecisions: [
                .init(
                    riskEventId: 14,
                    code: "035720",
                    symbol: "카카오",
                    decision: "approved",
                    blocked: false,
                    reason: "ok",
                    orderMode: "paper",
                    executionMode: "paper",
                    signalId: 3,
                    signalType: "new_entry",
                    relatedSignalReference: "strategy_signal:3",
                    createdAt: now.addingTimeInterval(-20)
                )
            ],
            orders: [
                .init(
                    orderId: 41,
                    code: "035720",
                    symbol: "카카오",
                    side: "buy",
                    orderQty: 5,
                    orderPrice: 52300,
                    status: "submitted",
                    orderMode: "paper",
                    executionMode: "paper",
                    sourceSignalReference: "strategy_signal:3",
                    brokerOrderId: nil,
                    createdAt: now.addingTimeInterval(-5),
                    updatedAt: now.addingTimeInterval(-5)
                )
            ],
            fills: [
                .init(
                    fillId: 51,
                    orderId: 41,
                    code: "035720",
                    symbol: "카카오",
                    side: "buy",
                    filledQty: 5,
                    filledPrice: 52300,
                    orderMode: "paper",
                    executionMode: "paper",
                    filledAt: now.addingTimeInterval(-8)
                )
            ],
            closedPositions: [],
            symbolByCode: ["035720": "카카오"]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.status, .executed)
        XCTAssertEqual(rows.first?.summary, "매수 주문 체결 완료")
    }
}
