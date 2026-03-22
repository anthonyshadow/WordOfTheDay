import SwiftUI

struct AuthView: View {
    @StateObject private var viewModel: AuthViewModel

    init(viewModel: AuthViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LDSpacing.md) {
                Text("Welcome back")
                    .font(LDTypography.title())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("Continue with Apple") {
                    Task { await viewModel.signInWithApple() }
                }
                .buttonStyle(LDSecondaryButtonStyle())

                Button("Continue with Google") {
                    Task { await viewModel.signInWithGoogle() }
                }
                .buttonStyle(LDSecondaryButtonStyle())

                Text("or")
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)

                LDCard {
                    VStack(alignment: .leading, spacing: LDSpacing.sm) {
                        if viewModel.isSignup {
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

                Button(viewModel.isSignup ? "Create account" : "Log in") {
                    Task { await viewModel.submitEmail() }
                }
                .buttonStyle(LDPrimaryButtonStyle())
                .disabled(!viewModel.isValid)
                .opacity(viewModel.isValid ? 1 : 0.5)

                Button(viewModel.isSignup ? "Already have an account? Log in" : "Need an account? Sign up") {
                    viewModel.isSignup.toggle()
                }
                .font(LDTypography.caption())
                .foregroundStyle(LDColor.inkSecondary)

                if case .loading = viewModel.phase {
                    ProgressView()
                }

                if case .failure(let error) = viewModel.phase {
                    LDErrorStateView(error: error) {
                        viewModel.phase = .idle
                    }
                }
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .task {
            viewModel.onAppear()
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return AuthView(
        viewModel: AuthViewModel(
            authService: dependencies.authService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService,
            appState: dependencies.appState
        )
    )
}
