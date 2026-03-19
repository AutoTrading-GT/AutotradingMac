//
//  MonitoringStore.swift
//  AutotradingMac
//

import Foundation

@MainActor
final class MonitoringStore: ObservableObject {
    @Published private(set) var runtime: RuntimeStatusSnapshot?
    @Published private(set) var marketTopRanks: [MarketRankSnapshotItem] = []
    @Published private(set) var recentSignals: [SignalSnapshotItem] = []
    @Published private(set) var recentRiskDecisions: [RiskDecisionSnapshotItem] = []
    @Published private(set) var recentOrders: [OrderSnapshotItem] = []
    @Published private(set) var recentFills: [FillSnapshotItem] = []
    @Published private(set) var currentPositions: [PositionSnapshotItem] = []
    @Published private(set) var recentClosedPositions: [ClosedPositionSnapshotItem] = []
    @Published private(set) var pnlSummary = PnLSummarySnapshot(
        openPositions: 0,
        unrealizedPnlTotal: nil,
        realizedPnlRecentTotal: nil,
        recentClosedCount: 0
    )

    @Published private(set) var latestTicks: [String: MarketTickPayload] = [:]
    @Published private(set) var isLoadingSnapshot = false
    @Published private(set) var snapshotLoaded = false
    @Published private(set) var connectionState: WebSocketConnectionState = .disconnected
    @Published private(set) var lastUpdatedAt: Date?
    @Published private(set) var lastErrorMessage: String?

    private let apiClient: MonitoringAPIClientProtocol
    private let webSocketClient: MonitoringWebSocketClient
    private var started = false
    private let maxRecentItems = 100

    init(
        apiClient: MonitoringAPIClientProtocol = MonitoringAPIClient(),
        webSocketClient: MonitoringWebSocketClient = MonitoringWebSocketClient()
    ) {
        self.apiClient = apiClient
        self.webSocketClient = webSocketClient
        bindWebSocketCallbacks()
    }

    func start() async {
        guard !started else { return }
        started = true
        await reloadSnapshot()
        webSocketClient.connect()
    }

    func stop() {
        webSocketClient.disconnect()
        started = false
    }

    func reloadSnapshot() async {
        isLoadingSnapshot = true
        defer { isLoadingSnapshot = false }

        do {
            let snapshot = try await apiClient.fetchSnapshot()
            apply(snapshot: snapshot)
            snapshotLoaded = true
            lastErrorMessage = nil
            lastUpdatedAt = Date()
        } catch {
            lastErrorMessage = "Snapshot load failed: \(error.localizedDescription)"
            snapshotLoaded = false
        }
    }

    func reconnectWebSocket() {
        webSocketClient.disconnect()
        webSocketClient.connect()
    }

    var workerRows: [WorkerStatusRow] {
        guard let workers = runtime?.workers.workers else { return [] }
        return workers.keys.sorted().map { workerName in
            let entry = workers[workerName] ?? [:]
            return WorkerStatusRow(
                id: workerName,
                worker: workerName,
                status: entry["status"]?.stringValue ?? "unknown",
                error: entry["error"]?.stringValue,
                statusMessage: entry["status_message"]?.stringValue,
                rankSource: entry["rank_source"]?.stringValue,
                tickSource: entry["tick_source"]?.stringValue,
                syncStatus: entry["sync_status"]?.stringValue
            )
        }
    }

    var dashboardCards: [RuntimeMetricCard] {
        guard let runtime else { return [] }
        return [
            RuntimeMetricCard(
                id: "app-status",
                title: "App Status",
                value: runtime.appStatus,
                tone: .fromStatus(runtime.appStatus)
            ),
            RuntimeMetricCard(
                id: "readiness",
                title: "Readiness",
                value: runtime.readinessStatus,
                tone: .fromStatus(runtime.readinessStatus)
            ),
            RuntimeMetricCard(
                id: "database",
                title: "Database",
                value: runtime.databaseStatus,
                tone: .fromStatus(runtime.databaseStatus)
            ),
            RuntimeMetricCard(
                id: "execution-mode",
                title: "Execution Mode",
                value: runtime.executionMode,
                tone: .info
            ),
            RuntimeMetricCard(
                id: "ws-clients",
                title: "WS Clients",
                value: "\(runtime.activeWsClients)",
                tone: .neutral
            ),
        ]
    }

