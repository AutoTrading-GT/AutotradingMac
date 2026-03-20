//
//  GlobalTopBarView.swift
//  AutotradingMac
//

import SwiftUI

struct GlobalTopBarView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            statusCluster
                .frame(maxWidth: .infinity, alignment: .leading)

            actionButtons
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            DesignTokens.Colors.surface2.opacity(0.95),
                            DesignTokens.Colors.surface1.opacity(0.90)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(DesignTokens.Colors.borderMedium.opacity(0.55), lineWidth: 0.5)
                .padding(0.5)
        )
        .shadow(color: DesignTokens.Shadows.cardBase.opacity(0.55), radius: 8, y: 3)
        .shadow(color: DesignTokens.Shadows.cardEmphasis.opacity(0.32), radius: 18, y: 8)
    }

    private var statusCluster: some View {
        TimelineView(.periodic(from: Date(), by: 30)) { _ in
            HStack(alignment: .center, spacing: 8) {
                toolbarInfoPill(
                    icon: "bolt.horizontal.circle.fill",
                    title: "자동매매",
                    value: automationStatusText,
                    tone: automationStatusTone
                )

                separatorPill

                toolbarInfoPill(
                    icon: "clock.fill",
                    title: "장 상태",
                    value: marketStatusText,
                    tone: marketStatusTone
                )

                separatorPill

                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                    Text(lastUpdatedRelativeText)
                        .lineLimit(1)
                }
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule(style: .continuous)
                        .fill(DesignTokens.Colors.surface1)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
                )
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var separatorPill: some View {
        RoundedRectangle(cornerRadius: 999, style: .continuous)
            .fill(DesignTokens.Colors.borderSubtle)
            .frame(width: 1, height: 18)
            .padding(.horizontal, 2)
    }

    private func toolbarInfoPill(icon: String, title: String, value: String, tone: StatusTone) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tone.foreground)
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
            Text(value)
                .font(DesignTokens.Typography.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Colors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(DesignTokens.Colors.surface1)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
        )
    }

    private var actionButtons: some View {
        HStack(spacing: 8) {
            Button {
            } label: {
                topActionLabel("시작", icon: "play.fill")
            }
            .buttonStyle(TopBarActionButtonStyle(tone: .start))
            .disabled(true)

            Button {
            } label: {
                topActionLabel("일시정지", icon: "pause.fill")
            }
            .buttonStyle(TopBarActionButtonStyle(tone: .pause))
            .disabled(true)

            Button(role: .destructive) {
            } label: {
                topActionLabel("긴급 정지", icon: "stop.fill")
            }
            .buttonStyle(TopBarActionButtonStyle(tone: .emergency))
                .disabled(true)
        }
    }

    private func topActionLabel(_ title: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
            Text(title)
                .font(DesignTokens.Typography.caption.weight(.semibold))
        }
        .frame(minWidth: 78)
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private var automationStatusText: String {
        guard let runtime = store.runtime else { return "자동매매 상태 확인 중" }
        let mode = runtime.executionMode.lowercased()
        let status = runtime.appStatus.lowercased()

        if status != "ready" {
            return "자동매매 점검 필요"
        }
        if mode == "disabled" {
            return "자동매매 대기 중"
        }
        if mode == "paper" || mode == "kis_virtual" {
            return "자동매매 실행 중"
        }
        return "자동매매 상태 확인 중"
    }

    private var automationStatusTone: StatusTone {
        if automationStatusText.contains("실행 중") { return .success }
        if automationStatusText.contains("점검") { return .warning }
        return .neutral
    }

    private var marketStatusText: String {
        let now = Date()
        let seoul = TimeZone(identifier: "Asia/Seoul") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = seoul

        let weekday = calendar.component(.weekday, from: now)
        if weekday == 1 || weekday == 7 {
            return "장 종료"
        }

        let open = marketDate(hour: 9, minute: 0, base: now, calendar: calendar)
        let close = marketDate(hour: 15, minute: 30, base: now, calendar: calendar)

        if now < open {
            return "장 시작까지 \(countdownText(from: now, to: open))"
        }
        if now < close {
            return "장 마감까지 \(countdownText(from: now, to: close))"
        }
        return "장 종료"
    }

    private var marketStatusTone: StatusTone {
        if marketStatusText.contains("마감까지") { return .success }
        if marketStatusText.contains("시작까지") { return .warning }
        return .neutral
    }

    private func marketDate(hour: Int, minute: Int, base: Date, calendar: Calendar) -> Date {
        let components = calendar.dateComponents([.year, .month, .day], from: base)
        return calendar.date(from: DateComponents(
            year: components.year,
            month: components.month,
            day: components.day,
            hour: hour,
            minute: minute
        )) ?? base
    }

    private func countdownText(from start: Date, to end: Date) -> String {
        let seconds = max(Int(end.timeIntervalSince(start)), 0)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)시간 \(minutes)분"
    }

    private var lastUpdatedRelativeText: String {
        guard let last = store.lastUpdatedAt else { return "업데이트 대기 중" }
        let delta = max(Int(Date().timeIntervalSince(last)), 0)
        if delta < 10 { return "방금 전" }
        if delta < 60 { return "\(delta)초 전" }
        if delta < 3600 { return "\(delta / 60)분 전" }
        return "\(delta / 3600)시간 전"
    }
}

