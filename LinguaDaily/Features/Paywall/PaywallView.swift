import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel: PaywallViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    init(viewModel: PaywallViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: LDSpacing.md) {
                LDCard(background: AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(hex: "#2A4B88"), Color(hex: "#1B2E52")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )) {
                    VStack(alignment: .leading, spacing: LDSpacing.sm) {
                        Text("Premium")
                            .font(LDTypography.overline())
                            .foregroundStyle(Color.white.opacity(0.8))
                        Text("Go beyond the daily word")
                            .font(LDTypography.title())
                            .foregroundStyle(.white)
                        Text("Unlimited archive, slow pronunciation mode, and mastery review.")
                            .font(LDTypography.body())
                            .foregroundStyle(Color.white.opacity(0.85))
                    }
                }

                planRow(title: "Monthly", price: "$5.99") {
                    Task { await viewModel.buyMonthly() }
                }

                planRow(title: "Yearly", price: "$39.99", featured: true) {
                    Task { await viewModel.buyYearly() }
                }

                Button("Restore purchases") {
                    Task { await viewModel.restore() }
                }
                .buttonStyle(LDSecondaryButtonStyle())

                Button("Manage subscription") {
                    if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
                        openURL(url)
                    }
                }
                .buttonStyle(LDSecondaryButtonStyle())

                Button("Continue with free plan") {
                    dismiss()
                }
                .buttonStyle(LDSecondaryButtonStyle())

                if case .loading = viewModel.phase {
                    ProgressView()
                }

                if case let .failure(error) = viewModel.phase {
                    LDErrorStateView(error: error) {
                        Task { await viewModel.load() }
                    }
                }
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
        .navigationTitle("Premium")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func planRow(title: String, price: String, featured: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: LDSpacing.xxs) {
                    Text(title)
                        .font(LDTypography.bodyBold())
                    Text("Auto-renewing subscription")
                        .font(LDTypography.caption())
                        .foregroundStyle(featured ? Color.white.opacity(0.8) : LDColor.inkSecondary)
                }
                Spacer()
                Text(price)
                    .font(LDTypography.section())
            }
            .foregroundStyle(featured ? Color.white : LDColor.inkPrimary)
            .padding(LDSpacing.md)
            .background(featured ? LDColor.accent : LDColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return NavigationStack {
        PaywallView(
            viewModel: PaywallViewModel(
                subscriptionService: dependencies.subscriptionService,
                analytics: dependencies.analyticsService,
                crash: dependencies.crashService,
                appState: dependencies.appState
            )
        )
    }
}
