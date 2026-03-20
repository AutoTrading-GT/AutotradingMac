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
        return normalizedBackendURL(raw) ?? URL(string: defaultBackendBaseURL)!
    }

    static var snapshotURL: URL {
        apiEndpoint("monitoring/snapshot")
    }

    static var runtimeURL: URL {
        apiEndpoint("monitoring/runtime")
    }

    static var engineStartURL: URL {
        apiEndpoint("engine/start")
    }

    static var enginePauseURL: URL {
        apiEndpoint("engine/pause")
    }

    static var engineEmergencyStopURL: URL {
        apiEndpoint("engine/emergency-stop")
    }

    static var engineClearEmergencyStopURL: URL {
        apiEndpoint("engine/clear-emergency-stop")
    }

    static var engineOrderModeURL: URL {
        apiEndpoint("engine/order-mode")
    }

    static var engineAccountModeURL: URL {
        apiEndpoint("engine/account-mode")
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

    private static func apiEndpoint(_ suffix: String) -> URL {
        let base = backendBaseURL
        let normalizedSuffix = suffix.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let basePath = base.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if basePath.hasSuffix("api") {
            return base.appendingPathComponent(normalizedSuffix)
        }
        return base.appendingPathComponent("api/\(normalizedSuffix)")
    }

    private static func normalizedBackendURL(_ raw: String) -> URL? {
        guard var components = URLComponents(string: raw) else {
            return nil
        }
        let trimmedPath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = trimmedPath.isEmpty ? "" : "/\(trimmedPath)"
        return components.url
    }
}
