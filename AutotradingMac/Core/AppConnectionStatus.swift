//
//  AppConnectionStatus.swift
//  AutotradingMac
//

import Foundation

enum AppConnectionStatusKind: String, Equatable {
    case initializing
    case connected
    case serverUnavailable
    case webSocketDisconnected
    case reconnecting
    case startupFailure
    case authenticationFailure
}

struct AppConnectionStatusSnapshot: Equatable {
    let kind: AppConnectionStatusKind
    let title: String
    let message: String
    let detail: String?

    var tone: StatusTone {
        switch kind {
        case .connected:
            return .success
        case .initializing, .reconnecting:
            return .warning
        case .serverUnavailable, .webSocketDisconnected:
            return .warning
        case .startupFailure, .authenticationFailure:
            return .danger
        }
    }

    var iconName: String {
        switch kind {
        case .connected:
            return "checkmark.circle.fill"
        case .initializing:
            return "arrow.triangle.2.circlepath.circle.fill"
        case .serverUnavailable:
            return "wifi.exclamationmark"
        case .webSocketDisconnected:
            return "bolt.horizontal.circle"
        case .reconnecting:
            return "arrow.clockwise.circle.fill"
        case .startupFailure:
            return "exclamationmark.triangle.fill"
        case .authenticationFailure:
            return "lock.trianglebadge.exclamationmark"
        }
    }

    var compactText: String {
        switch kind {
        case .connected:
            return "정상 연결"
        case .initializing:
            return "연결 확인 중"
        case .serverUnavailable:
            return "서버 연결 실패"
        case .webSocketDisconnected:
            return "실시간 연결 끊김"
        case .reconnecting:
            return "재연결 중"
        case .startupFailure:
            return "초기화 확인 필요"
        case .authenticationFailure:
            return "인증 확인 필요"
        }
    }

    var isHealthy: Bool {
        kind == .connected
    }
}

enum AppConnectionStatusResolver {
    static func resolve(
        isBackendConfigured: Bool,
        snapshotLoaded: Bool,
        isLoadingSnapshot: Bool,
        connectionState: WebSocketConnectionState,
        runtime: RuntimeStatusSnapshot?,
        lastErrorMessage: String?
    ) -> AppConnectionStatusSnapshot {
        guard isBackendConfigured else {
            return AppConnectionStatusSnapshot(
                kind: .serverUnavailable,
                title: "서버 주소 미설정",
                message: "연결할 서버 주소를 입력해 주세요.",
                detail: nil
            )
        }

        if let authDetail = firstMatchingDetail(
            in: [runtime?.startupError, runtime?.engineLastError, lastErrorMessage],
            where: isAuthenticationIssue
        ) {
            return AppConnectionStatusSnapshot(
                kind: .authenticationFailure,
                title: "인증 확인 필요",
                message: "인증에 실패했습니다. API 설정을 확인해 주세요.",
                detail: authDetail
            )
        }

        if let runtime, needsStartupAttention(runtime) {
            let detail = firstNonEmpty(runtime.startupError, runtime.engineLastError, runtime.engineMessage)
            return AppConnectionStatusSnapshot(
                kind: .startupFailure,
                title: "서버 초기화 확인 필요",
                message: "서버는 응답하지만 초기화가 완료되지 않았습니다.",
                detail: detail
            )
        }

        if !snapshotLoaded {
            if isLoadingSnapshot || connectionState == .connecting {
                return AppConnectionStatusSnapshot(
                    kind: .initializing,
                    title: "서버 연결 확인 중",
                    message: "서버 상태를 불러오고 있습니다.",
                    detail: nil
                )
            }

            return AppConnectionStatusSnapshot(
                kind: .serverUnavailable,
                title: "서버 연결 실패",
                message: "서버에 연결할 수 없습니다. 서버 주소와 실행 상태를 확인해 주세요.",
                detail: lastErrorMessage
            )
        }

        switch connectionState {
        case .connected:
            return AppConnectionStatusSnapshot(
                kind: .connected,
                title: "정상 연결",
                message: "서버와 실시간 연결이 모두 정상입니다.",
                detail: nil
            )
        case .connecting, .reconnecting:
            return AppConnectionStatusSnapshot(
                kind: .reconnecting,
                title: "재연결 중",
                message: "실시간 연결을 다시 시도하고 있습니다.",
                detail: lastErrorMessage
            )
        case .failed:
            return AppConnectionStatusSnapshot(
                kind: .webSocketDisconnected,
                title: "실시간 연결 끊김",
                message: "실시간 연결이 끊어졌습니다. 자동으로 다시 연결하는 중입니다.",
                detail: lastErrorMessage
            )
        case .disconnected:
            return AppConnectionStatusSnapshot(
                kind: .webSocketDisconnected,
                title: "실시간 연결 끊김",
                message: "실시간 연결이 끊어졌습니다. 다시 연결을 시도해 주세요.",
                detail: lastErrorMessage
            )
        }
    }

    private static func needsStartupAttention(_ runtime: RuntimeStatusSnapshot) -> Bool {
        if runtime.startupOk == false {
            return true
        }
        return runtime.readinessStatus.lowercased() != "ready"
    }

    private static func isAuthenticationIssue(_ detail: String) -> Bool {
        let normalized = detail.lowercased()
        return normalized.contains("401")
            || normalized.contains("403")
            || normalized.contains("unauthorized")
            || normalized.contains("forbidden")
            || normalized.contains("auth")
            || normalized.contains("credential")
            || normalized.contains("token")
            || normalized.contains("app key")
            || normalized.contains("secret")
    }

    private static func firstMatchingDetail(
        in details: [String?],
        where predicate: (String) -> Bool
    ) -> String? {
        details.compactMap { detail in
            guard let trimmed = detail?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return predicate(trimmed) ? trimmed : nil
        }.first
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        values.compactMap { value in
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }
            return trimmed
        }.first
    }
}