    var marketRows: [MarketRow] {
        let rankByCode = Dictionary(uniqueKeysWithValues: marketTopRanks.map { ($0.code, $0) })
        let codes = Set(rankByCode.keys).union(latestTicks.keys)

        let rows = codes.map { code -> MarketRow in
            let rankItem = rankByCode[code]
            let tick = latestTicks[code]
            return MarketRow(
                id: code,
                code: code,
                symbol: rankItem?.symbol ?? tick?.symbol ?? "-",
                rank: rankItem?.rank,
                price: tick?.price ?? rankItem?.price,
                changePct: tick?.changePct,
                metric: tick?.metric ?? rankItem?.metric,
                source: tick?.source ?? rankItem?.source,
                updatedAt: tick?.timestamp ?? rankItem?.capturedAt
            )
        }

        return rows.sorted { lhs, rhs in
            switch (lhs.rank, rhs.rank) {
            case let (l?, r?):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.code < rhs.code
            }
        }
    }

    var recentErrorItems: [String] {
        var errors: [String] = []
        if let startupError = runtime?.startupError, !startupError.isEmpty {
            errors.append("startup_error: \(startupError)")
        }
        for row in workerRows where row.error?.isEmpty == false {
            errors.append("\(row.worker): \(row.error ?? "")")
        }
        return errors
    }

    private func bindWebSocketCallbacks() {
        webSocketClient.onStateChange = { [weak self] state in
            Task { @MainActor in
                self?.connectionState = state
            }
        }

        webSocketClient.onError = { [weak self] message in
            Task { @MainActor in
                self?.lastErrorMessage = message
            }
        }

        webSocketClient.onEvent = { [weak self] envelope in
            Task { @MainActor in
                self?.handle(event: envelope)
            }
        }
    }

    private func apply(snapshot: MonitoringSnapshotResponse) {
        runtime = snapshot.runtime
        marketTopRanks = snapshot.marketTopRanks
        recentSignals = snapshot.recentSignals
        recentRiskDecisions = snapshot.recentRiskDecisions
        recentOrders = snapshot.recentOrders
        recentFills = snapshot.recentFills
        currentPositions = snapshot.currentPositions
        recentClosedPositions = snapshot.recentClosedPositions
        pnlSummary = snapshot.pnlSummary
    }

    private func handle(event: EventEnvelope) {
        lastUpdatedAt = event.ts

        switch event.type {
        case "connection.ack":
            _ = decodePayload(ConnectionAckPayload.self, from: event.data)
            connectionState = .connected
        case "worker.status":
            if let payload = decodePayload(WorkerStatusPayload.self, from: event.data) {
                applyWorkerStatus(payload: payload)
            }
        case "engine.health":
            if let payload = decodePayload(EngineHealthPayload.self, from: event.data) {
                applyEngineHealth(payload: payload)
            }
        case "market.rank_snapshot":
            if let payload = decodePayload(MarketRankSnapshotPayload.self, from: event.data) {
                applyMarketRank(payload: payload)
            }
        case "market.tick":
            if let payload = decodePayload(MarketTickPayload.self, from: event.data) {
                latestTicks[payload.code] = payload
            }
        case "signal.generated":
            if let payload = decodePayload(SignalGeneratedPayload.self, from: event.data) {
                appendSignal(payload: payload)
            }
        case "risk.blocked", "risk.approved":
            if let payload = decodePayload(RiskDecisionPayload.self, from: event.data) {
                appendRiskDecision(payload: payload)
            }
        case "order.created":
            if let payload = decodePayload(OrderCreatedPayload.self, from: event.data) {
                appendOrUpdateOrderCreated(payload: payload)
            }
        case "order.updated":
            if let payload = decodePayload(OrderUpdatedPayload.self, from: event.data) {
                appendOrUpdateOrderUpdated(payload: payload)
            }
        case "fill.received":
            if let payload = decodePayload(FillReceivedPayload.self, from: event.data) {
                appendFill(payload: payload)
            }
        case "position.updated":
            if let payload = decodePayload(PositionUpdatedPayload.self, from: event.data) {
                appendOrUpdatePosition(payload: payload)
            }
        case "position.pnl_updated":
            if let payload = decodePayload(PositionPnlUpdatedPayload.self, from: event.data) {
                applyPositionPnL(payload: payload)
            }
        case "position.closed":
            if let payload = decodePayload(PositionClosedPayload.self, from: event.data) {
                applyPositionClosed(payload: payload)
            }
        default:
            break
        }
    }

    private func applyWorkerStatus(payload: WorkerStatusPayload) {
        guard var runtime else { return }
        var workers = runtime.workers.workers
        var workerEntry = workers[payload.worker] ?? [:]
        workerEntry["status"] = .string(payload.status)
        if let message = payload.statusMessage {
            workerEntry["status_message"] = .string(message)
        }
        if let error = payload.error {
            workerEntry["error"] = .string(error)
        } else {
            workerEntry["error"] = .null
        }
        workers[payload.worker] = workerEntry
        runtime.workers.workers = workers
        self.runtime = runtime
    }

