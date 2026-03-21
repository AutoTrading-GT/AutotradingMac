//
//  AppControls.swift
//  AutotradingMac
//

import SwiftUI

struct AppSegmentedOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: String {
        "\(title)-\(String(describing: value))"
    }
}

struct AppSegmentedControl<Value: Hashable>: View {
    let options: [AppSegmentedOption<Value>]
    @Binding var selection: Value
    var minSegmentWidth: CGFloat = 0
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: 5) {
            ForEach(options) { option in
                let isSelected = option.value == selection
                Button {
                    selection = option.value
                } label: {
                    Text(option.title)
                        .font(DesignTokens.Typography.caption.weight(.semibold))
                        .foregroundStyle(isSelected ? DesignTokens.Colors.textPrimary : DesignTokens.Colors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(minWidth: minSegmentWidth)
                        .frame(height: height - 8)
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                .fill(isSelected ? DesignTokens.Colors.accentMuted.opacity(0.95) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                                .stroke(isSelected ? DesignTokens.Colors.accent.opacity(0.82) : Color.clear, lineWidth: 0.9)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .frame(height: height)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .fill(DesignTokens.Colors.surface1.opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
        )
    }
}

struct AppMenuOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String

    var id: String {
        "\(title)-\(String(describing: value))"
    }
}

struct AppMenuSelector<Value: Hashable>: View {
    let options: [AppMenuOption<Value>]
    @Binding var selection: Value
    var selectedTitle: String
    var width: CGFloat = 280

    var body: some View {
        Menu {
            ForEach(options) { option in
                Button(option.title) {
                    selection = option.value
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(selectedTitle)
                    .font(DesignTokens.Typography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Colors.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 6)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(DesignTokens.Colors.textSecondary)
            }
            .padding(.horizontal, 10)
            .frame(height: 32)
            .frame(width: width)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .fill(DesignTokens.Colors.surface1.opacity(0.92))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.lg, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
            )
        }
        .menuStyle(.borderlessButton)
    }
}

struct AppToolButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.caption.weight(.semibold))
            .foregroundStyle(DesignTokens.Colors.textSecondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .fill(DesignTokens.Colors.surface1.opacity(configuration.isPressed ? 0.95 : 0.75))
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md, style: .continuous)
                    .stroke(DesignTokens.Colors.borderSubtle.opacity(0.9), lineWidth: 0.9)
            )
    }
}

