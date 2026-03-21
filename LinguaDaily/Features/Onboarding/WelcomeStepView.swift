import SwiftUI

struct WelcomeStepView: View {
    let onContinue: () -> Void
    let onLogin: () -> Void

    var body: some View {
        VStack(spacing: LDSpacing.lg) {
            LDCard(background: AnyShapeStyle(LDColor.cardWarm)) {
                VStack(alignment: .leading, spacing: LDSpacing.md) {
                    Text("LinguaDaily")
                        .font(LDTypography.overline())
                        .foregroundStyle(LDColor.inkSecondary)
                        .textCase(.uppercase)
                    Text("Learn a new word every day.")
                        .font(LDTypography.title())
                        .foregroundStyle(LDColor.inkPrimary)
                    Text("Pronunciation, meaning, examples, and smart review in under 2 minutes.")
                        .font(LDTypography.body())
                        .foregroundStyle(LDColor.inkSecondary)
                }
            }

            HStack(spacing: LDSpacing.sm) {
                FeatureTile(value: "1/day", label: "Daily Word")
                FeatureTile(value: "Native", label: "Audio")
                FeatureTile(value: "Smart", label: "Review")
            }

            Button("Get Started", action: onContinue)
                .buttonStyle(LDPrimaryButtonStyle())
                .accessibilityLabel("Get Started")

            Button("Log in", action: onLogin)
                .buttonStyle(LDSecondaryButtonStyle())
                .accessibilityLabel("Log in")
        }
    }
}

private struct FeatureTile: View {
    let value: String
    let label: String

    var body: some View {
        LDCard {
            VStack(spacing: LDSpacing.xxs) {
                Text(value)
                    .font(LDTypography.bodyBold())
                    .foregroundStyle(LDColor.inkPrimary)
                Text(label)
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
