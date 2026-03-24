//
//  EventModels.swift
//  AutotradingMac
//

import Foundation

struct EventEnvelope: Decodable {
    let type: String
    let ts: Date
    let source: String
    let data: [String: JSONValue]
}

struct ConnectionAckPayload: Decodable {
    let connected: Bool
    let connection: [String: String]
    let app: [String: JSONValue]
    let workers: WorkersSnapshot?
}

struct WorkerStatusPayload: Decodable {
    let worker: String
    let status: String
    let statusMessage: String?
    let error: String?
}

struct EngineHealthPayload: Decodable {
    let healthy: Bool
    let details: [String: JSONValue]?
}

struct MarketRankSnapshotPayload: Decodable {
    let timestamp: Date
    let code: String
    let rank: Int?
    let metric: Double?
    let source: String
    let rankingMode: String?
    let symbol: String?
    let payload: [String: JSONValue]?
}

struct MarketTickPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let price: Double
    let change: Double?
    let changePct: Double?
    let volume: Double?
    let metric: Double?
    let source: String
    let payload: [String: JSONValue]?
}

struct SignalGeneratedPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let signalType: String
    let confidence: Double?
    let rankCurrent: Int?
    let rankPrevious: Int?
    let sourceSnapshotId: Int
    let previousSnapshotId: Int?
    let orderMode: String?
    let executionMode: String?
    let payload: [String: JSONValue]?
}

struct RiskDecisionPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let decision: String
    let signalId: Int?
    let signalType: String?
    let relatedSignalReference: String?
    let reason: String
    let orderMode: String?
    let executionMode: String?
    let context: [String: JSONValue]?
}

struct StrategySignalFilteredPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let strategyId: String
    let strategyDisplayName: String?
    let signalType: String
    let stage: String
    let reason: String
    let reasonCode: String?
    let summary: String?
    let selectionMode: String?
    let sourceSnapshotId: Int?
    let rankCurrent: Int?
    let candidateMetric: Double?
    let orderMode: String?
    let executionMode: String?
    let details: [String: JSONValue]?
}

struct OrderCreatedPayload: Decodable {
    let timestamp: Date
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String
    let qty: Double
    let orderPrice: Double?
    let status: String
    let sourceSignalReference: String
}

struct OrderUpdatedPayload: Decodable {
    let timestamp: Date
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String
    let qty: Double
    let orderPrice: Double?
    let filledQty: Double?
    let filledPrice: Double?
    let previousStatus: String?
    let status: String
    let sourceSignalReference: String
    let executionReason: String?
}

struct SignalExitGeneratedPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let positionId: Int
    let reason: String
    let reasonCode: String?
    let summary: String?
    let partial: Bool?
    let partialRatio: Double?
    let qty: Double?
    let currentPositionQty: Double?
    let expectedRemainingQty: Double?
    let markPrice: Double?
    let unrealizedPnl: Double?
    let unrealizedPnlPct: Double?
    let holdingSeconds: Double?
    let sourcePositionReference: String?
    let sourceSignalReference: String?
    let signalType: String?
    let sourceSignalType: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let orderMode: String?
    let executionMode: String?
    let triggeredAt: Date?
}

struct FillReceivedPayload: Decodable {
    let timestamp: Date
    let fillId: Int?
    let orderId: Int
    let code: String
    let symbol: String?
    let side: String?
    let filledQty: Double
    let filledPrice: Double
}

struct PositionUpdatedPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let side: String
    let qty: Double
    let avgPrice: Double?
}

struct PositionPnlUpdatedPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let positionId: Int
    let side: String
    let qty: Double
    let avgPrice: Double
    let markPrice: Double
    let markPriceSource: String?
    let unrealizedPnl: Double
    let unrealizedPnlPct: Double
}

struct PositionClosedPayload: Decodable {
    let timestamp: Date
    let code: String
    let symbol: String?
    let positionId: Int
    let side: String
    let closedQty: Double
    let avgEntryPrice: Double
    let exitPrice: Double
    let realizedPnl: Double
    let realizedPnlPct: Double
    let holdingSeconds: Double?
    let sourceOrderId: Int?
    let sourceSignalReference: String?
    let reason: String
    let reasonCode: String?
    let summary: String?
    let signalType: String?
    let strategyId: String?
    let strategyDisplayName: String?
    let orderMode: String?
    let executionMode: String?
}
