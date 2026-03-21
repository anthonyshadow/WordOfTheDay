import SwiftUI

struct NotificationEducationStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: LDSpacing.lg) {
            VStack(spacing: LDSpacing.sm) {
                Image(systemName: "bell.badge")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(LDColor.accent)
                    .padding()
                    .background(LDColor.surfaceMuted)
                    .clipShape(Circle())

                Text(viewModel.step.title)
                    .font(LDTypography.title())
                    .multilineTextAlignment(.center)

                Text("Get one short lesson every day at the time you choose.")
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }

            LDCard {
                VStack(alignment: .leading, spacing: LDSpacing.xs) {
                    Text("Preview notification")
                        .font(LDTypography.overline())
                        .foregroundStyle(LDColor.inkSecondary)
                    Text("Your French word is ready: Bonjour")
                        .font(LDTypography.bodyBold())
                    Text("Tap to hear pronunciation and examples.")
                        .font(LDTypography.caption())
                        .foregroundStyle(LDColor.inkSecondary)
                }
            }

            VStack(spacing: LDSpacing.sm) {
                Button("Enable Notifications") {
                    Task {
                        await viewModel.requestNotifications()
                        viewModel.continueTapped()
                    }
                }
                .buttonStyle(LDPrimaryButtonStyle())

                Button("Not now") {
                    viewModel.skipNotifications()
                    viewModel.continueTapped()
                }
                .buttonStyle(LDSecondaryButtonStyle())
            }
        }
        .onAppear {
            viewModel.trackNotificationEducationViewed()
            viewModel.skipNotifications()
        }
    }
}
