import Foundation
import Combine

@MainActor
final class ProgressViewModel: ObservableObject {
    @Published var phase: AsyncPhase<ProgressSnapshot> = .idle

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
            let progress = try await progressService.fetchProgress()
            phase = .success(progress)
            analytics.track(.progressOpened, properties: [:])
            if progress.currentStreakDays > 0 {
                analytics.track(.streakExtended, properties: ["days": "\(progress.currentStreakDays)"])
            }
        } catch {
            crash.capture(error, context: ["feature": "progress_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }
}
