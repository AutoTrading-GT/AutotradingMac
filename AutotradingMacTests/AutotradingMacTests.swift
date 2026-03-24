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
        XCTAssertEqual(snapshot.strategyTemplates.map(\.strategyId), ["turnover_surge_momentum", "intraday_breakout"])
        XCTAssertEqual(snapshot.template(id: "turnover_surge_momentum")?.status, "active")
        XCTAssertEqual(snapshot.template(id: "intraday_breakout")?.status, "preview_only")
        XCTAssertEqual(
            snapshot.strategyParams["turnover_surge_momentum"]?["selection_mode"]?.stringValue,
            "turnover"
        )
        XCTAssertEqual(snapshot.commonRiskParams["position_size_pct"]?.doubleValue, 10.0)
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

    func fetchSnapshot() async throws -> MonitoringSnapshotResponse {
        fatalError("unused in test")
    }

    func fetchRuntime() async throws -> RuntimeStatusSnapshot {
        fatalError("unused in test")
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
