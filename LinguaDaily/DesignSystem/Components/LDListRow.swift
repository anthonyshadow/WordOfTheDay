import SwiftUI

struct LDListRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(LDSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LDColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous)
                    .stroke(LDColor.surfaceMuted, lineWidth: 1)
            )
    }
}
