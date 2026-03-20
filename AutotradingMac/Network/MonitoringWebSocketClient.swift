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
        print("[MonitoringWebSocketClient] connect attempt url=\(url.absoluteString)")
        onStateChange?(.connecting)

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        print("[MonitoringWebSocketClient] open url=\(url.absoluteString)")
        onStateChange?(.connected)
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        if let task {
            print("[MonitoringWebSocketClient] close code=\(task.closeCode.rawValue) reason=\(closeReasonText(task.closeReason))")
            task.cancel(with: .normalClosure, reason: nil)
        } else {
            print("[MonitoringWebSocketClient] close code=<no-task> reason=<no-task>")
        }
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
                let closeCode = task.closeCode.rawValue
                let closeReason = closeReasonText(task.closeReason)
                print("[MonitoringWebSocketClient] error=\(error.localizedDescription) closeCode=\(closeCode) closeReason=\(closeReason)")
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

    private func closeReasonText(_ reasonData: Data?) -> String {
        guard let reasonData, !reasonData.isEmpty else {
            return "<none>"
        }
        return String(decoding: reasonData, as: UTF8.self)
    }
}
