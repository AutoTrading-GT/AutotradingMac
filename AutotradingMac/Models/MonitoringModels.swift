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
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        appName = try container.decode(String.self, forKey: .appName)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        env = try container.decode(String.self, forKey: .env)
        appStatus = try container.decode(String.self, forKey: .appStatus)
        orderMode = try container.decode(String.self, forKey: .orderMode)
        accountMode = try container.decode(String.self, forKey: .accountMode)
        executionMode = try container.decodeIfPresent(String.self, forKey: .executionMode)
        engineState = try container.decodeIfPresent(String.self, forKey: .engineState)
        engineAvailableActions = try container.decodeIfPresent([String].self, forKey: .engineAvailableActions)
        engineTransitioningAction = try container.decodeIfPresent(String.self, forKey: .engineTransitioningAction)
        engineLastAction = try container.decodeIfPresent(String.self, forKey: .engineLastAction)
        engineLastError = try container.decodeIfPresent(String.self, forKey: .engineLastError)
        engineMessage = try container.decodeIfPresent(String.self, forKey: .engineMessage)
        engineEmergencyLatched = try container.decodeIfPresent(Bool.self, forKey: .engineEmergencyLatched)
        engineUpdatedAt = try container.decodeIfPresent(Date.self, forKey: .engineUpdatedAt)
        databaseStatus = try container.decode(String.self, forKey: .databaseStatus)
        databaseConnected = try container.decode(Bool.self, forKey: .databaseConnected)
        readinessStatus = try container.decode(String.self, forKey: .readinessStatus)
        startupOk = try container.decode(Bool.self, forKey: .startupOk)
        startupStatus = try container.decode(String.self, forKey: .startupStatus)
        startupError = try container.decodeIfPresent(String.self, forKey: .startupError)
        activeWsClients = try container.decode(Int.self, forKey: .activeWsClients)
        accountSummary = try container.decodeIfPresent(AccountSummarySnapshot.self, forKey: .accountSummary)
        workers = try container.decodeIfPresent(WorkersSnapshot.self, forKey: .workers) ?? WorkersSnapshot.fallback
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
        mode = try container.decode(String.self, forKey: .mode)
        source = try container.decode(String.self, forKey: .source)
        available = try container.decode(Bool.self, forKey: .available)
        unavailableReason = try container.decodeIfPresent(String.self, forKey: .unavailableReason)
        accountLabel = try container.decodeIfPresent(String.self, forKey: .accountLabel)
        accountNumber = try container.decodeIfPresent(String.self, forKey: .accountNumber)
        maskedAccount = try container.decodeIfPresent(String.self, forKey: .maskedAccount)
        totalAccountValue = try container.decodeIfPresent(Double.self, forKey: .totalAccountValue)
        cashBalance = try container.decodeIfPresent(Double.self, forKey: .cashBalance)
        unrealizedPnlTotal = try container.decodeIfPresent(Double.self, forKey: .unrealizedPnlTotal)
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
