import Foundation

final class StubArchiveService: ArchiveServiceProtocol {
    private var allWords = SampleData.archive

    func fetchArchive(filter: ArchiveFilter, sort: ArchiveSort, query: String) async throws -> [ArchiveWord] {
        var result = allWords

        switch filter {
        case .all:
            break
        case .learned:
            result = result.filter { $0.status == .learned }
        case .reviewDue:
            result = result.filter { $0.status == .reviewDue }
        case .mastered:
            result = result.filter { $0.status == .mastered }
        case .favorites:
            result = result.filter { $0.isFavorited }
        }

        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            result = result.filter {
                $0.word.lemma.localizedCaseInsensitiveContains(query)
                || $0.word.definition.localizedCaseInsensitiveContains(query)
                || $0.word.examples.contains(where: { $0.sentence.localizedCaseInsensitiveContains(query) })
            }
        }

        switch sort {
        case .newest:
            result = result.sorted(by: { $0.dayNumber > $1.dayNumber })
        case .oldest:
            result = result.sorted(by: { $0.dayNumber < $1.dayNumber })
        case .alphabetical:
            result = result.sorted(by: { $0.word.lemma < $1.word.lemma })
        case .reviewDueSoon:
            result = result.sorted(by: {
                ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture)
            })
        }

        return result
    }
}
