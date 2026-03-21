import SwiftUI

struct LevelSelectionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LDSpacing.md) {
            stepHeader

            ForEach(LearningLevel.allCases, id: \.self) { level in
                Button {
                    viewModel.updateLevel(level)
                } label: {
                    HStack {
                        Text(level.title)
                            .font(LDTypography.bodyBold())
                        Spacer()
                        if viewModel.onboardingState.level == level {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundStyle(viewModel.onboardingState.level == level ? .white : LDColor.inkPrimary)
                    .padding(LDSpacing.md)
                    .background(viewModel.onboardingState.level == level ? LDColor.accent : LDColor.surface)
                    .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                }
                .buttonStyle(.plain)
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
