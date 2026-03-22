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
                previewContent
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
        .task {
            await viewModel.loadNotificationPreviewIfNeeded()
        }
    }

    @ViewBuilder
    private var previewContent: some View {
        switch viewModel.notificationPreviewPhase {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text("Preview notification")
                    .font(LDTypography.overline())
                    .foregroundStyle(LDColor.inkSecondary)
                ProgressView()
            }
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.retryLoadingNotificationPreview() }
            }
        case .empty:
            EmptyView()
        case let .success(preview):
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text("Preview notification")
                    .font(LDTypography.overline())
                    .foregroundStyle(LDColor.inkSecondary)
                Text(preview.title)
                    .font(LDTypography.bodyBold())
                Text(preview.body)
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)
            }
        }
    }
}