    private func applyEngineHealth(payload: EngineHealthPayload) {
        guard var runtime else { return }
        runtime.appStatus = payload.healthy ? "ready" : "degraded"
        if let executionMode = payload.details?["execution_mode"]?.stringValue {
            runtime.executionMode = executionMode
        }
        self.runtime = runtime
    }

    private func applyMarketRank(payload: MarketRankSnapshotPayload) {
        let incoming = MarketRankSnapshotItem(
            code: payload.code,
            symbol: payload.symbol,
            rank: payload.rank,
            metric: payload.metric,
            price: payload.payload?["price"]?.doubleValue,
            source: payload.source,
            capturedAt: payload.timestamp
        )
        if let index = marketTopRanks.firstIndex(where: { $0.code == incoming.code }) {
            marketTopRanks[index] = incoming
        } else {
            marketTopRanks.insert(incoming, at: 0)
        }
        marketTopRanks = Array(marketTopRanks.prefix(maxRecentItems)).sorted { lhs, rhs in
            switch (lhs.rank, rhs.rank) {
            case let (l?, r?):
                return l < r
            case (.some, .none):
                return true
            case (.none, .some):
                return false
            case (.none, .none):
                return lhs.code < rhs.code
            }
        }
    }

    private func appendSignal(payload: SignalGeneratedPayload) {
        let row = SignalSnapshotItem(
            signalId: nil,
            code: payload.code,
            symbol: payload.symbol,
            signalType: payload.signalType,
            confidence: payload.confidence,
            sourceSnapshotId: payload.sourceSnapshotId,
            previousSnapshotId: payload.previousSnapshotId,
            createdAt: payload.timestamp
        )
        recentSignals.insert(row, at: 0)
        recentSignals = Array(recentSignals.prefix(maxRecentItems))
    }

    private func appendRiskDecision(payload: RiskDecisionPayload) {
        let row = RiskDecisionSnapshotItem(
            riskEventId: nil,
            code: payload.code,
            symbol: payload.symbol,
            decision: payload.decision,
            blocked: payload.decision.lowercased() == "blocked",
            reason: payload.reason,
            signalId: payload.signalId,
            signalType: payload.signalType,
            relatedSignalReference: payload.relatedSignalReference,
            createdAt: payload.timestamp
        )
        recentRiskDecisions.insert(row, at: 0)
        recentRiskDecisions = Array(recentRiskDecisions.prefix(maxRecentItems))
    }

    private func appendOrUpdateOrderCreated(payload: OrderCreatedPayload) {
        let row = OrderSnapshotItem(
            orderId: payload.orderId,
            code: payload.code,
            symbol: payload.symbol,
            side: payload.side,
            orderQty: payload.qty,
            orderPrice: payload.orderPrice,
            status: payload.status,
            executionMode: runtime?.executionMode,
            sourceSignalReference: payload.sourceSignalReference,
            brokerOrderId: nil,
            createdAt: payload.timestamp,
            updatedAt: payload.timestamp
        )
        upsertOrder(row)
    }

    private func appendOrUpdateOrderUpdated(payload: OrderUpdatedPayload) {
        if let index = recentOrders.firstIndex(where: { $0.orderId == payload.orderId }) {
            let previous = recentOrders[index]
            recentOrders[index] = OrderSnapshotItem(
                orderId: previous.orderId,
                code: payload.code,
                symbol: payload.symbol,
                side: payload.side,
                orderQty: payload.qty,
                orderPrice: payload.orderPrice,
                status: payload.status,
                executionMode: previous.executionMode ?? runtime?.executionMode,
                sourceSignalReference: payload.sourceSignalReference,
                brokerOrderId: previous.brokerOrderId,
                createdAt: previous.createdAt,
                updatedAt: payload.timestamp
            )
        } else {
            let created = OrderSnapshotItem(
                orderId: payload.orderId,
                code: payload.code,
                symbol: payload.symbol,
                side: payload.side,
                orderQty: payload.qty,
                orderPrice: payload.orderPrice,
                status: payload.status,
                executionMode: runtime?.executionMode,
                sourceSignalReference: payload.sourceSignalReference,
                brokerOrderId: nil,
                createdAt: payload.timestamp,
                updatedAt: payload.timestamp
            )
            upsertOrder(created)
        }
    }

    private func appendFill(payload: FillReceivedPayload) {
        guard let fillID = payload.fillId else { return }
        let row = FillSnapshotItem(
            fillId: fillID,
            orderId: payload.orderId,
            code: payload.code,
            symbol: payload.symbol,
            side: payload.side ?? "-",
            filledQty: payload.filledQty,
            filledPrice: payload.filledPrice,
            executionMode: runtime?.executionMode,
            filledAt: payload.timestamp
        )
        if recentFills.contains(where: { $0.fillId == row.fillId }) {
            return
        }
        recentFills.insert(row, at: 0)
        recentFills = Array(recentFills.prefix(maxRecentItems))
    }

