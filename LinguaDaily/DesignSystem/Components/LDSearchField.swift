import SwiftUI

struct LDSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: LDSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(LDColor.inkSecondary)
            TextField(placeholder, text: $text)
                .font(LDTypography.body())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, LDSpacing.md)
        .padding(.vertical, LDSpacing.sm)
        .background(LDColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous)
                .stroke(LDColor.surfaceMuted, lineWidth: 1)
        )
        .accessibilityLabel(placeholder)
    }
}
