//
//  MonitoringModels.swift
//  AutotradingMac
//

import Foundation

struct MonitoringSnapshotResponse: Decodable {
    let runtime: RuntimeStatusSnapshot
    let marketTopRanks: [MarketRankSnapshotItem]
    let recentSignals: [SignalSnapshotItem]
    let recentRiskDecisions: [RiskDecisionSnapshotItem]
    let recentOrders: [OrderSnapshotItem]
    let recentFills: [FillSnapshotItem]
    let currentPositions: [PositionSnapshotItem]
    let recentClosedPositions: [ClosedPositionSnapshotItem]
    let pnlSummary: PnLSummarySnapshot
    let limits: [String: Int]

    enum CodingKeys: String, CodingKey {
        case runtime
        case marketTopRanks
        case recentSignals
        case recentRiskDecisions
        case recentOrders
        case recentFills
        case currentPositions
        case recentClosedPositions
        case pnlSummary
        case limits
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        runtime = (try? container.decode(RuntimeStatusSnapshot.self, forKey: .runtime))
            ?? RuntimeStatusSnapshot.fallback
        marketTopRanks = Self.decodeLossyArray(MarketRankSnapshotItem.self, from: container, forKey: .marketTopRanks)
        recentSignals = Self.decodeLossyArray(SignalSnapshotItem.self, from: container, forKey: .recentSignals)
        recentRiskDecisions = Self.decodeLossyArray(RiskDecisionSnapshotItem.self, from: container, forKey: .recentRiskDecisions)
        recentOrders = Self.decodeLossyArray(OrderSnapshotItem.self, from: container, forKey: .recentOrders)
        recentFills = Self.decodeLossyArray(FillSnapshotItem.self, from: container, forKey: .recentFills)
        currentPositions = Self.decodeLossyArray(PositionSnapshotItem.self, from: container, forKey: .currentPositions)
        recentClosedPositions = Self.decodeLossyArray(ClosedPositionSnapshotItem.self, from: container, forKey: .recentClosedPositions)
        pnlSummary = (try? container.decode(PnLSummarySnapshot.self, forKey: .pnlSummary))
            ?? PnLSummarySnapshot(openPositions: 0, unrealizedPnlTotal: nil, realizedPnlRecentTotal: nil, recentClosedCount: 0)
        limits = (try? container.decode([String: Int].self, forKey: .limits)) ?? [:]
    }

    private static func decodeLossyArray<T: Decodable>(
        _ type: T.Type,
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> [T] {
        guard let wrapped = try? container.decode([LossyDecodable<T>].self, forKey: key) else {
            return []
        }
        return wrapped.compactMap(\.value)
    }
}

struct RuntimeStatusSnapshot: Decodable {
    var timestamp: Date
    var appName: String
    var appVersion: String
    var env: String
    var appStatus: String
    var orderMode: String
    var accountMode: String
    var executionMode: String?
    var engineState: String?
    var engineAvailableActions: [String]?
    var engineTransitioningAction: String?
    var engineLastAction: String?
    var engineLastError: String?
    var engineMessage: String?
    var engineEmergencyLatched: Bool?
    var engineUpdatedAt: Date?
    var databaseStatus: String
    var databaseConnected: Bool
    var readinessStatus: String
    var startupOk: Bool
    var startupStatus: String
    var startupError: String?
    var activeWsClients: Int
    var accountSummary: AccountSummarySnapshot?
    var workers: WorkersSnapshot

