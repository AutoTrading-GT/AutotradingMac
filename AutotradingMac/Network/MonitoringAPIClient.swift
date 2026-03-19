//
//  MonitoringAPIClient.swift
//  AutotradingMac
//

import Foundation

protocol MonitoringAPIClientProtocol {
    func fetchSnapshot() async throws -> MonitoringSnapshotResponse
}

enum MonitoringAPIError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid API response."
        case .httpStatus(let statusCode):
            return "Monitoring API failed with HTTP \(statusCode)."
        }
    }
}

final class MonitoringAPIClient: MonitoringAPIClientProtocol {
    private let session: URLSession
    private let snapshotURL: URL

    init(
        session: URLSession = .shared,
        snapshotURL: URL = AppConfig.snapshotURL
    ) {
        self.session = session
        self.snapshotURL = snapshotURL
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
            throw MonitoringAPIError.httpStatus(http.statusCode)
        }
        return try MonitoringCoding.decoder().decode(MonitoringSnapshotResponse.self, from: data)
    }
}
