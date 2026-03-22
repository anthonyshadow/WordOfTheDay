import SwiftUI

struct WordDetailView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: WordDetailViewModel

    init(viewModel: WordDetailViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                if let actionError = viewModel.actionError {
                    LDErrorStateView(error: actionError) {
                        viewModel.clearActionError()
                    }
                }

                LDCard {
                    VStack(alignment: .leading, spacing: LDSpacing.sm) {
                        Text(viewModel.word.lemma)
                            .font(LDTypography.hero())
                        Text("\(viewModel.word.partOfSpeech) • \(viewModel.word.pronunciationIPA)")
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)

                        HStack(spacing: LDSpacing.sm) {
                            StatCardView(label: "CEFR", value: viewModel.word.cefrLevel)
                            StatCardView(label: "Frequency", value: "#\(viewModel.word.frequencyRank)")
                        }
                    }
                }

                LDCard(background: AnyShapeStyle(LDColor.surfaceMuted)) {
                    VStack(alignment: .leading, spacing: LDSpacing.xs) {
                        HStack {
                            Text("Status")
                                .font(LDTypography.caption())
                                .foregroundStyle(LDColor.inkSecondary)
                            Spacer()
                            if viewModel.isLoadingState {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Text(viewModel.progressState.status.title)
                                    .font(LDTypography.bodyBold())
                                    .foregroundStyle(LDColor.inkPrimary)
                            }
                        }

                        Text(statusSummary)
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)
                    }
                }

                HStack(spacing: LDSpacing.sm) {
                    Button(viewModel.progressState.isLearned ? "Learned" : "Mark learned") {
                        Task { await viewModel.toggleLearned() }
                    }
                    .buttonStyle(LDSecondaryButtonStyle())
                    .disabled(viewModel.isUpdating)

                    Button(viewModel.progressState.isSavedForReview ? "Saved" : "Save for review") {
                        Task { await viewModel.toggleSaveForReview() }
                    }
                    .buttonStyle(LDSecondaryButtonStyle())
                    .disabled(viewModel.isUpdating)
                }

                HStack(spacing: LDSpacing.sm) {
                    Button(viewModel.progressState.isFavorited ? "Favorited" : "Favorite") {
                        Task { await viewModel.toggleFavorite() }
                    }
                    .buttonStyle(LDSecondaryButtonStyle())
                    .disabled(viewModel.isUpdating)

                    ShareLink(
                        item: "\(viewModel.word.lemma): \(viewModel.word.definition)",
                        subject: Text("LinguaDaily word")
                    ) {
                        Text("Share")
                            .font(LDTypography.bodyBold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, LDSpacing.md)
                    }
                    .buttonStyle(LDSecondaryButtonStyle())
                }

                Text("How to pronounce it")
                    .font(LDTypography.section())

                if let audioError = viewModel.audioError {
                    LDErrorStateView(error: audioError) {
                        viewModel.clearAudioError()
                    }
                }

                if viewModel.word.audio.isEmpty {
                    Button {
                        Task { await viewModel.playPronunciation() }
                    } label: {
                        LDListRow {
                            HStack {
                                VStack(alignment: .leading, spacing: LDSpacing.xxs) {
                                    Text("Play pronunciation")
                                        .font(LDTypography.bodyBold())
                                    Text("Uses the device voice when no recorded audio is available.")
                                        .font(LDTypography.caption())
                                        .foregroundStyle(LDColor.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundStyle(LDColor.inkSecondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(viewModel.word.audio) { track in
                        Button {
                            Task { await viewModel.playPronunciation(track: track) }
                        } label: {
                            LDListRow {
                            HStack {
                                VStack(alignment: .leading, spacing: LDSpacing.xxs) {
                                    Text(track.speed.capitalized + " speed")
                                        .font(LDTypography.bodyBold())
                                    Text(track.accent.capitalized)
                                        .font(LDTypography.caption())
                                        .foregroundStyle(LDColor.inkSecondary)
                                }
                                Spacer()
                                Image(systemName: "play.fill")
                                    .foregroundStyle(LDColor.inkSecondary)
                            }
                        }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("Usage notes")
                    .font(LDTypography.section())
                LDCard {
                    Text(viewModel.word.usageNotes)
                        .font(LDTypography.body())
                        .foregroundStyle(LDColor.inkPrimary)
                }

                Text("Examples")
                    .font(LDTypography.section())
                ForEach(viewModel.word.examples) { sentence in
                    SentenceCardView(sentence: sentence)
                }

                Text("Related words")
                    .font(LDTypography.section())
                if viewModel.relatedWords.isEmpty {
                    LDEmptyStateView(
                        title: "No related words yet",
                        subtitle: "Add more words in this language to see connected vocabulary.",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    HStack(spacing: LDSpacing.xs) {
                        ForEach(viewModel.relatedWords) { related in
                            Button {
                                viewModel.relatedWordOpened(related)
                                appState.path.append(.wordDetail(related))
                            } label: {
                                Text(related.lemma)
                                    .font(LDTypography.caption())
                                    .padding(.horizontal, LDSpacing.sm)
                                    .padding(.vertical, LDSpacing.xs)
                                    .background(LDColor.surfaceMuted)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .navigationTitle(viewModel.word.lemma)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load()
        }
    }

    private var statusSummary: String {
        let state = viewModel.progressState
        var labels: [String] = []
        if state.isFavorited {
            labels.append("Favorited")
        }
        if state.isSavedForReview {
            labels.append("Saved for review")
        }
        if state.isLearned {
            labels.append("Marked learned")
        }

        if labels.isEmpty {
            return "No saved status yet for this word."
        }

        return labels.joined(separator: " • ")
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    NavigationStack {
        WordDetailView(
            viewModel: WordDetailViewModel(
                word: SampleData.words[0],
                lessonService: StubDailyLessonService(),
                progressService: StubProgressService(),
                audioPlayer: StubAudioPlayerService(),
                analytics: StubAnalyticsService(),
                crash: StubCrashReportingService()
            )
        )
        .environmentObject(dependencies.appState)
    }
}
