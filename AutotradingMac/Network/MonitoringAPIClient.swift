//
//  MonitoringAPIClient.swift
//  AutotradingMac
//

import Foundation

protocol MonitoringAPIClientProtocol {
    func fetchSnapshot() async throws -> MonitoringSnapshotResponse
    func fetchRuntime() async throws -> RuntimeStatusSnapshot
    func startEngine() async throws -> EngineControlCommandResponse
    func pauseEngine() async throws -> EngineControlCommandResponse
    func emergencyStopEngine() async throws -> EngineControlCommandResponse
    func clearEmergencyStop() async throws -> EngineControlCommandResponse
    func setOrderMode(_ mode: String, confirmLive: Bool) async throws -> EngineModeCommandResponse
    func setAccountMode(_ mode: String) async throws -> EngineModeCommandResponse
}

enum MonitoringAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int, String?)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response."
        case .httpStatus(let statusCode, let detail):
            if let detail, !detail.isEmpty {
                return "Monitoring API failed with HTTP \(statusCode): \(detail)"
            }
            return "Monitoring API failed with HTTP \(statusCode)."
        }
    }
}

final class MonitoringAPIClient: MonitoringAPIClientProtocol {
    private let session: URLSession
    private let snapshotURL: URL
    private let runtimeURL: URL
    private let engineStartURL: URL
    private let enginePauseURL: URL
    private let engineEmergencyStopURL: URL
    private let engineClearEmergencyStopURL: URL
    private let engineOrderModeURL: URL
    private let engineAccountModeURL: URL

    init(
        session: URLSession = .shared,
        snapshotURL: URL = AppConfig.snapshotURL,
        runtimeURL: URL = AppConfig.runtimeURL,
        engineStartURL: URL = AppConfig.engineStartURL,
        enginePauseURL: URL = AppConfig.enginePauseURL,
        engineEmergencyStopURL: URL = AppConfig.engineEmergencyStopURL,
        engineClearEmergencyStopURL: URL = AppConfig.engineClearEmergencyStopURL,
        engineOrderModeURL: URL = AppConfig.engineOrderModeURL,
        engineAccountModeURL: URL = AppConfig.engineAccountModeURL
    ) {
        self.session = session
        self.snapshotURL = snapshotURL
        self.runtimeURL = runtimeURL
        self.engineStartURL = engineStartURL
        self.enginePauseURL = enginePauseURL
        self.engineEmergencyStopURL = engineEmergencyStopURL
        self.engineClearEmergencyStopURL = engineClearEmergencyStopURL
        self.engineOrderModeURL = engineOrderModeURL
        self.engineAccountModeURL = engineAccountModeURL
    }

    func fetchSnapshot() async throws -> MonitoringSnapshotResponse {
        var request = URLRequest(url: snapshotURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        logRequest(request, context: "snapshot")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "snapshot",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            MonitoringSnapshotResponse.self,
            from: data,
            context: "GET /api/monitoring/snapshot"
        )
    }

    func fetchRuntime() async throws -> RuntimeStatusSnapshot {
        var request = URLRequest(url: runtimeURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        logRequest(request, context: "runtime")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "runtime",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        let envelope = try decodeModel(
            RuntimeStatusResponseEnvelope.self,
            from: data,
            context: "GET /api/monitoring/runtime"
        )
        return envelope.data
    }

    func startEngine() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: engineStartURL)
    }

    func pauseEngine() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: enginePauseURL)
    }

    func emergencyStopEngine() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: engineEmergencyStopURL)
    }

    func clearEmergencyStop() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: engineClearEmergencyStopURL)
    }

    func setOrderMode(_ mode: String, confirmLive: Bool) async throws -> EngineModeCommandResponse {
        try await sendModeCommand(
            to: engineOrderModeURL,
            mode: mode,
            confirmLive: confirmLive
        )
    }

    func setAccountMode(_ mode: String) async throws -> EngineModeCommandResponse {
        try await sendModeCommand(
            to: engineAccountModeURL,
            mode: mode,
            confirmLive: false
        )
    }

    private func sendEngineCommand(to url: URL) async throws -> EngineControlCommandResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            EngineControlCommandResponse.self,
            from: data,
            context: "POST \(url.path)"
        )
    }

    private func sendModeCommand(
        to url: URL,
        mode: String,
        confirmLive: Bool
    ) async throws -> EngineModeCommandResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["mode": mode, "confirm_live": confirmLive] as [String : Any]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            EngineModeCommandResponse.self,
            from: data,
            context: "POST \(url.path)"
        )
    }

    private func decodeModel<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        context: String
    ) throws -> T {
        do {
            return try MonitoringCoding.decoder().decode(type, from: data)
        } catch let decodingError as DecodingError {
            logDecodingError(decodingError, data: data, context: context)
            throw decodingError
        } catch {
            let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[MonitoringAPIClient] decode failed (\(context)): \(error.localizedDescription)\nbody=\(body.prefix(800))")
            throw error
        }
    }

    private func logDecodingError(_ error: DecodingError, data: Data, context: String) {
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        switch error {
        case .typeMismatch(let type, let debug):
            print("[MonitoringAPIClient] typeMismatch (\(context)): type=\(type), path=\(codingPath(debug.codingPath)), desc=\(debug.debugDescription)")
        case .valueNotFound(let type, let debug):
            print("[MonitoringAPIClient] valueNotFound (\(context)): type=\(type), path=\(codingPath(debug.codingPath)), desc=\(debug.debugDescription)")
        case .keyNotFound(let key, let debug):
            print("[MonitoringAPIClient] keyNotFound (\(context)): key=\(key.stringValue), path=\(codingPath(debug.codingPath)), desc=\(debug.debugDescription)")
        case .dataCorrupted(let debug):
            print("[MonitoringAPIClient] dataCorrupted (\(context)): path=\(codingPath(debug.codingPath)), desc=\(debug.debugDescription)")
        @unknown default:
            print("[MonitoringAPIClient] unknown decoding error (\(context))")
        }
        print("[MonitoringAPIClient] response body (\(context))=\(body.prefix(800))")
    }

    private func codingPath(_ path: [CodingKey]) -> String {
        if path.isEmpty {
            return "<root>"
        }
        return path.map(\.stringValue).joined(separator: ".")
    }

    private func parseErrorDetail(from data: Data) -> String? {
        guard
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let detail = raw["detail"] as? String,
            !detail.isEmpty
        else {
            return nil
        }
        return detail
    }

    private func logRequest(_ request: URLRequest, context: String) {
        let method = request.httpMethod ?? "GET"
        let url = request.url?.absoluteString ?? "<nil-url>"
        print("[MonitoringAPIClient][\(context)] request \(method) \(url)")
    }

    private func logResponse(context: String, url: URL?, statusCode: Int, data: Data) {
        let requestURL = url?.absoluteString ?? "<nil-url>"
        let body = String(data: data, encoding: .utf8) ?? "<non-utf8>"
        print("[MonitoringAPIClient][\(context)] status=\(statusCode) url=\(requestURL)")
        print("[MonitoringAPIClient][\(context)] body=\(body.prefix(500))")
    }
}
