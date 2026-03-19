//
//  GlobalTopBarView.swift
//  AutotradingMac
//

import SwiftUI

struct GlobalTopBarView: View {
    @EnvironmentObject private var store: MonitoringStore

    let currentPageTitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: Date(), by: 30)) { _ in
                HStack(alignment: .center, spacing: 12) {
                    Text(currentPageTitle)
                        .font(.title3.bold())

                    Spacer(minLength: 12)

                    Label("자동매매", systemImage: "bolt.horizontal.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusBadge(text: automationStatusText, tone: automationStatusTone)

                    Divider()
                        .frame(height: 16)

                    Label("장 상태", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    StatusBadge(text: marketStatusText, tone: marketStatusTone)

                    Divider()
                        .frame(height: 16)

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.secondary)
                        Text(lastUpdatedRelativeText)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                }
            }

            HStack(spacing: 8) {
                Button("시작") {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                Button("일시정지") {}
                    .buttonStyle(.bordered)
                    .disabled(true)
                Button("긴급 정지", role: .destructive) {}
                    .buttonStyle(.bordered)
                    .disabled(true)

                Text("제어 기능 미연결 (UI placeholder)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
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
