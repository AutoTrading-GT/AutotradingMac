//
//  AppTheme.swift
//  AutotradingMac
//

import SwiftUI

enum AppTheme {
    static let windowBackground = DesignTokens.Colors.bgBase
    static let sidebarBackground = DesignTokens.Colors.bgSidebar
    static let contentBackground = DesignTokens.Colors.bgBase
    static let panelBackground = DesignTokens.Colors.bgPanel
    static let surfaceBackground = DesignTokens.Colors.surface1
}

extension View {
    func appPanelStyle(cornerRadius: CGFloat = DesignTokens.Radius.xl) -> some View {
        self
            .background(
                AppTheme.panelBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
            )
    }

    func appSurfaceStyle(cornerRadius: CGFloat = DesignTokens.Radius.xl) -> some View {
        self
            .background(
                AppTheme.surfaceBackground,
                in: RoundedRectangle(cornerRadius: cornerRadius)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(DesignTokens.Colors.borderSubtle, lineWidth: 1)
            )
    }
}
