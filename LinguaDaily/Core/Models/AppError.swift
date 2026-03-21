import Foundation

enum AppError: Error, Equatable {
    case network(String)
    case auth(String)
    case decoding(String)
    case validation(String)
    case unknown(String)

    var viewError: ViewError {
        switch self {
        case let .network(message):
            return ViewError(title: "Network issue", message: message, actionTitle: "Retry")
        case let .auth(message):
            return ViewError(title: "Authentication issue", message: message, actionTitle: "Try again")
        case let .decoding(message):
            return ViewError(title: "Data issue", message: message, actionTitle: "Retry")
        case let .validation(message):
            return ViewError(title: "Invalid input", message: message, actionTitle: "Update")
        case let .unknown(message):
            return ViewError(title: "Unexpected error", message: message, actionTitle: "Retry")
        }
    }
}
