import SwiftUI

struct LDPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LDTypography.bodyBold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LDSpacing.md)
            .background(LDColor.accent)
            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct LDSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(LDTypography.bodyBold())
            .foregroundStyle(LDColor.inkPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, LDSpacing.md)
            .background(LDColor.surface)
            .overlay(
                RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous)
                    .stroke(LDColor.surfaceMuted, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
