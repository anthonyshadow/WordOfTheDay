import SwiftUI

struct LearningProgressView: View {
    @StateObject private var viewModel: ProgressViewModel

    init(viewModel: ProgressViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                Text("Progress")
                    .font(LDTypography.title())

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
            LDLoadingStateView(title: "Loading progress")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            LDEmptyStateView(title: "No progress yet", subtitle: "Learn your first word today.", actionTitle: nil, action: nil)
        case let .success(progress):
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: LDSpacing.sm) {
                StatCardView(label: "Current streak", value: "\(progress.currentStreakDays) days")
                StatCardView(label: "Words learned", value: "\(progress.wordsLearned)")
                StatCardView(label: "Mastered", value: "\(progress.masteredCount)")
                StatCardView(label: "Accuracy", value: "\(Int(progress.reviewAccuracy * 100))%")
            }

            LDCard {
                VStack(alignment: .leading, spacing: LDSpacing.sm) {
                    Text("This week")
                        .font(LDTypography.bodyBold())
                    HStack(alignment: .bottom, spacing: LDSpacing.xs) {
                        ForEach(progress.weeklyActivity) { point in
                            VStack(spacing: LDSpacing.xxs) {
                                RoundedRectangle(cornerRadius: LDRadius.sm)
                                    .fill(LDColor.accent)
                                    .frame(height: CGFloat(max(10, point.score)))
                                Text(point.weekdayLabel)
                                    .font(LDTypography.caption())
                                    .foregroundStyle(LDColor.inkSecondary)
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }

            LDCard {
                VStack(alignment: .leading, spacing: LDSpacing.xs) {
                    Text("Milestones")
                        .font(LDTypography.bodyBold())
                    Text("\(progress.currentStreakDays)-day streak • \(progress.wordsLearned) words learned")
                        .font(LDTypography.body())
                        .foregroundStyle(LDColor.inkPrimary)
                }
            }

            LDCard(background: AnyShapeStyle(LDColor.accentSoft)) {
                Text("Best retention category: \(progress.bestRetentionCategory).")
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkPrimary)
            }
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return LearningProgressView(
        viewModel: ProgressViewModel(
            progressService: dependencies.progressService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService
        )
    )
}