    private func appendOrUpdatePosition(payload: PositionUpdatedPayload) {
        if let index = currentPositions.firstIndex(where: { $0.code == payload.code }) {
            currentPositions[index].symbol = payload.symbol
            currentPositions[index].side = payload.side
            currentPositions[index].qty = payload.qty
            currentPositions[index].avgPrice = payload.avgPrice
            currentPositions[index].updatedAt = payload.timestamp
        } else {
            currentPositions.insert(
                PositionSnapshotItem(
                    positionId: nil,
                    code: payload.code,
                    symbol: payload.symbol,
                    side: payload.side,
                    qty: payload.qty,
                    avgPrice: payload.avgPrice,
                    markPrice: nil,
                    markPriceSource: nil,
                    unrealizedPnl: nil,
                    unrealizedPnlPct: nil,
                    updatedAt: payload.timestamp
                ),
                at: 0
            )
        }
        currentPositions = currentPositions.filter { $0.qty > 0 }
        recalculatePnLSummary()
    }

    private func applyPositionPnL(payload: PositionPnlUpdatedPayload) {
        if let index = currentPositions.firstIndex(where: { $0.code == payload.code }) {
            currentPositions[index].positionId = payload.positionId
            currentPositions[index].symbol = payload.symbol
            currentPositions[index].side = payload.side
            currentPositions[index].qty = payload.qty
            currentPositions[index].avgPrice = payload.avgPrice
            currentPositions[index].markPrice = payload.markPrice
            currentPositions[index].markPriceSource = payload.markPriceSource
            currentPositions[index].unrealizedPnl = payload.unrealizedPnl
            currentPositions[index].unrealizedPnlPct = payload.unrealizedPnlPct
            currentPositions[index].updatedAt = payload.timestamp
        } else {
            currentPositions.insert(
                PositionSnapshotItem(
                    positionId: payload.positionId,
                    code: payload.code,
                    symbol: payload.symbol,
                    side: payload.side,
                    qty: payload.qty,
                    avgPrice: payload.avgPrice,
                    markPrice: payload.markPrice,
                    markPriceSource: payload.markPriceSource,
                    unrealizedPnl: payload.unrealizedPnl,
                    unrealizedPnlPct: payload.unrealizedPnlPct,
                    updatedAt: payload.timestamp
                ),
                at: 0
            )
        }
        recalculatePnLSummary()
    }

    private func applyPositionClosed(payload: PositionClosedPayload) {
        currentPositions.removeAll { $0.positionId == payload.positionId || $0.code == payload.code }
        recentClosedPositions.insert(
            ClosedPositionSnapshotItem(
                eventId: nil,
                positionId: payload.positionId,
                code: payload.code,
                symbol: payload.symbol,
                closedQty: payload.closedQty,
                avgEntryPrice: payload.avgEntryPrice,
                exitPrice: payload.exitPrice,
                realizedPnl: payload.realizedPnl,
                realizedPnlPct: payload.realizedPnlPct,
                reason: payload.reason,
                createdAt: payload.timestamp
            ),
            at: 0
        )
        recentClosedPositions = Array(recentClosedPositions.prefix(maxRecentItems))
        recalculatePnLSummary()
    }

    private func upsertOrder(_ row: OrderSnapshotItem) {
        if let index = recentOrders.firstIndex(where: { $0.orderId == row.orderId }) {
            recentOrders[index] = row
        } else {
            recentOrders.insert(row, at: 0)
            recentOrders = Array(recentOrders.prefix(maxRecentItems))
        }
    }

    private func recalculatePnLSummary() {
        let openPositions = currentPositions.count
        let unrealizedTotal = currentPositions.compactMap(\.unrealizedPnl).reduce(0, +)
        let realizedTotal = recentClosedPositions.compactMap(\.realizedPnl).reduce(0, +)
        pnlSummary = PnLSummarySnapshot(
            openPositions: openPositions,
            unrealizedPnlTotal: openPositions > 0 ? unrealizedTotal : nil,
            realizedPnlRecentTotal: recentClosedPositions.isEmpty ? nil : realizedTotal,
            recentClosedCount: recentClosedPositions.count
        )
    }

    private func decodePayload<T: Decodable>(_ type: T.Type, from data: [String: JSONValue]) -> T? {
        let payload = data.mapValues(\.anyValue)
        guard JSONSerialization.isValidJSONObject(payload) else {
            return nil
        }
        do {
            let json = try JSONSerialization.data(withJSONObject: payload, options: [])
            return try MonitoringCoding.decoder().decode(type, from: json)
        } catch {
            lastErrorMessage = "Event decode failed (\(type)): \(error.localizedDescription)"
            return nil
        }
    }
}
