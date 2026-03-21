import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var phase: AsyncPhase<UserProfile> = .idle

    private let progressService: ProgressServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol

    init(progressService: ProgressServiceProtocol, analytics: AnalyticsServiceProtocol, crash: CrashReportingServiceProtocol) {
        self.progressService = progressService
        self.analytics = analytics
        self.crash = crash
    }

    func load() async {
        phase = .loading
        do {
            phase = .success(try await progressService.fetchProfile())
            analytics.track(.profileOpened, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "profile_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }
}
