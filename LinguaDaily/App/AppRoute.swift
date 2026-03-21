import Foundation

enum MainTab: Hashable {
    case today
    case review
    case words
    case progress
    case profile

    var title: String {
        switch self {
        case .today: return "Today"
        case .review: return "Review"
        case .words: return "Words"
        case .progress: return "Progress"
        case .profile: return "Profile"
        }
    }

    var systemImage: String {
        switch self {
        case .today: return "sun.max"
        case .review: return "arrow.triangle.2.circlepath"
        case .words: return "books.vertical"
        case .progress: return "chart.bar"
        case .profile: return "person.crop.circle"
        }
    }
}

enum AppDestination: Hashable {
    case wordDetail(Word)
    case settings
    case paywall
}

enum DeepLinkTarget: Hashable {
    case today
    case review

    init?(url: URL) {
        guard url.scheme?.lowercased() == "linguadaily" else {
            return nil
        }
        switch url.host?.lowercased() {
        case "today": self = .today
        case "review": self = .review
        default: return nil
        }
    }
}