    init(
        timestamp: Date,
        appName: String,
        appVersion: String,
        env: String,
        appStatus: String,
        orderMode: String,
        accountMode: String,
        executionMode: String?,
        engineState: String?,
        engineAvailableActions: [String]?,
        engineTransitioningAction: String?,
        engineLastAction: String?,
        engineLastError: String?,
        engineMessage: String?,
        engineEmergencyLatched: Bool?,
        engineUpdatedAt: Date?,
        databaseStatus: String,
        databaseConnected: Bool,
        readinessStatus: String,
        startupOk: Bool,
        startupStatus: String,
        startupError: String?,
        activeWsClients: Int,
        accountSummary: AccountSummarySnapshot?,
        workers: WorkersSnapshot
    ) {
        self.timestamp = timestamp
        self.appName = appName
        self.appVersion = appVersion
        self.env = env
        self.appStatus = appStatus
        self.orderMode = orderMode
        self.accountMode = accountMode
        self.executionMode = executionMode
        self.engineState = engineState
        self.engineAvailableActions = engineAvailableActions
        self.engineTransitioningAction = engineTransitioningAction
        self.engineLastAction = engineLastAction
        self.engineLastError = engineLastError
        self.engineMessage = engineMessage
        self.engineEmergencyLatched = engineEmergencyLatched
        self.engineUpdatedAt = engineUpdatedAt
        self.databaseStatus = databaseStatus
        self.databaseConnected = databaseConnected
        self.readinessStatus = readinessStatus
        self.startupOk = startupOk
        self.startupStatus = startupStatus
        self.startupError = startupError
        self.activeWsClients = activeWsClients
        self.accountSummary = accountSummary
        self.workers = workers
    }

    static let fallback = RuntimeStatusSnapshot(
        timestamp: Date(),
        appName: "autotrading-core",
        appVersion: "-",
        env: "unknown",
        appStatus: "degraded",
        orderMode: "paper",
        accountMode: "paper",
        executionMode: "paper",
        engineState: nil,
        engineAvailableActions: [],
        engineTransitioningAction: nil,
        engineLastAction: nil,
        engineLastError: nil,
        engineMessage: nil,
        engineEmergencyLatched: nil,
        engineUpdatedAt: nil,
        databaseStatus: "unknown",
        databaseConnected: false,
        readinessStatus: "not_ready",
        startupOk: false,
        startupStatus: "unknown",
        startupError: nil,
        activeWsClients: 0,
        accountSummary: nil,
        workers: WorkersSnapshot.fallback
    )

    enum CodingKeys: String, CodingKey {
        case timestamp
        case appName
        case appVersion
        case env
        case appStatus
        case orderMode
        case accountMode
        case executionMode
        case engineState
        case engineAvailableActions
        case engineTransitioningAction
        case engineLastAction
        case engineLastError
        case engineMessage
        case engineEmergencyLatched
        case engineUpdatedAt
        case databaseStatus
        case databaseConnected
        case readinessStatus
        case startupOk
        case startupStatus
        case startupError
        case activeWsClients
        case accountSummary
        case workers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = (try? container.decode(Date.self, forKey: .timestamp)) ?? Date()
        appName = container.decodeStringFlexible(forKey: .appName) ?? "autotrading-core"
        appVersion = container.decodeStringFlexible(forKey: .appVersion) ?? "-"
        env = container.decodeStringFlexible(forKey: .env) ?? "unknown"
        appStatus = container.decodeStringFlexible(forKey: .appStatus) ?? "degraded"
        executionMode = container.decodeStringFlexible(forKey: .executionMode)
        orderMode = container.decodeStringFlexible(forKey: .orderMode)
            ?? executionMode
            ?? "paper"
        accountMode = container.decodeStringFlexible(forKey: .accountMode)
            ?? "paper"
        engineState = container.decodeStringFlexible(forKey: .engineState)
        engineAvailableActions = try container.decodeIfPresent([String].self, forKey: .engineAvailableActions)
        engineTransitioningAction = container.decodeStringFlexible(forKey: .engineTransitioningAction)
        engineLastAction = container.decodeStringFlexible(forKey: .engineLastAction)
        engineLastError = container.decodeStringFlexible(forKey: .engineLastError)
        engineMessage = container.decodeStringFlexible(forKey: .engineMessage)
        engineEmergencyLatched = container.decodeBoolFlexible(forKey: .engineEmergencyLatched)
        engineUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .engineUpdatedAt)
        databaseStatus = container.decodeStringFlexible(forKey: .databaseStatus) ?? "unknown"
        databaseConnected = container.decodeBoolFlexible(forKey: .databaseConnected) ?? false
        readinessStatus = container.decodeStringFlexible(forKey: .readinessStatus) ?? "not_ready"
        startupOk = container.decodeBoolFlexible(forKey: .startupOk) ?? false
        startupStatus = container.decodeStringFlexible(forKey: .startupStatus) ?? "unknown"
        startupError = container.decodeStringFlexible(forKey: .startupError)
        activeWsClients = container.decodeIntFlexible(forKey: .activeWsClients) ?? 0
        accountSummary = try? container.decodeIfPresent(AccountSummarySnapshot.self, forKey: .accountSummary)
        workers = (try? container.decode(WorkersSnapshot.self, forKey: .workers)) ?? WorkersSnapshot.fallback
    }
}

