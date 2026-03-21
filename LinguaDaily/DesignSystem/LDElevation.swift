import SwiftUI

struct CardElevation: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
            .shadow(color: .black.opacity(0.02), radius: 1, x: 0, y: 1)
    }
}

extension View {
    func cardElevation() -> some View {
        modifier(CardElevation())
    }
}
