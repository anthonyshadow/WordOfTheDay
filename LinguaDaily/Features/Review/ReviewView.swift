import SwiftUI

struct ReviewView: View {
    @StateObject private var viewModel: ReviewViewModel

    init(viewModel: ReviewViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: LDSpacing.md) {
            header
            content
            Spacer()
        }
        .padding(LDSpacing.lg)
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        HStack {
            Text("Review")
                .font(LDTypography.title())
            Spacer()
            if let progressLabel = viewModel.progressLabel {
                Text(progressLabel)
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LDLoadingStateView(title: "Preparing review")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            LDEmptyStateView(
                title: "No review due",
                subtitle: "Great work. Check back later for the next review.",
                actionTitle: "Refresh",
                action: { Task { await viewModel.load() } }
            )
        case .success:
            if let card = viewModel.currentCard {
                LDCard(background: AnyShapeStyle(LDColor.accent)) {
                    VStack(alignment: .leading, spacing: LDSpacing.sm) {
                        Text("What does this mean?")
                            .font(LDTypography.caption())
                            .foregroundStyle(Color.white.opacity(0.7))
                        Text(card.lemma)
                            .font(LDTypography.hero())
                            .foregroundStyle(.white)
                        Text(card.pronunciation)
                            .font(LDTypography.caption())
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                }

                ForEach(card.options) { option in
                    Button {
                        viewModel.selectOption(option.id)
                    } label: {
                        HStack {
                            Text(option.text)
                                .font(LDTypography.bodyBold())
                            Spacer()
                            if viewModel.selectedOptionID == option.id {
                                Image(systemName: "checkmark.circle.fill")
                            }
                        }
                        .padding(LDSpacing.md)
                        .frame(maxWidth: .infinity)
                        .background(LDColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous)
                                .stroke(viewModel.selectedOptionID == option.id ? LDColor.accent : LDColor.surfaceMuted, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }

                if let feedback = viewModel.feedback {
                    LDCard(background: AnyShapeStyle(feedback.isCorrect ? LDColor.accentSoft : Color(hex: "#FBEAE8"))) {
                        VStack(alignment: .leading, spacing: LDSpacing.xs) {
                            Text(feedback.isCorrect ? "Correct" : "Not quite")
                                .font(LDTypography.bodyBold())
                            Text(feedback.explanation)
                                .font(LDTypography.body())
                            Text("Next review: \(feedback.nextReviewDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(LDTypography.caption())
                                .foregroundStyle(LDColor.inkSecondary)
                        }
                    }

                    Button("Next") {
                        viewModel.next()
                    }
                    .buttonStyle(LDPrimaryButtonStyle())
                } else {
                    Button("Submit answer") {
                        Task { await viewModel.submit() }
                    }
                    .buttonStyle(LDPrimaryButtonStyle())
                    .disabled(viewModel.selectedOptionID == nil)
                    .opacity(viewModel.selectedOptionID == nil ? 0.5 : 1)
                }
            }
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return ReviewView(
        viewModel: ReviewViewModel(
            reviewService: dependencies.reviewService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService
        )
    )
}