private enum TopBarActionTone {
    case start
    case pause
    case emergency
}

private struct TopBarActionButtonStyle: ButtonStyle {
    let tone: TopBarActionTone

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foregroundColor(configuration: configuration))
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(backgroundFill(configuration: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(borderColor(configuration: configuration), lineWidth: 1)
            )
            .shadow(color: shadowColor(configuration: configuration), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private func foregroundColor(configuration: Configuration) -> Color {
        if !configuration.isPressed {
            switch tone {
            case .start:
                return DesignTokens.Colors.successMuted
            case .pause:
                return DesignTokens.Colors.warningMuted
            case .emergency:
                return DesignTokens.Colors.dangerMuted
            }
        }

        return DesignTokens.Colors.textPrimary.opacity(0.9)
    }

    private func backgroundFill(configuration: Configuration) -> LinearGradient {
        let pressedOpacity: Double = configuration.isPressed ? 0.85 : 1.0
        switch tone {
        case .start:
            return LinearGradient(
                colors: [
                    DesignTokens.Colors.successBackground.opacity(0.95 * pressedOpacity),
                    DesignTokens.Colors.surface1.opacity(0.9 * pressedOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .pause:
            return LinearGradient(
                colors: [
                    DesignTokens.Colors.warningBackground.opacity(0.95 * pressedOpacity),
                    DesignTokens.Colors.surface1.opacity(0.9 * pressedOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        case .emergency:
            return LinearGradient(
                colors: [
                    DesignTokens.Colors.dangerBackground.opacity(0.95 * pressedOpacity),
                    DesignTokens.Colors.surface1.opacity(0.9 * pressedOpacity)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func borderColor(configuration: Configuration) -> Color {
        switch tone {
        case .start:
            return DesignTokens.Colors.successBackground.opacity(configuration.isPressed ? 0.9 : 0.75)
        case .pause:
            return DesignTokens.Colors.warningBackground.opacity(configuration.isPressed ? 0.9 : 0.75)
        case .emergency:
            return DesignTokens.Colors.dangerBackground.opacity(configuration.isPressed ? 0.9 : 0.75)
        }
    }

    private func shadowColor(configuration: Configuration) -> Color {
        if configuration.isPressed {
            return .clear
        }
        switch tone {
        case .start:
            return DesignTokens.Colors.successBackground.opacity(0.35)
        case .pause:
            return DesignTokens.Colors.warningBackground.opacity(0.30)
        case .emergency:
            return DesignTokens.Colors.dangerBackground.opacity(0.32)
        }
    }
}
