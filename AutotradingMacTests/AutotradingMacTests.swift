//
//  AutotradingMacTests.swift
//  AutotradingMacTests
//
//  Created by 한규탁 on 3/19/26.
//

import XCTest
@testable import AutotradingMac

final class AutotradingMacTests: XCTestCase {
    func test_strategySettingsSnapshot_buildsFallbackMultiStrategyCatalogFromLegacyInit() {
        let snapshot = Self.makeStrategySettingsSnapshot()

        XCTAssertEqual(snapshot.activeStrategyId, "turnover_surge_momentum")
        XCTAssertEqual(
            snapshot.strategyTemplates.map(\.strategyId),
            ["turnover_surge_momentum", "opening_pullback_reentry", "intraday_breakout"]
        )
        XCTAssertEqual(snapshot.template(id: "turnover_surge_momentum")?.status, "active")
        XCTAssertEqual(snapshot.template(id: "opening_pullback_reentry")?.status, "available")
        XCTAssertEqual(snapshot.template(id: "intraday_breakout")?.status, "preview_only")
        XCTAssertEqual(
            snapshot.strategyParams["turnover_surge_momentum"]?["selection_mode"]?.stringValue,
            "turnover"
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["candidate_end_time"]?.stringValue,
            "09:20"
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["exclude_recently_listed_days"]?.intValue,
            5
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["recent_vi_lookback_minutes"]?.intValue,
            15
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["max_spread_pct"]?.doubleValue,
            0.30,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["min_best_bid_size"]?.intValue,
            300
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["max_orderbook_imbalance_ratio"]?.doubleValue,
            3.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["risk_per_trade_pct"]?.doubleValue,
            0.30,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["max_position_size_pct_cap"]?.doubleValue,
            7.0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            snapshot.strategyParams["opening_pullback_reentry"]?["sizing_slippage_buffer_pct"]?.doubleValue,
            0.20,
            accuracy: 0.0001
        )
        XCTAssertEqual(snapshot.commonRiskParams["position_size_pct"]?.doubleValue, 10.0)
        XCTAssertTrue(snapshot.commonRiskParams["allowed_signal_types"]?.arrayStringValues?.contains("opening_pullback_reentry") ?? false)
    }

