//
//  ContentView.swift
//  AutotradingMac
//
//  Created by 한규탁 on 3/19/26.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: MonitoringStore

    var body: some View {
        AppShellView()
            .task {
                await store.start()
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(MonitoringStore())
}
