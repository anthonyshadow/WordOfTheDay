import SwiftUI

struct OnboardingFlowView: View {
    @StateObject private var viewModel: OnboardingViewModel

    init(viewModel: OnboardingViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: LDSpacing.lg) {
            if viewModel.step.rawValue > 0 {
                HStack {
                    Button {
                        viewModel.backTapped()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LDColor.inkSecondary)
                            .padding(10)
                            .background(LDColor.surface)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Spacer()
                }
            }

            stepContent

            if case .failure(let error) = viewModel.asyncPhase {
                LDErrorStateView(error: error) {
                    viewModel.asyncPhase = .idle
                }
            }

            if viewModel.step != .welcome && viewModel.step != .notifications && viewModel.step != .account {
                Button("Continue") {
                    viewModel.continueTapped()
                }
                .buttonStyle(LDPrimaryButtonStyle())
                .disabled(!viewModel.canContinue)
                .opacity(viewModel.canContinue ? 1 : 0.5)
                .accessibilityLabel("Continue")
            }
        }
        .padding(LDSpacing.lg)
        .background(LDColor.background.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.2), value: viewModel.step)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeStepView(
                onContinue: viewModel.continueTapped,
                onLogin: viewModel.jumpToLoginFromWelcome
            )
        case .goal:
            GoalSelectionStepView(viewModel: viewModel)
        case .language:
            LanguageSelectionStepView(viewModel: viewModel)
        case .level:
            LevelSelectionStepView(viewModel: viewModel)
        case .reminder:
            ReminderSelectionStepView(viewModel: viewModel)
        case .notifications:
            NotificationEducationStepView(viewModel: viewModel)
        case .account:
            AccountStepView(viewModel: viewModel)
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return OnboardingFlowView(
        viewModel: OnboardingViewModel(
            onboardingService: dependencies.onboardingService,
            authService: dependencies.authService,
            notificationService: dependencies.notificationService,
            analytics: dependencies.analyticsService,
            crashReporter: dependencies.crashService,
            appState: dependencies.appState
        )
    )
}
