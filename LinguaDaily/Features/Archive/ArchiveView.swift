import SwiftUI

struct ArchiveView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ArchiveViewModel

    init(viewModel: ArchiveViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: LDSpacing.md) {
            HStack {
                Text("My Words")
                    .font(LDTypography.title())
                Spacer()
                Menu {
                    ForEach(ArchiveSort.allCases, id: \.self) { sort in
                        Button(sort.title) {
                            viewModel.updateSort(sort)
                            Task { await viewModel.load() }
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .padding(8)
                        .background(LDColor.surface)
                        .clipShape(RoundedRectangle(cornerRadius: LDRadius.sm, style: .continuous))
                }
            }

            LDSearchField(placeholder: "Search words, meanings, examples", text: $viewModel.query)
                .onChange(of: viewModel.query) { _, newValue in
                    viewModel.updateQuery(newValue)
                    Task { await viewModel.load() }
                }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: LDSpacing.xs) {
                    ForEach(ArchiveFilter.allCases, id: \.self) { filter in
                        LDFilterChip(title: filter.title, isActive: viewModel.filter == filter) {
                            viewModel.updateFilter(filter)
                            Task { await viewModel.load() }
                        }
                    }
                }
            }

            content
            Spacer()
        }
        .padding(LDSpacing.lg)
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LDLoadingStateView(title: "Loading archive")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            if viewModel.filter == .favorites {
                LDEmptyStateView(
                    title: "No favorites yet",
                    subtitle: "Favorite words on Today or in details to find them quickly.",
                    actionTitle: "Show all",
                    action: {
                        viewModel.updateFilter(.all)
                        Task { await viewModel.load() }
                    }
                )
            } else {
                LDEmptyStateView(
                    title: "No matching words",
                    subtitle: "Try a different search or filter.",
                    actionTitle: "Clear filters",
                    action: {
                        viewModel.updateFilter(.all)
                        viewModel.updateQuery("")
                        Task { await viewModel.load() }
                    }
                )
            }
        case let .success(words):
            ScrollView {
                VStack(spacing: LDSpacing.sm) {
                    ForEach(words) { row in
                        Button {
                            appState.path.append(.wordDetail(row.word))
                        } label: {
                            LDListRow {
                                HStack {
                                    VStack(alignment: .leading, spacing: LDSpacing.xxs) {
                                        Text(row.word.lemma)
                                            .font(LDTypography.bodyBold())
                                            .foregroundStyle(LDColor.inkPrimary)
                                        Text("Day \(row.dayNumber) • \(row.status.rawValue)")
                                            .font(LDTypography.caption())
                                            .foregroundStyle(LDColor.inkSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: row.isFavorited ? "heart.fill" : "chevron.right")
                                        .foregroundStyle(row.isFavorited ? LDColor.danger : LDColor.inkSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return ArchiveView(
        viewModel: ArchiveViewModel(
            archiveService: dependencies.archiveService,
            cacheStore: dependencies.cacheStore,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService,
            entitlementProvider: { .free }
        )
    )
    .environmentObject(dependencies.appState)
}
