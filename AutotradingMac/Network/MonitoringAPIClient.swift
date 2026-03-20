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

    init(
        session: URLSession = .shared,
        snapshotURL: URL = AppConfig.snapshotURL,
        runtimeURL: URL = AppConfig.runtimeURL,
        engineStartURL: URL = AppConfig.engineStartURL,
        enginePauseURL: URL = AppConfig.enginePauseURL,
        engineEmergencyStopURL: URL = AppConfig.engineEmergencyStopURL,
        engineClearEmergencyStopURL: URL = AppConfig.engineClearEmergencyStopURL
    ) {
        self.session = session
        self.snapshotURL = snapshotURL
        self.runtimeURL = runtimeURL
        self.engineStartURL = engineStartURL
        self.enginePauseURL = enginePauseURL
        self.engineEmergencyStopURL = engineEmergencyStopURL
        self.engineClearEmergencyStopURL = engineClearEmergencyStopURL
    }

    func fetchSnapshot() async throws -> MonitoringSnapshotResponse {
        var request = URLRequest(url: snapshotURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try MonitoringCoding.decoder().decode(MonitoringSnapshotResponse.self, from: data)
    }

    func fetchRuntime() async throws -> RuntimeStatusSnapshot {
        var request = URLRequest(url: runtimeURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        let envelope = try MonitoringCoding.decoder().decode(RuntimeStatusResponseEnvelope.self, from: data)
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
        return try MonitoringCoding.decoder().decode(EngineControlCommandResponse.self, from: data)
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
}
