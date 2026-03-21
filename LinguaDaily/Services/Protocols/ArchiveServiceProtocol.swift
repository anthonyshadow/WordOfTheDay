import Foundation

protocol ArchiveServiceProtocol {
    func fetchArchive(filter: ArchiveFilter, sort: ArchiveSort, query: String) async throws -> [ArchiveWord]
}
