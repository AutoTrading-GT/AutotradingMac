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
}
