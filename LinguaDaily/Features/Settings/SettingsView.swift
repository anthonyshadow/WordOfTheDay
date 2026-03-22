import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel
    @EnvironmentObject private var appState: AppState
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
        case let .success(preference):
            LDListRow {
                Toggle(isOn: Binding(
                    get: { preference.isEnabled },
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

            settingsRow(title: "Preferred accent", value: "Parisian")
            settingsRow(title: "Pronunciation speed", value: appState.subscriptionState.tier == .premium ? "Normal + slow" : "Normal")
            settingsRow(title: "Daily learning mode", value: "1 new word + review")
            settingsRow(title: "Appearance", value: "System")

            Button {
                appState.path.append(.paywall)
            } label: {
                settingsRow(title: "Manage subscription", value: appState.subscriptionState.tier == .premium ? "Premium" : "Free")
            }
            .buttonStyle(.plain)

            settingsRow(title: "Privacy", value: "Data and account")
            settingsRow(title: "Help and feedback", value: "Contact support")

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
            authService: dependencies.authService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService,
            appState: dependencies.appState
        )
    )
    .environmentObject(dependencies.appState)
}
