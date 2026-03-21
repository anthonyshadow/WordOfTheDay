import SwiftUI

struct StatCardView: View {
    let label: String
    let value: String

    var body: some View {
        LDCard(background: AnyShapeStyle(LDColor.surfaceMuted)) {
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text(label)
                    .font(LDTypography.overline())
                    .foregroundStyle(LDColor.inkSecondary)
                    .textCase(.uppercase)
                Text(value)
                    .font(LDTypography.bodyBold())
                    .foregroundStyle(LDColor.inkPrimary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
