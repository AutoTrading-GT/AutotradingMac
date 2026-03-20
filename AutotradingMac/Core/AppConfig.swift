//
//  AppConfig.swift
//  AutotradingMac
//

import Foundation

enum AppConfig {
    static let debugBuildMarker = "AUTOTRADING_MAC_DEBUG_BUILD_20260320"
    private static let forceDiagnosticEndpointMode = true
    private static let diagnosticBackendBaseURL = URL(string: "http://127.0.0.1:8008")!
    private static let diagnosticWebSocketURL = URL(string: "ws://127.0.0.1:8008/ws/events")!
    private static let defaultBackendBaseURL = "http://127.0.0.1:8008"
    private static let defaultWebSocketPath = "/ws/events"
    private static let backendEnvKey = "AUTOTRADING_BACKEND_BASE_URL"
    private static let websocketEnvKey = "AUTOTRADING_BACKEND_WS_URL"

    static var backendBaseURL: URL {
        if forceDiagnosticEndpointMode {
            return diagnosticBackendBaseURL
        }
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
        if forceDiagnosticEndpointMode {
            return diagnosticWebSocketURL
        }
        let env = ProcessInfo.processInfo.environment[websocketEnvKey]
        let candidate = env?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let candidate, !candidate.isEmpty, let url = URL(string: candidate) {
            return url
        }
        return deriveWebSocketURL(from: backendBaseURL)
    }

    static func printResolvedEndpoints() {
        print("[\(debugBuildMarker)] forceDiagnosticEndpointMode=\(forceDiagnosticEndpointMode)")
        print("[\(debugBuildMarker)] final base URL=\(backendBaseURL.absoluteString)")
        print("[\(debugBuildMarker)] final snapshot URL=\(snapshotURL.absoluteString)")
        print("[\(debugBuildMarker)] final runtime URL=\(runtimeURL.absoluteString)")
        print("[\(debugBuildMarker)] final ws URL=\(webSocketURL.absoluteString)")
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
