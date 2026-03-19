//
//  MonitoringWebSocketClient.swift
//  AutotradingMac
//

import Foundation

enum WebSocketConnectionState: String {
    case disconnected
    case connecting
    case connected
    case error
}

final class MonitoringWebSocketClient {
    private let session: URLSession
    private let url: URL
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?

    var onStateChange: ((WebSocketConnectionState) -> Void)?
    var onEvent: ((EventEnvelope) -> Void)?
    var onError: ((String) -> Void)?

    init(
        session: URLSession = .shared,
        url: URL = AppConfig.webSocketURL
    ) {
        self.session = session
        self.url = url
    }

    func connect() {
        guard task == nil else { return }
        onStateChange?(.connecting)

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        onStateChange?(.connected)
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        onStateChange?(.disconnected)
    }

    private func receiveLoop() async {
        guard let task else { return }

        while !Task.isCancelled {
            do {
                let message = try await task.receive()
                switch message {
                case .string(let text):
                    try handleIncoming(data: Data(text.utf8))
                case .data(let data):
                    try handleIncoming(data: data)
                @unknown default:
                    continue
                }
            } catch {
                onError?("WebSocket receive failed: \(error.localizedDescription)")
                onStateChange?(.error)
                break
            }
        }

        disconnect()
    }

    private func handleIncoming(data: Data) throws {
        let envelope = try MonitoringCoding.decoder().decode(EventEnvelope.self, from: data)
        onEvent?(envelope)
    }
}
