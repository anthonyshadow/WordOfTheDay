import Foundation
import Combine

@MainActor
final class ArchiveViewModel: ObservableObject {
    @Published var phase: AsyncPhase<[ArchiveWord]> = .idle
    @Published var query = ""
    @Published var filter: ArchiveFilter = .all
    @Published var sort: ArchiveSort = .newest

    private let archiveService: ArchiveServiceProtocol
    private let cacheStore: LocalCacheStore
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let entitlementProvider: () -> EntitlementTier

    init(
        archiveService: ArchiveServiceProtocol,
        cacheStore: LocalCacheStore,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        entitlementProvider: @escaping () -> EntitlementTier
    ) {
        self.archiveService = archiveService
        self.cacheStore = cacheStore
        self.analytics = analytics
        self.crash = crash
        self.entitlementProvider = entitlementProvider
    }

    func load() async {
        phase = .loading
        do {
            let words = try await archiveService.fetchArchive(filter: filter, sort: sort, query: query)
            let limitedWords = AccessPolicy.applyArchiveLimit(words: words, tier: entitlementProvider())
            if limitedWords.isEmpty {
                phase = .empty
            } else {
                phase = .success(limitedWords)
                try? cacheStore.upsertArchiveMetadata(limitedWords)
                analytics.track(.archiveOpened, properties: ["count": "\(limitedWords.count)"])
            }
        } catch {
            crash.capture(error, context: ["feature": "archive_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func updateFilter(_ filter: ArchiveFilter) {
        self.filter = filter
        analytics.track(.archiveFilterChanged, properties: ["filter": filter.rawValue])
    }

    func updateSort(_ sort: ArchiveSort) {
        self.sort = sort
        analytics.track(.archiveSortChanged, properties: ["sort": sort.rawValue])
    }

    func updateQuery(_ query: String) {
        self.query = query
        analytics.track(.archiveSearchUsed, properties: ["length": "\(query.count)"])
    }
}
