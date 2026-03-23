//
//  MonitoringWebSocketClient.swift
//  AutotradingMac
//

import Foundation

enum WebSocketConnectionState: String {
    case disconnected
    case connecting
    case connected
    case reconnecting
    case failed
}

final class MonitoringWebSocketClient {
    private let session: URLSession
    private let urlProvider: () -> URL
    private var task: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var shouldReconnect = false
    private var reconnectAttempt = 0

    var onStateChange: ((WebSocketConnectionState) -> Void)?
    var onEvent: ((EventEnvelope) -> Void)?
    var onError: ((String) -> Void)?

    init(
        session: URLSession = .shared,
        url: URL? = nil
    ) {
        self.session = session
        self.urlProvider = { url ?? AppConfig.webSocketURL }
    }

    func connect() {
        guard task == nil else { return }
        shouldReconnect = true
        reconnectTask?.cancel()
        reconnectTask = nil
        let url = urlProvider()
        print("[MonitoringWebSocketClient] connect attempt url=\(url.absoluteString)")
        onStateChange?(.connecting)

        let task = session.webSocketTask(with: url)
        self.task = task
        task.resume()
        reconnectAttempt = 0
        print("[MonitoringWebSocketClient] open url=\(url.absoluteString)")
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        cleanupConnection(emitStateChange: true)
    }

    private func cleanupConnection(emitStateChange: Bool) {
        receiveTask?.cancel()
        receiveTask = nil
        if let task {
            print("[MonitoringWebSocketClient] close code=\(task.closeCode.rawValue) reason=\(closeReasonText(task.closeReason))")
            task.cancel(with: .normalClosure, reason: nil)
        } else {
            print("[MonitoringWebSocketClient] close code=<no-task> reason=<no-task>")
        }
        task = nil
        if emitStateChange {
            onStateChange?(.disconnected)
        }
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
                onStateChange?(.failed)
                cleanupConnection(emitStateChange: false)
                scheduleReconnect()
                break
            }
        }
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

    private func scheduleReconnect() {
        guard shouldReconnect else { return }
        guard reconnectTask == nil else { return }
        reconnectAttempt += 1
        let delayNanoseconds = min(UInt64(reconnectAttempt), 5) * 1_000_000_000
        onStateChange?(.reconnecting)
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanoseconds)
            guard let self, !Task.isCancelled else { return }
            self.reconnectTask = nil
            self.connect()
        }
    }
}
