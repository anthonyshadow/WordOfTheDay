import SwiftUI

struct LDCard<Content: View>: View {
    var background: AnyShapeStyle
    var content: Content

    init(background: AnyShapeStyle = AnyShapeStyle(LDColor.surface), @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    var body: some View {
        content
            .padding(LDSpacing.md)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: LDRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LDRadius.lg, style: .continuous)
                    .stroke(LDColor.surfaceMuted, lineWidth: 1)
            )
            .cardElevation()
    }
}
