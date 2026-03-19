//
//  AutotradingMacApp.swift
//  AutotradingMac
//
//  Created by 한규탁 on 3/19/26.
//

import SwiftUI

@main
struct AutotradingMacApp: App {
    @StateObject private var store = MonitoringStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onDisappear {
                    store.stop()
                }
        }
        .windowResizability(.contentSize)
    }
}