struct AccountSummarySnapshot: Decodable {
    let mode: String
    let source: String
    let available: Bool
    let unavailableReason: String?
    let accountLabel: String?
    let accountNumber: String?
    let maskedAccount: String?
    let totalAccountValue: Double?
    let cashBalance: Double?
    let unrealizedPnlTotal: Double?

    enum CodingKeys: String, CodingKey {
        case mode
        case source
        case available
        case unavailableReason
        case accountLabel
        case accountNumber
        case maskedAccount
        case totalAccountValue
        case cashBalance
        case unrealizedPnlTotal
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = container.decodeStringFlexible(forKey: .mode) ?? "paper"
        source = container.decodeStringFlexible(forKey: .source) ?? "unknown"
        available = container.decodeBoolFlexible(forKey: .available) ?? false
        unavailableReason = container.decodeStringFlexible(forKey: .unavailableReason)
        accountLabel = container.decodeStringFlexible(forKey: .accountLabel)
        accountNumber = container.decodeStringFlexible(forKey: .accountNumber)
        maskedAccount = container.decodeStringFlexible(forKey: .maskedAccount)
        totalAccountValue = container.decodeDoubleFlexible(forKey: .totalAccountValue)
        cashBalance = container.decodeDoubleFlexible(forKey: .cashBalance)
        unrealizedPnlTotal = container.decodeDoubleFlexible(forKey: .unrealizedPnlTotal)
    }
}

struct RuntimeStatusResponseEnvelope: Decodable {
    let data: RuntimeStatusSnapshot
}

struct WorkerSummarySnapshot: Decodable {
    let count: Int
    let running: Int
    let error: Int
    let stopping: Int
    let starting: Int
    let stopped: Int
}

struct WorkersSnapshot: Decodable {
    var summary: WorkerSummarySnapshot
    var workers: [String: [String: JSONValue]]

    static let fallback = WorkersSnapshot(
        summary: WorkerSummarySnapshot(count: 0, running: 0, error: 0, stopping: 0, starting: 0, stopped: 0),
        workers: [:]
    )

    enum CodingKeys: String, CodingKey {
        case summary
        case workers
    }

    init(summary: WorkerSummarySnapshot, workers: [String: [String: JSONValue]]) {
        self.summary = summary
        self.workers = workers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        summary = (try? container.decode(WorkerSummarySnapshot.self, forKey: .summary))
            ?? WorkersSnapshot.fallback.summary

        guard let rawWorkers = try? container.decode([String: JSONValue].self, forKey: .workers) else {
            workers = [:]
            return
        }
        var parsed: [String: [String: JSONValue]] = [:]
        for (name, value) in rawWorkers {
            if let object = value.objectValue {
                parsed[name] = object
            }
        }
        workers = parsed
    }
}

struct MarketRankSnapshotItem: Decodable, Identifiable {
    var id: String { code }
    let code: String
    let symbol: String?
    let rank: Int?
    let metric: Double?
    let price: Double?
    let source: String?
    let capturedAt: Date
}

struct SignalSnapshotItem: Decodable, Identifiable {
    var id: String { "signal-\(signalId?.description ?? "none")-\(code)-\(createdAt.timeIntervalSince1970)" }
    let signalId: Int?
    let code: String
    let symbol: String?
    let signalType: String
    let confidence: Double?
    let sourceSnapshotId: Int?
    let previousSnapshotId: Int?
    let createdAt: Date
}

struct RiskDecisionSnapshotItem: Decodable, Identifiable {
    var id: String {
        "risk-\(riskEventId?.description ?? "none")-\(code ?? "unknown")-\(createdAt.timeIntervalSince1970)"
    }

