//
//  ShepherdEmptyState.swift
//  Shepherd
//

import SwiftUI

struct ShepherdEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(ShepherdColors.liquidAccentSoft.opacity(0.8))

            Text(title)
                .font(ShepherdFont.headline(.semibold))
                .adaptiveTextPrimary()
                .multilineTextAlignment(.center)

            Text(message)
                .font(ShepherdFont.subheadline())
                .adaptiveTextSecondary()
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 16)
        .glassCard(padding: 0, cornerRadius: ShepherdRadius.extraLarge)
    }
}
