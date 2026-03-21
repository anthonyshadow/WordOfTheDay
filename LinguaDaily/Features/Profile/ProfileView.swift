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
        case let .success(profile):
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

                    Button("Edit Profile") {}
                        .buttonStyle(LDSecondaryButtonStyle())
                }
                .frame(maxWidth: .infinity)
            }

            infoRow(title: "Primary language", value: profile.activeLanguage?.name ?? "Not set")
            infoRow(title: "Current level", value: profile.level.title)
            infoRow(title: "Daily time", value: profile.reminderTime.formatted(date: .omitted, time: .shortened))
            infoRow(title: "Plan", value: appState.subscriptionState.tier == .premium ? "Premium" : "Free")
            infoRow(title: "Achievement summary", value: "12-day streak • First 50 words")

            Button(appState.subscriptionState.tier == .premium ? "Manage subscription" : "Upgrade to premium") {
                appState.path.append(.paywall)
            }
            .buttonStyle(LDPrimaryButtonStyle())
        }
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
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService
        )
    )
    .environmentObject(dependencies.appState)
}
