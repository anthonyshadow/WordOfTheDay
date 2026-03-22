import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ProfileViewModel

    init(viewModel: ProfileViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                HStack {
                    Text("Profile")
                        .font(LDTypography.title())
                    Spacer()
                    Button("Settings") {
                        appState.path.append(.settings)
                    }
                    .font(LDTypography.caption())
                }

                content
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $viewModel.isEditingProfile) {
            NavigationStack {
                Form {
                    Section("Profile") {
                        TextField("Display name", text: $viewModel.editDisplayName)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()

                        Picker("Primary language", selection: selectedLanguageID) {
                            ForEach(viewModel.availableLanguages) { language in
                                Text(language.name).tag(Optional(language.id))
                            }
                        }

                        Picker("Learning goal", selection: $viewModel.editLearningGoal) {
                            ForEach(LearningGoal.allCases, id: \.self) { goal in
                                Text(goal.title).tag(goal)
                            }
                        }

                        Picker("Level", selection: $viewModel.editLevel) {
                            ForEach(LearningLevel.allCases, id: \.self) { level in
                                Text(level.title).tag(level)
                            }
                        }
                    }

                    if let editError = viewModel.editError {
                        Section {
                            LDErrorStateView(error: editError) {
                                viewModel.clearEditError()
                            }
                        }
                    }
                }
                .navigationTitle("Edit Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            viewModel.dismissProfileEditor()
                        }
                    }

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await viewModel.saveProfile() }
                        }
                        .disabled(viewModel.isSavingProfile || viewModel.editDisplayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LDLoadingStateView(title: "Loading profile")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            LDEmptyStateView(title: "No profile", subtitle: "Sign in to continue.", actionTitle: nil, action: nil)
        case let .success(state):
            let profile = state.profile
            let progress = state.progress

            LDCard {
                VStack(spacing: LDSpacing.sm) {
                    Text(String(profile.displayName.prefix(1)))
                        .font(LDTypography.title())
                        .foregroundStyle(.white)
                        .frame(width: 72, height: 72)
                        .background(LDColor.accent)
                        .clipShape(Circle())
                    Text(profile.displayName)
                        .font(LDTypography.section())
                    Text("Learning \(profile.activeLanguage?.name ?? "Language") since \(profile.joinedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(LDTypography.caption())
                        .foregroundStyle(LDColor.inkSecondary)
                        .multilineTextAlignment(.center)

                    Button("Edit Profile") {
                        Task { await viewModel.beginEditingProfile() }
                    }
                    .buttonStyle(LDSecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }

            infoRow(title: "Primary language", value: profile.activeLanguage?.name ?? "Not set")
            infoRow(title: "Current level", value: profile.level.title)
            infoRow(title: "Daily time", value: profile.reminderTime.formatted(date: .omitted, time: .shortened))
            infoRow(title: "Plan", value: appState.subscriptionState.tier == .premium ? "Premium" : "Free")
            infoRow(
                title: "Achievement summary",
                value: "\(progress.currentStreakDays)-day streak • \(progress.wordsLearned) words learned"
            )

            Button(appState.subscriptionState.tier == .premium ? "Manage subscription" : "Upgrade to premium") {
                appState.path.append(.paywall)
            }
            .buttonStyle(LDPrimaryButtonStyle())
        }
    }

    private var selectedLanguageID: Binding<UUID?> {
        Binding(
            get: { viewModel.editSelectedLanguage?.id },
            set: { languageID in
                viewModel.editSelectedLanguage = viewModel.availableLanguages.first(where: { $0.id == languageID })
            }
        )
    }

    @ViewBuilder
    private func infoRow(title: String, value: String) -> some View {
        LDListRow {
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text(title)
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)
                Text(value)
                    .font(LDTypography.bodyBold())
            }
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return ProfileView(
        viewModel: ProfileViewModel(
            progressService: dependencies.progressService,
            onboardingService: dependencies.onboardingService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService,
            appState: dependencies.appState
        )
    )
    .environmentObject(dependencies.appState)
}
