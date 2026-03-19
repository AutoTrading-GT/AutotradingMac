//
//  SettingsView.swift
//  AutotradingMac
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title3.bold())
                Text("읽기 전용 연결 정보/런타임 기본 정보 페이지")
                    .foregroundStyle(.secondary)

                connectionSection
                runtimeSection
                strategyPlaceholderSection
            }
            .padding()
        }
        .navigationTitle("Settings")
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Backend / Connection")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Backend Base URL").foregroundStyle(.secondary)
                    Text(AppConfig.backendBaseURL.absoluteString).textSelection(.enabled)
                }
                GridRow {
                    Text("WebSocket URL").foregroundStyle(.secondary)
                    Text(AppConfig.webSocketURL.absoluteString).textSelection(.enabled)
                }
            }
            Text("연결 상태 확인/재연결/스냅샷 강제 갱신은 Dev 화면에서 수행합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var runtimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("App Runtime")
                .font(.headline)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("App Version").foregroundStyle(.secondary)
                    Text(appVersion)
                }
                GridRow {
                    Text("App Status").foregroundStyle(.secondary)
                    Text(store.runtime?.appStatus ?? "-")
                }
                GridRow {
                    Text("Execution Mode").foregroundStyle(.secondary)
                    Text(store.runtime?.executionMode ?? "-")
                }
                GridRow {
                    Text("Environment").foregroundStyle(.secondary)
                    Text(store.runtime?.env ?? "-")
                }
                GridRow {
                    Text("Active WS Clients").foregroundStyle(.secondary)
                    Text("\(store.runtime?.activeWsClients ?? 0)")
                }
            }
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var strategyPlaceholderSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Strategy Settings")
                .font(.headline)
            Text("향후 전략/리스크 파라미터 설정 화면이 들어올 예정입니다. (현재 placeholder)")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }
}