    @MainActor
    func test_monitoringStore_allowsOpeningPullbackStrategyActivation() async {
        let snapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(strategyEnvelope: envelope),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadStrategySettings()
        store.updateStrategyActiveTemplate("opening_pullback_reentry")

        XCTAssertEqual(store.strategyDraft?.activeStrategyId, "opening_pullback_reentry")
        XCTAssertEqual(store.strategyDraft?.template(id: "opening_pullback_reentry")?.status, "active")
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["time_stop_hard_minutes"]?.intValue,
            30
        )
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["exclude_recently_listed_enabled"]?.boolValue,
            true
        )
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["risk_per_trade_pct"]?.doubleValue,
            0.30,
            accuracy: 0.0001
        )
        XCTAssertTrue(
            store.strategyDraft?.commonRiskParams["allowed_signal_types"]?.arrayStringValues?.contains("opening_pullback_reentry") ?? false
        )
        XCTAssertEqual(store.strategyDraft?.basic.exit.stopLossPct ?? 0, 1.0, accuracy: 0.0001)
        XCTAssertNil(store.lastStrategySettingsErrorMessage)
    }

    @MainActor
    func test_monitoringStore_updatesOpeningPullbackParamsAfterActivation() async {
        let snapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(strategyEnvelope: envelope),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadStrategySettings()
        store.updateStrategyActiveTemplate("opening_pullback_reentry")
        store.updateActiveStrategyParamString("candidate_end_time", value: "09:18")
        store.updateActiveStrategyParamBool("exclude_recent_vi_enabled", value: false)
        store.updateActiveStrategyParamDouble("risk_per_trade_pct", value: 0.42, range: 0.01...10)

        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["candidate_end_time"]?.stringValue,
            "09:18"
        )
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["exclude_recent_vi_enabled"]?.boolValue,
            false
        )
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["risk_per_trade_pct"]?.doubleValue,
            0.42,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["candidate_start_time"]?.stringValue,
            "09:03"
        )
    }

    @MainActor
    func test_monitoringStore_keepsSharedDraftValuesCurrentAcrossStrategyPanels() async {
        let snapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(strategyEnvelope: envelope),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadStrategySettings()
        store.updateStrategyBasicTopN(7)
        store.updateStrategyBasicDailyTradeLimitEnabled(true)
        store.updateStrategyBasicDailyTradeLimitCount(6)
        store.updateStrategyBasicForceCloseOnMarketClose(true)
        store.updateStrategyScannerMinTurnover(250_000_000)
        store.updateStrategyScannerMinChangePct(3.4)
        store.updateStrategyRankJumpThreshold(5)
        store.updateStrategySignalWindowMinutes(14)
        store.updateStrategyConcurrencyWindowMinutes(21)

        XCTAssertEqual(store.strategyDraft?.basic.entry.topN, 7)
        XCTAssertEqual(store.strategyDraft?.scanner.topN, 7)
        XCTAssertEqual(store.strategyDraft?.signal.topN, 7)
        XCTAssertEqual(store.strategyDraft?.basic.risk.dailyTradeLimitEnabled, true)
        XCTAssertEqual(store.strategyDraft?.basic.risk.dailyTradeLimitCount, 6)
        XCTAssertEqual(store.strategyDraft?.basic.exit.forceCloseOnMarketClose, true)
        XCTAssertEqual(store.strategyDraft?.scanner.minTurnover, 250_000_000, accuracy: 0.0001)
        XCTAssertEqual(store.strategyDraft?.scanner.minChangePct, 3.4, accuracy: 0.0001)
        XCTAssertEqual(store.strategyDraft?.signal.rankJumpThreshold, 5)
        XCTAssertEqual(store.strategyDraft?.risk.signalWindowMinutes, 14)
        XCTAssertEqual(store.strategyDraft?.risk.concurrencyWindowMinutes, 21)
    }

    @MainActor
    func test_monitoringStore_preservesStrategySpecificAndSharedDraftAfterTemplateSwitch() async {
        let snapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(strategyEnvelope: envelope),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadStrategySettings()
        store.updateStrategyBasicPositionSizePct(12.5)
        store.updateStrategyBasicDailyTradeLimitCount(8)
        store.updateStrategyActiveTemplate("opening_pullback_reentry")
        store.updateActiveStrategyParamString("candidate_end_time", value: "09:17")
        store.updateActiveStrategyParamBool("exclude_recent_vi_enabled", value: false)
        store.updateStrategyActiveTemplate("turnover_surge_momentum")

        XCTAssertEqual(store.strategyDraft?.activeStrategyId, "turnover_surge_momentum")
        XCTAssertEqual(store.strategyDraft?.basic.risk.positionSizePct ?? 0, 12.5, accuracy: 0.0001)
        XCTAssertEqual(store.strategyDraft?.basic.risk.dailyTradeLimitCount, 8)
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["candidate_end_time"]?.stringValue,
            "09:17"
        )
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["exclude_recent_vi_enabled"]?.boolValue,
            false
        )
    }

    @MainActor
    func test_monitoringStore_preservesOpeningDraftAcrossStrategyReload() async {
        let snapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(strategyEnvelope: envelope),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadStrategySettings()
        store.updateStrategyActiveTemplate("opening_pullback_reentry")
        store.updateActiveStrategyParamString("candidate_end_time", value: "09:16")
        XCTAssertTrue(store.strategyDirty)

        await store.reloadStrategySettings()

        XCTAssertEqual(store.strategyDraft?.activeStrategyId, "opening_pullback_reentry")
        XCTAssertEqual(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?["candidate_end_time"]?.stringValue,
            "09:16"
        )
        XCTAssertFalse(
            store.strategyDraft?.strategyParams["opening_pullback_reentry"]?.isEmpty ?? true
        )
    }

    @MainActor
    func test_monitoringStore_rejectsPreviewOnlyStrategyActivation() async {
        let snapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: snapshot,
            defaults: snapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(strategyEnvelope: envelope),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadStrategySettings()
        XCTAssertEqual(store.strategyDraft?.activeStrategyId, "turnover_surge_momentum")
        XCTAssertEqual(store.strategyDraft?.template(id: "intraday_breakout")?.status, "preview_only")

        store.updateStrategyActiveTemplate("intraday_breakout")

        XCTAssertEqual(store.strategyDraft?.activeStrategyId, "turnover_surge_momentum")
        XCTAssertEqual(store.strategyDraft?.template(id: "intraday_breakout")?.status, "preview_only")
        XCTAssertTrue(store.lastStrategySettingsErrorMessage?.contains("프리뷰") ?? false)
    }

    @MainActor
    func test_monitoringStore_ignoresLocalPositionEventsWhenAccountModeIsLive() async throws {
        let strategySnapshot = Self.makeStrategySettingsSnapshot()
        let envelope = StrategySettingsResponseEnvelope(
            data: strategySnapshot,
            defaults: strategySnapshot,
            applyPolicy: "저장된 값은 엔진 재시작 없이 다음 평가 사이클부터 반영됩니다.",
            updatedAt: Date()
        )
        let snapshot = try Self.makeMonitoringSnapshotResponse(
            orderMode: "live",
            accountMode: "live",
            currentPositions: []
        )
        let store = MonitoringStore(
            apiClient: MockMonitoringAPIClient(
                strategyEnvelope: envelope,
                snapshot: snapshot,
                runtimeSnapshot: snapshot.runtime
            ),
            webSocketClient: MonitoringWebSocketClient(url: URL(string: "ws://127.0.0.1/ws/events")!),
            localNotificationService: MockLocalNotificationService()
        )

        await store.reloadSnapshot()
        XCTAssertEqual(store.runtime?.accountMode, "live")
        XCTAssertTrue(store.currentPositions.isEmpty)

        store.handleEventForTesting(
            EventEnvelope(
                type: "position.updated",
                ts: Date(),
                source: "execution-worker",
                data: [
                    "timestamp": .string("2026-03-25T06:00:00Z"),
                    "code": .string("Q530036"),
                    "symbol": .string("삼성 인버스 2X WTI원유 선물 ETN"),
                    "side": .string("long"),
                    "qty": .number(1),
                    "avg_price": .number(10000)
                ]
            )
        )

        XCTAssertTrue(store.currentPositions.isEmpty)
    }

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
                sourceOrderId: nil,
                sourceSignalReference: "exit_signal:position:1:first_take_profit"
            ),
            .init(
                id: "fill-101",
                timestamp: now.addingTimeInterval(-10),
                kind: .fill,
                code: "005930",
                side: "sell",
                status: nil,
                orderId: 101,
                sourceOrderId: nil,
                sourceSignalReference: nil
            ),
            .init(
                id: "close-101",
                timestamp: now,
                kind: .close,
                code: "005930",
                side: "sell",
                status: "take_profit",
                orderId: nil,
                sourceOrderId: 101,
                sourceSignalReference: "exit_signal:position:1:first_take_profit"
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
                sourceOrderId: nil,
                sourceSignalReference: "strategy_signal:entry-202"
            ),
            .init(
                id: "fill-202",
                timestamp: now.addingTimeInterval(-8),
                kind: .fill,
                code: "000660",
                side: "buy",
                status: nil,
                orderId: 202,
                sourceOrderId: nil,
                sourceSignalReference: nil
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
            sourceOrderId: nil,
            sourceSignalReference: "strategy_signal:entry-303"
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

    func test_resultFeedReducer_keepsExitDecisionAndHidesRelatedSellOrderAndFill() {
        let now = Date()
        let candidates: [ResultFeedEventCandidate] = [
            .init(
                id: "exit-501",
                timestamp: now,
                kind: .exit,
                code: "005930",
                side: "sell",
                status: "first_take_profit_partial",
                orderId: nil,
                sourceOrderId: nil,
                sourceSignalReference: "exit_signal:position:5:first_take_profit"
            ),
            .init(
                id: "order-501",
                timestamp: now.addingTimeInterval(5),
                kind: .order,
                code: "005930",
                side: "sell",
                status: "filled",
                orderId: 501,
                sourceOrderId: nil,
                sourceSignalReference: "exit_signal:position:5:first_take_profit"
            ),
            .init(
                id: "fill-501",
                timestamp: now.addingTimeInterval(8),
                kind: .fill,
                code: "005930",
                side: "sell",
                status: nil,
                orderId: 501,
                sourceOrderId: nil,
                sourceSignalReference: nil
            ),
        ]

        let visible = ResultFeedReducer.visibleEventIDs(for: candidates)
        XCTAssertTrue(visible.contains("exit-501"))
        XCTAssertFalse(visible.contains("order-501"))
        XCTAssertFalse(visible.contains("fill-501"))
    }

    func test_monitoringSnapshotResponse_decodesRecentExitEvents() throws {
        let json = """
        {
          "runtime": {
            "timestamp": "2026-03-24T10:00:00Z",
            "app_name": "autotrading-core",
            "app_version": "0.1.0",
            "env": "dev",
            "app_status": "ready",
            "order_mode": "paper",
            "account_mode": "paper",
            "database_status": "connected",
            "database_connected": true,
            "readiness_status": "ready",
            "startup_ok": true,
            "startup_status": "ok",
            "active_ws_clients": 1,
            "workers": {
              "summary": {
                "count": 4,
                "running": 4,
                "error": 0,
                "stopping": 0,
                "starting": 0,
                "stopped": 0
              },
              "workers": {}
            }
          },
          "market_top_ranks": [],
          "recent_signals": [],
          "recent_strategy_events": [],
          "recent_exit_events": [
            {
              "event_id": 901,
              "event_type": "signal.exit_generated",
              "position_id": 17,
              "code": "005930",
              "symbol": "삼성전자",
              "signal_type": "exit",
              "source_signal_type": "opening_pullback_reentry",
              "reason": "first_take_profit",
              "reason_code": "first_take_profit_partial",
              "summary": "1차 부분익절 조건 충족",
              "strategy_id": "opening_pullback_reentry",
              "strategy_display_name": "Opening Pullback Re-entry",
              "partial": true,
              "partial_ratio": 0.4,
              "qty": 4.0,
              "current_position_qty": 10.0,
              "expected_remaining_qty": 6.0,
              "source_signal_reference": "exit_signal:position:17:first_take_profit",
              "triggered_at": "2026-03-24T10:00:00Z",
              "order_mode": "paper",
              "execution_mode": "paper",
              "created_at": "2026-03-24T10:00:01Z"
            }
          ],
          "recent_risk_decisions": [],
          "recent_orders": [],
          "recent_fills": [],
          "current_positions": [],
          "recent_closed_positions": [],
          "pnl_summary": {
            "open_positions": 0,
            "unrealized_pnl_total": null,
            "realized_pnl_recent_total": null,
            "recent_closed_count": 0
          },
          "limits": {
            "recent_exit_events": 20
          }
        }
        """

        let snapshot = try MonitoringCoding.decoder().decode(
            MonitoringSnapshotResponse.self,
            from: Data(json.utf8)
        )

        XCTAssertEqual(snapshot.recentExitEvents.count, 1)
        XCTAssertEqual(snapshot.recentExitEvents.first?.reasonCode, "first_take_profit_partial")
        XCTAssertEqual(snapshot.recentExitEvents.first?.strategyId, "opening_pullback_reentry")
        XCTAssertEqual(snapshot.recentExitEvents.first?.partialRatio, 0.4, accuracy: 0.0001)
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
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
                    summary: "상위 순위권 신규 진입 조건 충족",
                    confidence: 0.91,
                    selectionMode: "turnover",
                    rankCurrent: nil,
                    rankPrevious: nil,
                    payload: nil,
                    orderMode: "paper",
                    executionMode: "paper",
                    sourceSnapshotId: nil,
                    previousSnapshotId: nil,
                    createdAt: now.addingTimeInterval(-30)
                )
            ],
            strategyEvents: [],
            riskDecisions: [
                .init(
                    riskEventId: 11,
                    code: "005930",
                    symbol: "삼성전자",
                    decision: "approved",
                    blocked: false,
                    reason: "ok",
                    reasonCode: "risk_checks_passed",
                    summary: "리스크 검사를 통과해 주문 대기",
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
                    context: nil,
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
                    executionReason: "new_entry",
                    signalType: "new_entry",
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
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
        XCTAssertEqual(rows.first?.strategyLabel, "Turnover / Surge Momentum")
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
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
                    summary: nil,
                    confidence: 0.7,
                    selectionMode: nil,
                    rankCurrent: nil,
                    rankPrevious: nil,
                    payload: nil,
                    orderMode: "paper",
                    executionMode: "paper",
                    sourceSnapshotId: nil,
                    previousSnapshotId: nil,
                    createdAt: now.addingTimeInterval(-20)
                )
            ],
            strategyEvents: [],
            riskDecisions: [
                .init(
                    riskEventId: 12,
                    code: "000660",
                    symbol: "SK하이닉스",
                    decision: "blocked",
                    blocked: true,
                    reason: "already_holding_position",
                    reasonCode: "block_when_position_exists",
                    summary: "보유 중 종목이라 추가 진입 차단",
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
                    context: nil,
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
            strategyEvents: [],
            riskDecisions: [
                .init(
                    riskEventId: 13,
                    code: "035420",
                    symbol: "NAVER",
                    decision: "blocked",
                    blocked: true,
                    reason: "daily_trade_limit_reached:3",
                    reasonCode: "daily_trade_limit_reached",
                    summary: "일일 거래 한도 도달로 진입 차단",
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
                    context: nil,
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
            strategyEvents: [],
            riskDecisions: [
                .init(
                    riskEventId: 14,
                    code: "035720",
                    symbol: "카카오",
                    decision: "approved",
                    blocked: false,
                    reason: "ok",
                    reasonCode: "risk_checks_passed",
                    summary: "리스크 검사를 통과해 주문 대기",
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
                    context: nil,
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
                    executionReason: "new_entry",
                    signalType: "new_entry",
                    strategyId: "turnover_surge_momentum",
                    strategyDisplayName: "Turnover / Surge Momentum",
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

    func test_dashboardSignalSummary_includesOpeningStrategyFilteredEvent() {
        let now = Date()
        let rows = DashboardSignalSummaryBuilder.build(
            signals: [],
            strategyEvents: [
                .init(
                    eventId: 21,
                    eventType: "strategy.signal_filtered",
                    code: "005930",
                    symbol: "삼성전자",
                    strategyId: "opening_pullback_reentry",
                    strategyDisplayName: "Opening Pullback Re-entry",
                    signalType: "opening_pullback_reentry",
                    stage: "signal",
                    reason: "recent_vi_excluded",
                    reasonCode: "recent_vi_excluded",
                    summary: "최근 VI 발동 종목이라 진입 제외",
                    selectionMode: "turnover",
                    rankCurrent: 2,
                    sourceSnapshotId: 10,
                    candidateMetric: 1_500_000_000,
                    details: nil,
                    orderMode: "paper",
                    executionMode: "paper",
                    createdAt: now
                )
            ],
            riskDecisions: [],
            orders: [],
            fills: [],
            closedPositions: [],
            symbolByCode: ["005930": "삼성전자"]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.status, .blocked)
        XCTAssertEqual(rows.first?.summary, "최근 VI 발동 종목이라 진입 제외")
        XCTAssertEqual(rows.first?.strategyLabel, "Opening Pullback Re-entry")
    }

    func test_dashboardSignalSummary_mapsSpreadBlockReason() {
        let now = Date()
        let rows = DashboardSignalSummaryBuilder.build(
            signals: [],
            strategyEvents: [
                .init(
                    eventId: 22,
                    eventType: "strategy.signal_filtered",
                    code: "005930",
                    symbol: "삼성전자",
                    strategyId: "opening_pullback_reentry",
                    strategyDisplayName: "Opening Pullback Re-entry",
                    signalType: "opening_pullback_reentry",
                    stage: "signal",
                    reason: "spread_too_wide",
                    reasonCode: "spread_too_wide",
                    summary: nil,
                    selectionMode: "turnover",
                    rankCurrent: 2,
                    sourceSnapshotId: 10,
                    candidateMetric: 1_500_000_000,
                    details: nil,
                    orderMode: "paper",
                    executionMode: "paper",
                    createdAt: now
                )
            ],
            riskDecisions: [],
            orders: [],
            fills: [],
            closedPositions: [],
            symbolByCode: ["005930": "삼성전자"]
        )

        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows.first?.status, .blocked)
        XCTAssertEqual(rows.first?.summary, "스프레드가 넓어 진입 제외")
    }

    func test_connectionStatusResolver_reportsConnectedWhenRuntimeAndWebSocketAreHealthy() {
        let status = AppConnectionStatusResolver.resolve(
            isBackendConfigured: true,
            snapshotLoaded: true,
            isLoadingSnapshot: false,
            connectionState: .connected,
            runtime: RuntimeStatusSnapshot(
                timestamp: Date(),
                appName: "autotrading-core",
                appVersion: "1.0",
                env: "dev",
                appStatus: "ready",
                orderMode: "paper",
                accountMode: "paper",
                marketTradingActive: true,
                marketClosedIdle: false,
                strategyRunState: "running",
                riskRunState: "running",
                executionMode: "paper",
                engineState: "running",
                engineAvailableActions: [],
                engineTransitioningAction: nil,
                engineLastAction: nil,
                engineLastError: nil,
                engineMessage: nil,
                engineEmergencyLatched: false,
                engineUpdatedAt: nil,
                databaseStatus: "up",
                databaseConnected: true,
                readinessStatus: "ready",
                startupOk: true,
                startupStatus: "ready",
                startupError: nil,
                activeWsClients: 1,
                accountSummary: nil,
                workers: .fallback
            ),
            lastErrorMessage: nil
        )

        XCTAssertEqual(status.kind, .connected)
        XCTAssertEqual(status.compactText, "정상 연결")
    }

    func test_connectionStatusResolver_reportsServerUnavailableForBadBaseURL() {
        let status = AppConnectionStatusResolver.resolve(
            isBackendConfigured: true,
            snapshotLoaded: false,
            isLoadingSnapshot: false,
            connectionState: .disconnected,
            runtime: nil,
            lastErrorMessage: "Snapshot load failed: Could not connect to the server."
        )

        XCTAssertEqual(status.kind, .serverUnavailable)
        XCTAssertEqual(status.title, "서버 연결 실패")
    }

    func test_connectionStatusResolver_reportsReconnectingWhenSnapshotExistsButWSIsRetrying() {
        let status = AppConnectionStatusResolver.resolve(
            isBackendConfigured: true,
            snapshotLoaded: true,
            isLoadingSnapshot: false,
            connectionState: .reconnecting,
            runtime: RuntimeStatusSnapshot(
                timestamp: Date(),
                appName: "autotrading-core",
                appVersion: "1.0",
                env: "dev",
                appStatus: "ready",
                orderMode: "paper",
                accountMode: "paper",
                marketTradingActive: true,
                marketClosedIdle: false,
                strategyRunState: "running",
                riskRunState: "running",
                executionMode: "paper",
                engineState: "running",
                engineAvailableActions: [],
                engineTransitioningAction: nil,
                engineLastAction: nil,
                engineLastError: nil,
                engineMessage: nil,
                engineEmergencyLatched: false,
                engineUpdatedAt: nil,
                databaseStatus: "up",
                databaseConnected: true,
                readinessStatus: "ready",
                startupOk: true,
                startupStatus: "ready",
                startupError: nil,
                activeWsClients: 1,
                accountSummary: nil,
                workers: .fallback
            ),
            lastErrorMessage: "WebSocket receive failed: network connection lost"
        )

        XCTAssertEqual(status.kind, .reconnecting)
        XCTAssertEqual(status.compactText, "재연결 중")
    }

    func test_connectionStatusResolver_reportsAuthenticationFailure() {
        let status = AppConnectionStatusResolver.resolve(
            isBackendConfigured: true,
            snapshotLoaded: true,
            isLoadingSnapshot: false,
            connectionState: .connected,
            runtime: RuntimeStatusSnapshot(
                timestamp: Date(),
                appName: "autotrading-core",
                appVersion: "1.0",
                env: "prod",
                appStatus: "degraded",
                orderMode: "paper",
                accountMode: "paper",
                marketTradingActive: nil,
                marketClosedIdle: nil,
                strategyRunState: nil,
                riskRunState: nil,
                executionMode: "paper",
                engineState: "running",
                engineAvailableActions: [],
                engineTransitioningAction: nil,
                engineLastAction: nil,
                engineLastError: nil,
                engineMessage: nil,
                engineEmergencyLatched: false,
                engineUpdatedAt: nil,
                databaseStatus: "up",
                databaseConnected: true,
                readinessStatus: "not_ready",
                startupOk: false,
                startupStatus: "error",
                startupError: "KIS auth failed: unauthorized",
                activeWsClients: 0,
                accountSummary: nil,
                workers: .fallback
            ),
            lastErrorMessage: nil
        )

        XCTAssertEqual(status.kind, .authenticationFailure)
        XCTAssertEqual(status.compactText, "인증 확인 필요")
    }

    private static func makeStrategySettingsSnapshot() -> StrategySettingsSnapshot {
        StrategySettingsSnapshot(
            scanner: ScannerSettingsSnapshot(
                modes: ["turnover", "surge"],
                defaultMode: "turnover",
                topN: 10,
                pageStep: 10,
                maxLimit: 30,
                candidateLimit: 30,
                rankingSource: "rank_snapshots",
                minTurnover: nil,
                minChangePct: nil,
                scoreDefinition: ScannerScoreDefinitionSnapshot(
                    name: "후보 우선순위 점수(관찰용)",
                    summary: "거래대금/등락률/상대순위를 조합한 스캐너 점수입니다.",
                    formulaBasis: "mode별 가중합",
                    weights: [
                        "turnover": ScannerScoreWeightsSnapshot(rank: 40, turnover: 45, changePct: 15),
                        "surge": ScannerScoreWeightsSnapshot(rank: 40, turnover: 15, changePct: 45),
                    ],
                    notes: []
                )
            ),
            signal: SignalSettingsSnapshot(
                topN: 10,
                rankJumpThreshold: 3,
                rankJumpWindowSeconds: 600,
                rankHoldTolerance: 1,
                enabledSignalTypes: ["new_entry", "rank_jump", "rank_maintained"]
            ),
            risk: RiskSettingsSnapshot(
                allowedSignalTypes: ["new_entry", "rank_jump"],
                maxConcurrentCandidates: 3,
                cooldownMinutes: 10,
                signalWindowMinutes: 10,
                concurrencyWindowMinutes: 15,
                blockWhenPositionExists: true
            )
        )
    }

    private static func makeMonitoringSnapshotResponse(
        orderMode: String,
        accountMode: String,
        currentPositions: [[String: Any]]
    ) throws -> MonitoringSnapshotResponse {
        let jsonObject: [String: Any] = [
            "runtime": [
                "timestamp": "2026-03-25T06:00:00Z",
                "app_name": "autotrading-core",
                "app_version": "0.1.0",
                "env": "dev",
                "app_status": "ready",
                "order_mode": orderMode,
                "account_mode": accountMode,
                "database_status": "connected",
                "database_connected": true,
                "readiness_status": "ready",
                "startup_ok": true,
                "startup_status": "ok",
                "active_ws_clients": 1,
                "workers": [
                    "summary": [
                        "count": 4,
                        "running": 4,
                        "error": 0,
                        "stopping": 0,
                        "starting": 0,
                        "stopped": 0
                    ],
                    "workers": [:]
                ]
            ],
            "market_top_ranks": [],
            "recent_signals": [],
            "recent_strategy_events": [],
            "recent_exit_events": [],
            "recent_risk_decisions": [],
            "recent_orders": [],
            "recent_fills": [],
            "current_positions": currentPositions,
            "recent_closed_positions": [],
            "pnl_summary": [
                "open_positions": 0,
                "unrealized_pnl_total": NSNull(),
                "realized_pnl_recent_total": NSNull(),
                "recent_closed_count": 0
            ],
            "limits": [:]
        ]
        let data = try JSONSerialization.data(withJSONObject: jsonObject)
        return try MonitoringCoding.decoder().decode(MonitoringSnapshotResponse.self, from: data)
    }
}

private struct MockLocalNotificationService: LocalNotificationServiceProtocol {
    func authorizationStatus() async -> AppNotificationAuthorizationStatus {
        .authorized
    }

    func requestAuthorizationIfNeeded() async -> AppNotificationAuthorizationStatus {
        .authorized
    }

    func deliverNotification(
        title: String,
        subtitle: String?,
        body: String,
        identifier: String
    ) async {}
}

private struct MockMonitoringAPIClient: MonitoringAPIClientProtocol {
    let strategyEnvelope: StrategySettingsResponseEnvelope
    var snapshot: MonitoringSnapshotResponse? = nil
    var runtimeSnapshot: RuntimeStatusSnapshot? = nil

    func fetchSnapshot() async throws -> MonitoringSnapshotResponse {
        guard let snapshot else {
            fatalError("unused in test")
        }
        return snapshot
    }

    func fetchRuntime() async throws -> RuntimeStatusSnapshot {
        if let runtimeSnapshot {
            return runtimeSnapshot
        }
        guard let snapshot else {
            fatalError("unused in test")
        }
        return snapshot.runtime
    }

    func fetchStrategySettings() async throws -> StrategySettingsResponseEnvelope {
        strategyEnvelope
    }

    func updateStrategySettings(_ payload: StrategySettingsUpdatePayload) async throws -> StrategySettingsResponseEnvelope {
        strategyEnvelope
    }

    func fetchAppSettings() async throws -> AppSettingsResponseEnvelope {
        fatalError("unused in test")
    }

    func updateAppSettings(_ payload: AppSettingsUpdatePayload) async throws -> AppSettingsUpdateResponseEnvelope {
        fatalError("unused in test")
    }

    func fetchScannerRanks(mode: String, limit: Int) async throws -> ScannerRanksResponse {
        fatalError("unused in test")
    }

    func fetchChartSeries(symbol: String, timeframe: ChartTimeframeOption, limit: Int) async throws -> ChartSeriesResponse {
        fatalError("unused in test")
    }

    func startEngine() async throws -> EngineControlCommandResponse {
        fatalError("unused in test")
    }

    func pauseEngine() async throws -> EngineControlCommandResponse {
        fatalError("unused in test")
    }

    func emergencyStopEngine() async throws -> EngineControlCommandResponse {
        fatalError("unused in test")
    }

    func clearEmergencyStop() async throws -> EngineControlCommandResponse {
        fatalError("unused in test")
    }

    func setOrderMode(_ mode: String, confirmLive: Bool) async throws -> EngineModeCommandResponse {
        fatalError("unused in test")
    }

    func setAccountMode(_ mode: String) async throws -> EngineModeCommandResponse {
        fatalError("unused in test")
    }
}
