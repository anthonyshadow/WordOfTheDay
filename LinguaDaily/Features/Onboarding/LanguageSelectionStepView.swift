import SwiftUI

struct LanguageSelectionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: LDSpacing.md) {
            stepHeader
            content
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

    @ViewBuilder
    private var content: some View {
        switch viewModel.languagePhase {
        case .idle, .loading:
            LDLoadingStateView(title: "Loading languages")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.retryLoadingLanguages() }
            }
        case .empty:
            LDEmptyStateView(
                title: "No languages available",
                subtitle: "Add an active language in Supabase, then try again.",
                actionTitle: "Retry"
            ) {
                Task { await viewModel.retryLoadingLanguages() }
            }
        case .success:
            LDSearchField(placeholder: "Search languages", text: $viewModel.languageQuery)

            if viewModel.filteredLanguages.isEmpty {
                LDEmptyStateView(
                    title: "No matching languages",
                    subtitle: "Try a different search term.",
                    actionTitle: nil,
                    action: nil
                )
            } else {
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
                                    Image(systemName: isSelected(language) ? "checkmark.circle.fill" : "chevron.right")
                                }
                                .foregroundStyle(isSelected(language) ? .white : LDColor.inkPrimary)
                                .padding(LDSpacing.md)
                                .background(isSelected(language) ? LDColor.accent : LDColor.surface)
                                .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func isSelected(_ language: Language) -> Bool {
        viewModel.onboardingState.language?.code.lowercased() == language.code.lowercased()
    }
}
