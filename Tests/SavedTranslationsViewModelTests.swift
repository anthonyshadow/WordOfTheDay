import XCTest
@testable import LinguaDaily

@MainActor
final class SavedTranslationsViewModelTests: XCTestCase {
    func testLoadFetchesSavedTranslationsAndTracksOpen() async {
        let translationService = TestTranslationService()
        translationService.fetchResult = .success([
            TestData.savedTranslation(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                sourceText: "Hello",
                translatedText: "Bonjour",
                isFavorited: true
            ),
            TestData.savedTranslation(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                sourceText: "Good night",
                translatedText: "Bonne nuit",
                createdAt: Date(timeIntervalSince1970: 1_700_200_000)
            )
        ])
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(
            translationService: translationService,
            analytics: analytics
        )

        await viewModel.load()

        guard case let .success(translations) = viewModel.phase else {
            return XCTFail("Expected translations to load")
        }
        XCTAssertEqual(translations.count, 2)
        XCTAssertEqual(translations.first?.sourceText, "Good night")
        XCTAssertEqual(analytics.events.last?.event, .translationLibraryOpened)
    }

    func testUpdateQueryFiltersSourceAndTranslatedText() async {
        let translationService = TestTranslationService()
        translationService.fetchResult = .success([
            TestData.savedTranslation(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                sourceText: "Hello",
                translatedText: "Bonjour"
            ),
            TestData.savedTranslation(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                sourceText: "Goodbye",
                translatedText: "Au revoir",
                createdAt: Date(timeIntervalSince1970: 1_700_200_000)
            )
        ])
        let viewModel = makeViewModel(translationService: translationService)

        await viewModel.load()
        viewModel.updateQuery("bonjour")

        guard case let .success(translations) = viewModel.phase else {
            return XCTFail("Expected filtered translations")
        }
        XCTAssertEqual(translations.map(\.translatedText), ["Bonjour"])
    }

    func testUpdateFilterShowsOnlyFavorites() async {
        let translationService = TestTranslationService()
        translationService.fetchResult = .success([
            TestData.savedTranslation(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                sourceText: "Hello",
                translatedText: "Bonjour",
                isFavorited: true
            ),
            TestData.savedTranslation(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                sourceText: "Goodbye",
                translatedText: "Au revoir"
            )
        ])
        let viewModel = makeViewModel(translationService: translationService)

        await viewModel.load()
        viewModel.updateFilter(.favorites)

        guard case let .success(translations) = viewModel.phase else {
            return XCTFail("Expected favorite translations")
        }
        XCTAssertEqual(translations.count, 1)
        XCTAssertEqual(translations.first?.translatedText, "Bonjour")
    }

    func testToggleFavoriteUpdatesStoredTranslation() async {
        let translationService = TestTranslationService()
        let translationID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        translationService.fetchResult = .success([
            TestData.savedTranslation(
                id: translationID,
                sourceText: "Hello",
                translatedText: "Bonjour",
                isFavorited: false
            )
        ])
        translationService.updateResult = .success(
            TestData.savedTranslation(
                id: translationID,
                sourceText: "Hello",
                translatedText: "Bonjour",
                isFavorited: true
            )
        )
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(
            translationService: translationService,
            analytics: analytics
        )

        await viewModel.load()
        await viewModel.toggleFavorite(id: translationID)

        XCTAssertEqual(translationService.updateRequests.first?.id, translationID)
        XCTAssertTrue(translationService.updateRequests.first?.isFavorited ?? false)
        XCTAssertEqual(viewModel.translation(id: translationID)?.isFavorited, true)
        XCTAssertEqual(analytics.events.last?.event, .translationFavorited)
    }

    func testRemoveSaveDeletesTranslationAndTransitionsToEmpty() async {
        let translationService = TestTranslationService()
        let translationID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        translationService.fetchResult = .success([
            TestData.savedTranslation(
                id: translationID,
                sourceText: "Hello",
                translatedText: "Bonjour"
            )
        ])
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(
            translationService: translationService,
            analytics: analytics
        )

        await viewModel.load()
        await viewModel.removeSave(id: translationID)

        XCTAssertEqual(translationService.deletedIDs, [translationID])
        guard case .empty = viewModel.phase else {
            return XCTFail("Expected empty phase after deletion")
        }
        XCTAssertEqual(analytics.events.last?.event, .translationRemoved)
    }

    private func makeViewModel(
        translationService: TestTranslationService = TestTranslationService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService()
    ) -> SavedTranslationsViewModel {
        SavedTranslationsViewModel(
            translationService: translationService,
            analytics: analytics,
            crash: crash
        )
    }
}
