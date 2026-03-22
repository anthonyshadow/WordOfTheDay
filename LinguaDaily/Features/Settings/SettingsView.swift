import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var appState: AppState
    @Environment(\.openURL) private var openURL
    @State private var showDeleteConfirmation = false

    init(viewModel: SettingsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                Text("Settings")
                    .font(LDTypography.title())

                content
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
        .alert("Delete account?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await viewModel.deleteAccount() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action is permanent and removes your LinguaDaily account data.")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LDLoadingStateView(title: "Loading settings")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            LDEmptyStateView(title: "No settings", subtitle: "Try again later.", actionTitle: nil, action: nil)
        case let .success(state):
            LDListRow {
                Toggle(isOn: Binding(
                    get: { state.notificationPreference.isEnabled },
                    set: { newValue in Task { await viewModel.toggleNotifications(newValue) } }
                )) {
                    Text("Notifications")
                        .font(LDTypography.bodyBold())
                }
            }

            LDCard {
                DatePicker(
                    "Reminder time",
                    selection: Binding(
                        get: { viewModel.reminder },
                        set: { newValue in
                            viewModel.reminder = newValue
                            Task { await viewModel.updateReminder(newValue) }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.compact)
            }

            Menu {
                Button("Default") {
                    Task { await viewModel.updatePreferredAccent(nil) }
                }
                ForEach(state.availableAccents, id: \.self) { accent in
                    Button(accent.capitalized) {
                        Task { await viewModel.updatePreferredAccent(accent) }
                    }
                }
            } label: {
                settingsRow(title: "Preferred accent", value: state.profile.preferredAccent?.capitalized ?? "Default")
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(DailyLearningMode.allCases, id: \.self) { mode in
                    Button(mode.title) {
                        Task { await viewModel.updateDailyLearningMode(mode) }
                    }
                }
            } label: {
                settingsRow(title: "Daily learning mode", value: state.profile.dailyLearningMode.title)
            }
            .buttonStyle(.plain)

            Menu {
                ForEach(AppearancePreference.allCases, id: \.self) { appearance in
                    Button(appearance.title) {
                        Task { await viewModel.updateAppearance(appearance) }
                    }
                }
            } label: {
                settingsRow(title: "Appearance", value: state.profile.appearancePreference.title)
            }
            .buttonStyle(.plain)

            settingsRow(
                title: "Pronunciation speed",
                value: appState.subscriptionState.tier == .premium ? "Normal + slow" : "Normal"
            )

            Button {
                appState.path.append(.paywall)
            } label: {
                settingsRow(title: "Manage subscription", value: appState.subscriptionState.tier == .premium ? "Premium" : "Free")
            }
            .buttonStyle(.plain)

            Button {
                if let url = URL(string: "https://linguadaily.app/privacy") {
                    openURL(url)
                }
            } label: {
                settingsRow(title: "Privacy", value: "Privacy policy")
            }
            .buttonStyle(.plain)

            Button {
                if let url = URL(string: "mailto:support@linguadaily.app?subject=LinguaDaily%20Feedback") {
                    openURL(url)
                }
            } label: {
                settingsRow(title: "Help and feedback", value: "Email support")
            }
            .buttonStyle(.plain)

            Button("Log out") {
                Task { await viewModel.logOut() }
            }
            .buttonStyle(LDSecondaryButtonStyle())

            Button("Delete account") {
                showDeleteConfirmation = true
            }
            .buttonStyle(LDSecondaryButtonStyle())
            .tint(LDColor.danger)

            #if DEBUG
            LDCard {
                VStack(alignment: .leading, spacing: LDSpacing.sm) {
                    Text("Debug")
                        .font(LDTypography.section())

                    Text("Send a handled test event to Sentry without crashing the app.")
                        .font(LDTypography.caption())
                        .foregroundStyle(LDColor.inkSecondary)

                    Button("Send Sentry test event") {
                        viewModel.sendSentryTestEvent()
                    }
                    .buttonStyle(LDSecondaryButtonStyle())

                    if let statusMessage = viewModel.sentryTestStatusMessage {
                        Text(statusMessage)
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)
                    }
                }
            }
            #endif
        }
    }

    @ViewBuilder
    private func settingsRow(title: String, value: String) -> some View {
        LDListRow {
            HStack {
                Text(title)
                    .font(LDTypography.body())
                Spacer()
                Text(value)
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)
            }
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return SettingsView(
        viewModel: SettingsViewModel(
            notificationService: dependencies.notificationService,
            progressService: dependencies.progressService,
            authService: dependencies.authService,
            onboardingService: dependencies.onboardingService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService,
            appState: dependencies.appState
        )
    )
    .environmentObject(dependencies.appState)
}
