//
//  MonitoringAPIClient.swift
//  AutotradingMac
//

import Foundation

protocol MonitoringAPIClientProtocol {
    func fetchSnapshot() async throws -> MonitoringSnapshotResponse
    func fetchRuntime() async throws -> RuntimeStatusSnapshot
    func fetchStrategySettings() async throws -> StrategySettingsResponseEnvelope
    func updateStrategySettings(_ payload: StrategySettingsUpdatePayload) async throws -> StrategySettingsResponseEnvelope
    func fetchAppSettings() async throws -> AppSettingsResponseEnvelope
    func updateAppSettings(_ payload: AppSettingsUpdatePayload) async throws -> AppSettingsUpdateResponseEnvelope
    func fetchScannerRanks(mode: String, limit: Int) async throws -> ScannerRanksResponse
    func fetchChartSeries(symbol: String, timeframe: ChartTimeframeOption, limit: Int) async throws -> ChartSeriesResponse
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
    private let snapshotURLProvider: () -> URL
    private let runtimeURLProvider: () -> URL
    private let strategySettingsURLProvider: () -> URL
    private let appSettingsURLProvider: () -> URL
    private let engineStartURLProvider: () -> URL
    private let enginePauseURLProvider: () -> URL
    private let engineEmergencyStopURLProvider: () -> URL
    private let engineClearEmergencyStopURLProvider: () -> URL
    private let engineOrderModeURLProvider: () -> URL
    private let engineAccountModeURLProvider: () -> URL

    init(
        session: URLSession = .shared,
        snapshotURL: URL? = nil,
        runtimeURL: URL? = nil,
        strategySettingsURL: URL? = nil,
        appSettingsURL: URL? = nil,
        engineStartURL: URL? = nil,
        enginePauseURL: URL? = nil,
        engineEmergencyStopURL: URL? = nil,
        engineClearEmergencyStopURL: URL? = nil,
        engineOrderModeURL: URL? = nil,
        engineAccountModeURL: URL? = nil
    ) {
        self.session = session
        self.snapshotURLProvider = { snapshotURL ?? AppConfig.snapshotURL }
        self.runtimeURLProvider = { runtimeURL ?? AppConfig.runtimeURL }
        self.strategySettingsURLProvider = { strategySettingsURL ?? AppConfig.strategySettingsURL }
        self.appSettingsURLProvider = { appSettingsURL ?? AppConfig.appSettingsURL }
        self.engineStartURLProvider = { engineStartURL ?? AppConfig.engineStartURL }
        self.enginePauseURLProvider = { enginePauseURL ?? AppConfig.enginePauseURL }
        self.engineEmergencyStopURLProvider = { engineEmergencyStopURL ?? AppConfig.engineEmergencyStopURL }
        self.engineClearEmergencyStopURLProvider = { engineClearEmergencyStopURL ?? AppConfig.engineClearEmergencyStopURL }
        self.engineOrderModeURLProvider = { engineOrderModeURL ?? AppConfig.engineOrderModeURL }
        self.engineAccountModeURLProvider = { engineAccountModeURL ?? AppConfig.engineAccountModeURL }
    }

    func fetchSnapshot() async throws -> MonitoringSnapshotResponse {
        var request = URLRequest(url: snapshotURLProvider())
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
        var request = URLRequest(url: runtimeURLProvider())
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

    func fetchStrategySettings() async throws -> StrategySettingsResponseEnvelope {
        var request = URLRequest(url: strategySettingsURLProvider())
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        logRequest(request, context: "strategy-settings")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "strategy-settings",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            StrategySettingsResponseEnvelope.self,
            from: data,
            context: "GET /api/monitoring/strategy-settings"
        )
    }

    func updateStrategySettings(_ payload: StrategySettingsUpdatePayload) async throws -> StrategySettingsResponseEnvelope {
        var request = URLRequest(url: strategySettingsURLProvider())
        request.httpMethod = "PATCH"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try MonitoringCoding.encoder().encode(payload)
        logRequest(request, context: "strategy-settings.patch")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "strategy-settings.patch",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            StrategySettingsResponseEnvelope.self,
            from: data,
            context: "PATCH /api/monitoring/strategy-settings"
        )
    }

    func fetchAppSettings() async throws -> AppSettingsResponseEnvelope {
        var request = URLRequest(url: appSettingsURLProvider())
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        logRequest(request, context: "app-settings")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "app-settings",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            AppSettingsResponseEnvelope.self,
            from: data,
            context: "GET /api/monitoring/app-settings"
        )
    }

    func updateAppSettings(_ payload: AppSettingsUpdatePayload) async throws -> AppSettingsUpdateResponseEnvelope {
        var request = URLRequest(url: appSettingsURLProvider())
        request.httpMethod = "PATCH"
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try MonitoringCoding.encoder().encode(payload)
        logRequest(request, context: "app-settings.patch")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "app-settings.patch",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            AppSettingsUpdateResponseEnvelope.self,
            from: data,
            context: "PATCH /api/monitoring/app-settings"
        )
    }

    func fetchChartSeries(
        symbol: String,
        timeframe: ChartTimeframeOption,
        limit: Int
    ) async throws -> ChartSeriesResponse {
        var request = URLRequest(url: AppConfig.chartSeriesURL(symbol: symbol, timeframe: timeframe, limit: limit))
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        logRequest(request, context: "chart")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "chart",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            ChartSeriesResponse.self,
            from: data,
            context: "GET /api/chart/{symbol}"
        )
    }

    func fetchScannerRanks(mode: String, limit: Int) async throws -> ScannerRanksResponse {
        var request = URLRequest(url: AppConfig.scannerRanksURL(mode: mode, limit: limit))
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        logRequest(request, context: "scanner-ranks")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MonitoringAPIError.invalidResponse
        }
        logResponse(
            context: "scanner-ranks",
            url: request.url,
            statusCode: http.statusCode,
            data: data
        )
        guard (200..<300).contains(http.statusCode) else {
            throw MonitoringAPIError.httpStatus(http.statusCode, parseErrorDetail(from: data))
        }
        return try decodeModel(
            ScannerRanksResponse.self,
            from: data,
            context: "GET /api/monitoring/scanner/ranks"
        )
    }

    func startEngine() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: engineStartURLProvider())
    }

    func pauseEngine() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: enginePauseURLProvider())
    }

    func emergencyStopEngine() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: engineEmergencyStopURLProvider())
    }

    func clearEmergencyStop() async throws -> EngineControlCommandResponse {
        try await sendEngineCommand(to: engineClearEmergencyStopURLProvider())
    }

    func setOrderMode(_ mode: String, confirmLive: Bool) async throws -> EngineModeCommandResponse {
        try await sendModeCommand(
            to: engineOrderModeURLProvider(),
            mode: mode,
            confirmLive: confirmLive
        )
    }

    func setAccountMode(_ mode: String) async throws -> EngineModeCommandResponse {
        try await sendModeCommand(
            to: engineAccountModeURLProvider(),
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
        if let raw = try? JSONSerialization.jsonObject(with: data) {
            if let object = raw as? [String: Any], let detail = object["detail"] {
                return stringify(detail)
            }
            return stringify(raw)
        }

        let plain = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let plain, !plain.isEmpty {
            return plain
        }
        return nil
    }

    private func stringify(_ value: Any) -> String? {
        if let string = value as? String {
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if JSONSerialization.isValidJSONObject(value),
           let data = try? JSONSerialization.data(withJSONObject: value, options: []),
           let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return "\(value)"
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
