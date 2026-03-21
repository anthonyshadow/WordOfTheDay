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

    func testAssignsLowestFrequencyWordEvenWhenInputIsUnsorted() {
        let assigner = DailyWordAssigner()
        let allWords = SampleData.words.shuffled()

        let result = assigner.assignWord(allWords: allWords, alreadyAssignedWordIDs: [])

        XCTAssertEqual(result?.lemma, "Bonjour")
        XCTAssertEqual(result?.frequencyRank, 20)
    }

    func testFallsBackWhenExhausted() {
        let assigner = DailyWordAssigner()
        let allWords = SampleData.words
        let assignedIDs = Set(allWords.map(\.id))

        let result = assigner.assignWord(allWords: allWords, alreadyAssignedWordIDs: assignedIDs)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.lemma, "Bonjour")
    }

    func testReturnsNilWhenNoWordsExist() {
        let assigner = DailyWordAssigner()

        let result = assigner.assignWord(allWords: [], alreadyAssignedWordIDs: [])

        XCTAssertNil(result)
    }
}
