import Foundation

enum AsyncPhase<Value> {
    case idle
    case loading
    case success(Value)
    case empty
    case failure(ViewError)
}

struct ViewError: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let message: String
    let actionTitle: String

    static let generic = ViewError(
        title: "Something went wrong",
        message: "Please try again in a moment.",
        actionTitle: "Retry"
    )
}
