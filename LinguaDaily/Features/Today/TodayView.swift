import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: TodayViewModel

    init(viewModel: TodayViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                header
                content
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: LDSpacing.xxs) {
            HStack {
                Text("Today")
                    .font(LDTypography.title())
                Spacer()
                Label("\(viewModel.currentStreakDays)", systemImage: "flame.fill")
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.warning)
                    .accessibilityLabel("Current streak \(viewModel.currentStreakDays)")
            }
            Text(Date.now.formatted(date: .abbreviated, time: .omitted))
                .font(LDTypography.caption())
                .foregroundStyle(LDColor.inkSecondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LDLoadingStateView(title: "Loading today's word")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            LDEmptyStateView(
                title: "No lesson yet",
                subtitle: "Come back soon for your next daily word.",
                actionTitle: "Refresh",
                action: { Task { await viewModel.load() } }
            )
        case let .success(lesson):
            if let audioError = viewModel.audioError {
                LDErrorStateView(error: audioError) {
                    viewModel.clearAudioError()
                }
            }

            if viewModel.reviewDueCount > 0 {
                LDCard(background: AnyShapeStyle(LDColor.accentSoft)) {
                    VStack(alignment: .leading, spacing: LDSpacing.sm) {
                        Text("Review due")
                            .font(LDTypography.overline())
                            .foregroundStyle(LDColor.inkSecondary)
                        Text("You have \(viewModel.reviewDueCount) review \(viewModel.reviewDueCount == 1 ? "card" : "cards") waiting.")
                            .font(LDTypography.body())
                        Button("Start Review") {
                            appState.selectedTab = .review
                        }
                        .buttonStyle(LDPrimaryButtonStyle())
                    }
                }
            }

            WordCardView(lesson: lesson) {
                Task { await viewModel.playPronunciation() }
            }

            if lesson.word.audio.isEmpty {
                LDEmptyStateView(
                    title: "Audio unavailable offline",
                    subtitle: "Reconnect and try pronunciation again.",
                    actionTitle: nil,
                    action: nil
                )
            }

            Text("Example sentences")
                .font(LDTypography.section())
            ForEach(lesson.word.examples) { sentence in
                SentenceCardView(sentence: sentence)
            }

            HStack(spacing: LDSpacing.sm) {
                Button(lesson.isLearned ? "Learned" : "Mark learned") {
                    Task { await viewModel.toggleLearned() }
                }
                .buttonStyle(LDSecondaryButtonStyle())

                Button(lesson.isSavedForReview ? "Saved" : "Save for review") {
                    Task { await viewModel.toggleSaveForReview() }
                }
                .buttonStyle(LDSecondaryButtonStyle())
            }

            HStack(spacing: LDSpacing.sm) {
                Button(lesson.isFavorited ? "Favorited" : "Favorite") {
                    Task { await viewModel.toggleFavorite() }
                }
                .buttonStyle(LDSecondaryButtonStyle())

                ShareLink(
                    item: "\(lesson.word.lemma): \(lesson.word.definition)",
                    subject: Text("LinguaDaily word")
                ) {
                    Text("Share")
                        .font(LDTypography.bodyBold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, LDSpacing.md)
                }
                .buttonStyle(LDSecondaryButtonStyle())
            }

            Button("Open word detail") {
                appState.path.append(.wordDetail(lesson.word))
            }
            .buttonStyle(LDPrimaryButtonStyle())
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return TodayView(
        viewModel: TodayViewModel(
            lessonService: dependencies.dailyLessonService,
            reviewService: dependencies.reviewService,
            progressService: dependencies.progressService,
            audioPlayer: dependencies.audioPlayerService,
            cacheStore: dependencies.cacheStore,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService
        )
    )
    .environmentObject(dependencies.appState)
}
