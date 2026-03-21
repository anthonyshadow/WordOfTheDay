import SwiftUI

struct LanguageSelectionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LDSpacing.md) {
            stepHeader
            LDSearchField(placeholder: "Search languages", text: $viewModel.languageQuery)

            ScrollView {
                VStack(spacing: LDSpacing.sm) {
                    ForEach(viewModel.filteredLanguages) { language in
                        Button {
                            viewModel.updateLanguage(language)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: LDSpacing.xxs) {
                                    Text(language.name)
                                        .font(LDTypography.bodyBold())
                                    Text(language.nativeName)
                                        .font(LDTypography.caption())
                                }
                                Spacer()
                                Image(systemName: viewModel.onboardingState.language?.id == language.id ? "checkmark.circle.fill" : "chevron.right")
                            }
                            .foregroundStyle(viewModel.onboardingState.language?.id == language.id ? .white : LDColor.inkPrimary)
                            .padding(LDSpacing.md)
                            .background(viewModel.onboardingState.language?.id == language.id ? LDColor.accent : LDColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
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
