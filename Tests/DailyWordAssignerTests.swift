import XCTest
@testable import LinguaDaily

final class DailyWordAssignerTests: XCTestCase {
    func testAssignsLowestFrequencyUnassignedWord() {
        let assigner = DailyWordAssigner()
        let allWords = SampleData.words
        let assignedIDs = Set(allWords.dropFirst().map(\.id))

        let result = assigner.assignWord(allWords: allWords, alreadyAssignedWordIDs: assignedIDs)

        XCTAssertEqual(result?.id, allWords.first?.id)
    }

    func testFallsBackWhenExhausted() {
        let assigner = DailyWordAssigner()
        let allWords = SampleData.words
        let assignedIDs = Set(allWords.map(\.id))

        let result = assigner.assignWord(allWords: allWords, alreadyAssignedWordIDs: assignedIDs)

        XCTAssertNotNil(result)
    }
}
