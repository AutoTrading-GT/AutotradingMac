//
//  AppConfig.swift
//  AutotradingMac
//

import Foundation

enum AppConfig {
    private static let defaultBackendBaseURL = "http://127.0.0.1:8008"
    private static let defaultWebSocketPath = "/ws/events"
    private static let backendEnvKey = "AUTOTRADING_BACKEND_BASE_URL"
    private static let websocketEnvKey = "AUTOTRADING_BACKEND_WS_URL"

    static var backendBaseURL: URL {
        let env = ProcessInfo.processInfo.environment[backendEnvKey]
        let candidate = env?.trimmingCharacters(in: .whitespacesAndNewlines)
        let raw = (candidate?.isEmpty == false) ? candidate! : defaultBackendBaseURL
        return URL(string: raw) ?? URL(string: defaultBackendBaseURL)!
    }

    static var snapshotURL: URL {
        backendBaseURL.appendingPathComponent("api/monitoring/snapshot")
    }

    static var runtimeURL: URL {
        backendBaseURL.appendingPathComponent("api/monitoring/runtime")
    }

    static var engineStartURL: URL {
        backendBaseURL.appendingPathComponent("api/engine/start")
    }

    static var enginePauseURL: URL {
        backendBaseURL.appendingPathComponent("api/engine/pause")
    }

    static var engineEmergencyStopURL: URL {
        backendBaseURL.appendingPathComponent("api/engine/emergency-stop")
    }

    static var engineClearEmergencyStopURL: URL {
        backendBaseURL.appendingPathComponent("api/engine/clear-emergency-stop")
    }

    static var engineOrderModeURL: URL {
        backendBaseURL.appendingPathComponent("api/engine/order-mode")
    }

    static var engineAccountModeURL: URL {
        backendBaseURL.appendingPathComponent("api/engine/account-mode")
    }

    static var webSocketURL: URL {
        let env = ProcessInfo.processInfo.environment[websocketEnvKey]
        let candidate = env?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, !candidate.isEmpty, let url = URL(string: candidate) {
            return url
        }
        return deriveWebSocketURL(from: backendBaseURL)
    }

    private static func deriveWebSocketURL(from baseURL: URL) -> URL {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            return URL(string: "ws://127.0.0.1:8008\(defaultWebSocketPath)")!
        }
        if components.scheme == "https" {
            components.scheme = "wss"
        } else {
            components.scheme = "ws"
        }
        components.path = defaultWebSocketPath
        components.query = nil
        components.fragment = nil
        return components.url ?? URL(string: "ws://127.0.0.1:8008\(defaultWebSocketPath)")!
    }
}
