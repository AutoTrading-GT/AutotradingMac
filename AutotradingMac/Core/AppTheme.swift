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
    static let panelBorder = DesignTokens.Colors.borderSubtle.opacity(0.92)
    static let surfaceBorder = DesignTokens.Colors.borderSubtle.opacity(0.78)
    static let panelHighlight = Color.white.opacity(0.045)
    static let panelShadow = Color.black.opacity(0.22)
}

extension View {
    func appPanelStyle(cornerRadius: CGFloat = DesignTokens.Radius.xl) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                AppTheme.panelBackground.opacity(0.98),
                                DesignTokens.Colors.bgElevated.opacity(0.88),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.panelBorder, lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.panelHighlight, .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .shadow(color: AppTheme.panelShadow, radius: 8, x: 0, y: 3)
    }

    func appSurfaceStyle(cornerRadius: CGFloat = DesignTokens.Radius.xl) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(DesignTokens.Colors.surface1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.surfaceBorder, lineWidth: 1)
            )
    }

    func appToolbarChrome(cornerRadius: CGFloat = DesignTokens.Radius.xxl) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                DesignTokens.Colors.surface2.opacity(0.82),
                                DesignTokens.Colors.surface1.opacity(0.72),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.95), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 6, x: 0, y: 2)
    }
}
