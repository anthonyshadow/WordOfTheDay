import SwiftUI

struct LDLoadingStateView: View {
    let title: String

    var body: some View {
        LDCard {
            VStack(spacing: LDSpacing.sm) {
                ProgressView()
                Text(title)
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct LDEmptyStateView: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        LDCard {
            VStack(spacing: LDSpacing.sm) {
                Text(title)
                    .font(LDTypography.section())
                    .foregroundStyle(LDColor.inkPrimary)
                Text(subtitle)
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkSecondary)
                    .multilineTextAlignment(.center)
                if let actionTitle, let action {
                    Button(actionTitle, action: action)
                        .buttonStyle(LDPrimaryButtonStyle())
                        .accessibilityLabel(actionTitle)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct LDErrorStateView: View {
    let error: ViewError
    let retry: () -> Void

    var body: some View {
        LDCard {
            VStack(spacing: LDSpacing.sm) {
                Text(error.title)
                    .font(LDTypography.section())
                    .foregroundStyle(LDColor.danger)
                Text(error.message)
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkSecondary)
                    .multilineTextAlignment(.center)
                Button(error.actionTitle, action: retry)
                    .buttonStyle(LDPrimaryButtonStyle())
                    .accessibilityLabel(error.actionTitle)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
