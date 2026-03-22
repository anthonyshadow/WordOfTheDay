import Foundation
import SwiftData

@MainActor
enum PreviewFactory {
    static func makeContainer() -> AppDependencyContainer {
        let schema = Schema([
            CachedDailyLessonEntity.self,
            CachedWordMetadataEntity.self,
            CachedWordEnrichmentEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let modelContainer = try! ModelContainer(for: schema, configurations: [configuration])
        return AppDependencyContainer(
            modelContext: modelContainer.mainContext,
            modelContainer: modelContainer
        )
    }
}
