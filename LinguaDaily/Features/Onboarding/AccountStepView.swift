import SwiftUI

struct AccountStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: LDSpacing.md) {
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text(viewModel.step.stepLabel)
                    .font(LDTypography.overline())
                    .foregroundStyle(LDColor.inkSecondary)
                    .textCase(.uppercase)
                Text(viewModel.step.title)
                    .font(LDTypography.title())
                    .foregroundStyle(LDColor.inkPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Continue with Apple") {
                Task { await viewModel.signInWithApple() }
            }
            .buttonStyle(LDSecondaryButtonStyle())
            .accessibilityLabel("Continue with Apple")

            Button("Continue with Google") {
                Task { await viewModel.signInWithGoogle() }
            }
            .buttonStyle(LDSecondaryButtonStyle())
            .accessibilityLabel("Continue with Google")

            Text("or")
                .font(LDTypography.caption())
                .foregroundStyle(LDColor.inkSecondary)

            LDCard {
                VStack(alignment: .leading, spacing: LDSpacing.sm) {
                    if viewModel.isCreatingAccount {
                        Text("Full name")
                            .font(LDTypography.overline())
                            .foregroundStyle(LDColor.inkSecondary)
                        TextField("Your name", text: $viewModel.fullName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .font(LDTypography.body())

                        Divider()
                    }

                    Text("Email")
                        .font(LDTypography.overline())
                        .foregroundStyle(LDColor.inkSecondary)
                    TextField("name@email.com", text: $viewModel.email)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(LDTypography.body())

                    Divider()

                    Text("Password")
                        .font(LDTypography.overline())
                        .foregroundStyle(LDColor.inkSecondary)
                    SecureField("Minimum 6 characters", text: $viewModel.password)
                        .font(LDTypography.body())
                }
            }

            Button(viewModel.isCreatingAccount ? "Create account" : "Log in") {
                Task { await viewModel.submitEmailAuth() }
            }
            .buttonStyle(LDPrimaryButtonStyle())
            .disabled(!viewModel.canContinue)
            .opacity(viewModel.canContinue ? 1 : 0.5)

            Button(viewModel.isCreatingAccount ? "Already have an account? Log in" : "Need an account? Sign up") {
                viewModel.isCreatingAccount.toggle()
            }
            .font(LDTypography.caption())
            .foregroundStyle(LDColor.inkSecondary)

            HStack(spacing: LDSpacing.xs) {
                Link("Privacy", destination: URL(string: "https://linguadaily.app/privacy")!)
                Text("•")
                Link("Terms", destination: URL(string: "https://linguadaily.app/terms")!)
            }
            .font(LDTypography.caption())
            .foregroundStyle(LDColor.inkSecondary)

            if case .loading = viewModel.asyncPhase {
                ProgressView()
            }
        }
    }
}
