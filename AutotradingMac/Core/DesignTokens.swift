//
//  DesignTokens.swift
//  AutotradingMac
//
//  Mapping source:
//  - design_ref/figma_web_export/src/styles/theme.css (.dark tokens)
//

import SwiftUI

enum DesignTokens {
    enum Colors {
        // Base surfaces
        static let bgBase = Color(rgb: 0x191A1F)
        static let bgElevated = Color(rgb: 0x1F2026)
        static let bgSidebar = Color(rgb: 0x17181C)
        static let bgToolbar = Color(rgb: 0x1A1A1E, opacity: 0.85)

        // Panel/surfaces with alpha
        static let bgPanel = Color(rgb: 0x24252C, opacity: 0.90)
        static let bgPanelHover = Color(rgb: 0x2B2D36, opacity: 0.93)
        static let surface1 = Color.white.opacity(0.028)
        static let surface2 = Color.white.opacity(0.045)
        static let surface3 = Color.white.opacity(0.070)

        // Text
        static let textPrimary = Color.white.opacity(0.95)
        static let textSecondary = Color.white.opacity(0.65)
        static let textTertiary = Color.white.opacity(0.45)
        static let textQuaternary = Color.white.opacity(0.28)

        // Borders
        static let borderSubtle = Color.white.opacity(0.06)
        static let borderMedium = Color.white.opacity(0.10)
        static let borderStrong = Color.white.opacity(0.15)

        // Accent + semantic
        static let accent = Color(rgb: 0x7795BC)
        static let accentMuted = Color(rgb: 0x7795BC, opacity: 0.15)
        static let accentSubtle = Color(rgb: 0x7795BC, opacity: 0.08)

        static let success = Color(rgb: 0x76B790)
        static let successBackground = Color(rgb: 0x76B790, opacity: 0.12)
        static let successMuted = Color(rgb: 0x76B790, opacity: 0.70)

        static let danger = Color(rgb: 0xEB7F86)
        static let dangerBackground = Color(rgb: 0xEB7F86, opacity: 0.12)
        static let dangerMuted = Color(rgb: 0xEB7F86, opacity: 0.70)

        static let warning = Color(rgb: 0xEAB367)
        static let warningBackground = Color(rgb: 0xEAB367, opacity: 0.12)
        static let warningMuted = Color(rgb: 0xEAB367, opacity: 0.70)

        static let info = Color(rgb: 0x82AACF)
        static let infoBackground = Color(rgb: 0x82AACF, opacity: 0.12)

        // Trading semantic
        static let profit = Color(rgb: 0xEB7F86)
        static let loss = Color(rgb: 0x82AACF)
    }

    enum Spacing {
        // 8px base rhythm from theme.css
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x5: CGFloat = 20
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
        static let x10: CGFloat = 40
        static let x12: CGFloat = 48
        static let x16: CGFloat = 64
    }

    enum Layout {
        static let pagePadding: CGFloat = 14
        static let sectionGap: CGFloat = 16
        static let panelInnerPadding: CGFloat = 12
        static let rowHorizontalPadding: CGFloat = 12
        static let rowVerticalPadding: CGFloat = 8
    }

    enum Radius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 6
        static let md: CGFloat = 8
        static let lg: CGFloat = 10
        static let xl: CGFloat = 12
        static let xxl: CGFloat = 14
    }

    enum Typography {
        static let baseSize: CGFloat = 16
        static let weightNormal: Font.Weight = .regular
        static let weightMedium: Font.Weight = .medium

        static let title = Font.system(size: 20, weight: .semibold)
        static let sectionTitle = Font.system(size: 16, weight: .semibold)
        static let body = Font.system(size: 14, weight: .regular)
        static let bodyStrong = Font.system(size: 14, weight: .medium)
        static let caption = Font.system(size: 12, weight: .medium)
        static let caption2 = Font.system(size: 11, weight: .regular)
    }

    enum Shadows {
        // theme.css shadow token reference:
        // --shadow-sm: 0 1px 2px rgba(0,0,0,0.2)
        // --shadow-md: 0 2px 8px rgba(0,0,0,0.25), 0 1px 2px rgba(0,0,0,0.15)
        // --shadow-lg: 0 4px 16px rgba(0,0,0,0.3), 0 2px 4px rgba(0,0,0,0.2)
        static let cardBase = Color.black.opacity(0.25)
        static let cardEmphasis = Color.black.opacity(0.30)
    }
}

private extension Color {
    init(rgb: UInt32, opacity: Double = 1.0) {
        let red = Double((rgb >> 16) & 0xFF) / 255.0
        let green = Double((rgb >> 8) & 0xFF) / 255.0
        let blue = Double(rgb & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}