    let riskEventId: Int?
    let code: String?
    let symbol: String?
    let decision: String
    let blocked: Bool?
    let reason: String
    let signalId: Int?
    let signalType: String?
    let relatedSignalReference: String?
    let createdAt: Date
}

struct OrderSnapshotItem: Decodable, Identifiable {
    var id: Int { orderId }
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String
    let orderQty: Double
    let orderPrice: Double?
    let status: String
    let orderMode: String?
    let executionMode: String?
    let sourceSignalReference: String?
    let brokerOrderId: String?
    let createdAt: Date
    let updatedAt: Date
}

struct FillSnapshotItem: Decodable, Identifiable {
    var id: Int { fillId }
    let fillId: Int
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String
    let filledQty: Double
    let filledPrice: Double
    let orderMode: String?
    let executionMode: String?
    let filledAt: Date
}

struct PositionSnapshotItem: Decodable, Identifiable {
    var id: String { "position-\(positionId?.description ?? "none")-\(code)" }
    var positionId: Int?
    var code: String
    var symbol: String?
    var side: String
    var qty: Double
    var avgPrice: Double?
    var markPrice: Double?
    var markPriceSource: String?
    var unrealizedPnl: Double?
    var unrealizedPnlPct: Double?
    var updatedAt: Date
}

struct ClosedPositionSnapshotItem: Decodable, Identifiable {
    var id: String {
        "closed-\(eventId?.description ?? "none")-\(positionId?.description ?? "none")-\(createdAt.timeIntervalSince1970)"
    }

    let eventId: Int?
    let positionId: Int?
    let code: String?
    let symbol: String?
    let closedQty: Double?
    let avgEntryPrice: Double?
    let exitPrice: Double?
    let realizedPnl: Double?
    let realizedPnlPct: Double?
    let reason: String?
    let createdAt: Date
}

struct PnLSummarySnapshot: Decodable {
    var openPositions: Int
    var unrealizedPnlTotal: Double?
    var realizedPnlRecentTotal: Double?
    var recentClosedCount: Int
}

struct RuntimeMetricCard: Identifiable {
    let id: String
    let title: String
    let value: String
    let tone: StatusTone
}

struct WorkerStatusRow: Identifiable {
    let id: String
    let worker: String
    let status: String
    let error: String?
    let statusMessage: String?
    let rankSource: String?
    let tickSource: String?
    let syncStatus: String?
}

struct MarketRow: Identifiable {
    let id: String
    let code: String
    let symbol: String
    let rank: Int?
    let price: Double?
    let changePct: Double?
    let metric: Double?
    let source: String?
    let updatedAt: Date?
}

struct EngineControlSnapshot: Decodable {
    let state: String
    let orderMode: String
    let accountMode: String
    let orderModeLiveAllowed: Bool
    let transitioningAction: String?
    let lastAction: String?
    let lastError: String?
    let message: String?
    let emergencyLatched: Bool
    let availableActions: [String]
    let updatedAt: Date
}

struct EngineControlCommandResponse: Decodable {
    let ok: Bool
    let action: String
    let message: String
    let engine: EngineControlSnapshot
}

struct EngineModeCommandResponse: Decodable {
    let ok: Bool
    let target: String
    let mode: String
    let message: String
    let engine: EngineControlSnapshot
}

private struct LossyDecodable<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

private extension KeyedDecodingContainer {
    func decodeStringFlexible(forKey key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return String(value)
        }
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return String(value)
        }
        return nil
    }

    func decodeDoubleFlexible(forKey key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return Double(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            return Double(value.replacingOccurrences(of: ",", with: ""))
        }
        return nil
    }

    func decodeIntFlexible(forKey key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(value)
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            if let intValue = Int(value) {
                return intValue
            }
            if let doubleValue = Double(value) {
                return Int(doubleValue)
            }
        }
        return nil
    }

    func decodeBoolFlexible(forKey key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) {
            return value
        }
        if let value = try? decodeIfPresent(Int.self, forKey: key) {
            return value != 0
        }
        if let value = try? decodeIfPresent(String.self, forKey: key) {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true", "1", "yes", "y":
                return true
            case "false", "0", "no", "n":
                return false
            default:
                return nil
            }
        }
        return nil
    }
}
