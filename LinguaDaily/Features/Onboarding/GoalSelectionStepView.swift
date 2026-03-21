import SwiftUI

struct GoalSelectionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LDSpacing.md) {
            stepHeader
            ForEach(LearningGoal.allCases, id: \.self) { goal in
                Button {
                    viewModel.updateGoal(goal)
                } label: {
                    HStack {
                        Text(goal.title)
                            .font(LDTypography.bodyBold())
                        Spacer()
                        if viewModel.onboardingState.goal == goal {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundStyle(viewModel.onboardingState.goal == goal ? .white : LDColor.inkPrimary)
                    .padding(LDSpacing.md)
                    .background(viewModel.onboardingState.goal == goal ? LDColor.accent : LDColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(goal.title)
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: LDSpacing.xs) {
            Text(viewModel.step.stepLabel)
                .font(LDTypography.overline())
                .foregroundStyle(LDColor.inkSecondary)
                .textCase(.uppercase)
            Text(viewModel.step.title)
                .font(LDTypography.title())
                .foregroundStyle(LDColor.inkPrimary)
        }
    }
}
