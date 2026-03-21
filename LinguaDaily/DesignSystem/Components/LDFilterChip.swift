import SwiftUI

struct LDFilterChip: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(LDTypography.caption())
                .foregroundStyle(isActive ? Color.white : LDColor.inkSecondary)
                .padding(.horizontal, LDSpacing.sm)
                .padding(.vertical, LDSpacing.xs)
                .background(isActive ? LDColor.accent : LDColor.surfaceMuted)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
