//
//  ContentView.swift
//  AutotradingMac
//
//  Created by 한규탁 on 3/19/26.
//

import SwiftUI

private enum ConsoleWindowLayout {
    static let width: CGFloat = 1360
    static let height: CGFloat = 760
}

struct ContentView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        AppShellView()
            .frame(width: ConsoleWindowLayout.width, height: ConsoleWindowLayout.height)
            .background(AppTheme.windowBackground)
            .foregroundStyle(DesignTokens.Colors.textPrimary)
            .font(DesignTokens.Typography.body)
            .task {
                await store.start()
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(MonitoringStore())
}
