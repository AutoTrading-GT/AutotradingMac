//
//  StrategyRuntimeConfig.swift
//  AutotradingMac
//

import Foundation

struct StrategyRuntimeConfig {
    let executionMode: String
    let paperOrderQty: Double
    let paperTakeProfitPct: Double
    let paperStopLossPct: Double
    let paperMaxHoldingMinutes: Int
    let paperExitQtyRatio: Double
    let riskAllowedSignalTypes: [String]
    let riskMaxConcurrentCandidates: Int
    let riskCooldownMinutes: Int
    let riskSignalWindowMinutes: Int
    let riskConcurrencyWindowMinutes: Int
    let riskBlockWhenPositionExists: Bool

    static var current: StrategyRuntimeConfig {
        let env = ProcessInfo.processInfo.environment
        return StrategyRuntimeConfig(
            executionMode: envString(env, key: "EXECUTION_MODE", default: "paper"),
            paperOrderQty: envDouble(env, key: "PAPER_ORDER_QTY", default: 1.0),
            paperTakeProfitPct: envDouble(env, key: "PAPER_TAKE_PROFIT_PCT", default: 0.03),
            paperStopLossPct: envDouble(env, key: "PAPER_STOP_LOSS_PCT", default: 0.02),
            paperMaxHoldingMinutes: envInt(env, key: "PAPER_MAX_HOLDING_MINUTES", default: 60),
            paperExitQtyRatio: envDouble(env, key: "PAPER_EXIT_QTY_RATIO", default: 1.0),
            riskAllowedSignalTypes: envCSV(env, key: "RISK_ALLOWED_SIGNAL_TYPES", default: "new_entry,rank_jump"),
            riskMaxConcurrentCandidates: envInt(env, key: "RISK_MAX_CONCURRENT_CANDIDATES", default: 3),
            riskCooldownMinutes: envInt(env, key: "RISK_COOLDOWN_MINUTES", default: 10),
            riskSignalWindowMinutes: envInt(env, key: "RISK_SIGNAL_WINDOW_MINUTES", default: 10),
            riskConcurrencyWindowMinutes: envInt(env, key: "RISK_CONCURRENCY_WINDOW_MINUTES", default: 15),
            riskBlockWhenPositionExists: envBool(env, key: "RISK_BLOCK_WHEN_POSITION_EXISTS", default: true)
        )
    }

    private static func envString(_ env: [String: String], key: String, default defaultValue: String) -> String {
        guard let raw = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return defaultValue
        }
        return raw
    }

    private static func envDouble(_ env: [String: String], key: String, default defaultValue: Double) -> Double {
        guard let raw = env[key], let value = Double(raw) else { return defaultValue }
        return value
    }

    private static func envInt(_ env: [String: String], key: String, default defaultValue: Int) -> Int {
        guard let raw = env[key], let value = Int(raw) else { return defaultValue }
        return value
    }

    private static func envBool(_ env: [String: String], key: String, default defaultValue: Bool) -> Bool {
        guard let raw = env[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !raw.isEmpty else {
            return defaultValue
        }
        switch raw {
        case "1", "true", "yes", "on":
            return true
        case "0", "false", "no", "off":
            return false
        default:
            return defaultValue
        }
    }

    private static func envCSV(_ env: [String: String], key: String, default defaultValue: String) -> [String] {
        let raw = envString(env, key: key, default: defaultValue)
        return raw
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
