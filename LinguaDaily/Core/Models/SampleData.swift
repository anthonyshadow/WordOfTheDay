import Foundation

enum SampleData {
    static let french = Language(
        id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        code: "fr",
        name: "French",
        nativeName: "Francais",
        isActive: true
    )

    static let words: [Word] = [
        makeWord(
            lemma: "Bonjour",
            ipa: "/bɔ̃.ʒuʁ/",
            part: "interjection",
            cefr: "A1",
            rank: 20,
            definition: "Hello; good morning.",
            usage: "Polite greeting in both formal and informal settings.",
            examples: [
                ("Bonjour, comment allez-vous ?", "Hello, how are you?"),
                ("Elle a dit bonjour en entrant.", "She said hello when she came in.")
            ]
        ),
        makeWord(
            lemma: "Merci",
            ipa: "/mɛʁ.si/",
            part: "interjection",
            cefr: "A1",
            rank: 25,
            definition: "Thank you.",
            usage: "Use with " + "beaucoup" + " for extra emphasis.",
            examples: [
                ("Merci pour votre aide.", "Thank you for your help."),
                ("Merci beaucoup !", "Thank you very much!")
            ]
        ),
        makeWord(
            lemma: "Au revoir",
            ipa: "/o ʁə.vwaʁ/",
            part: "phrase",
            cefr: "A1",
            rank: 45,
            definition: "Goodbye.",
            usage: "Standard farewell.",
            examples: [
                ("Au revoir et bonne journee.", "Goodbye and have a good day."),
                ("Je dois partir, au revoir.", "I have to go, goodbye.")
            ]
        ),
        makeWord(
            lemma: "Pardon",
            ipa: "/paʁ.dɔ̃/",
            part: "interjection",
            cefr: "A1",
            rank: 65,
            definition: "Sorry; excuse me.",
            usage: "Polite apology or attention getter.",
            examples: [
                ("Pardon, je suis en retard.", "Sorry, I am late."),
                ("Pardon, ou est la sortie ?", "Excuse me, where is the exit?")
            ]
        ),
        makeWord(
            lemma: "Aujourd'hui",
            ipa: "/o.ʒuʁ.dɥi/",
            part: "adverb",
            cefr: "A1",
            rank: 80,
            definition: "Today.",
            usage: "Common time marker in daily speech.",
            examples: [
                ("Aujourd'hui, il fait beau.", "Today, the weather is nice."),
                ("Je travaille aujourd'hui.", "I am working today.")
            ]
        ),
        makeWord(
            lemma: "Demain",
            ipa: "/də.mɛ̃/",
            part: "adverb",
            cefr: "A1",
            rank: 85,
            definition: "Tomorrow.",
            usage: "Used for near-future plans.",
            examples: [
                ("Demain, nous partons tot.", "Tomorrow, we leave early."),
                ("Je te vois demain.", "I will see you tomorrow.")
            ]
        ),
        makeWord(
            lemma: "Eau",
            ipa: "/o/",
            part: "noun",
            cefr: "A1",
            rank: 95,
            definition: "Water.",
            usage: "Frequent in restaurants and travel.",
            examples: [
                ("Je voudrais de l'eau, s'il vous plait.", "I would like some water, please."),
                ("L'eau est froide.", "The water is cold.")
            ]
        ),
        makeWord(
            lemma: "Parler",
            ipa: "/paʁ.le/",
            part: "verb",
            cefr: "A1",
            rank: 70,
            definition: "To speak.",
            usage: "Often followed by a language.",
            examples: [
                ("Je parle un peu francais.", "I speak a little French."),
                ("Elle parle tres vite.", "She speaks very fast.")
            ]
        ),
        makeWord(
            lemma: "Comprendre",
            ipa: "/kɔ̃.pʁɑ̃dʁ/",
            part: "verb",
            cefr: "A2",
            rank: 150,
            definition: "To understand.",
            usage: "Critical for practical conversation.",
            examples: [
                ("Je ne comprends pas.", "I do not understand."),
                ("Tu comprends cette phrase ?", "Do you understand this sentence?")
            ]
        ),
        makeWord(
            lemma: "Bienvenue",
            ipa: "/bjɛ̃.və.ny/",
            part: "interjection",
            cefr: "A1",
            rank: 260,
            definition: "Welcome.",
            usage: "Used when receiving someone.",
            examples: [
                ("Bienvenue a Paris !", "Welcome to Paris!"),
                ("Vous etes les bienvenus.", "You are welcome (plural).")
            ]
        )
    ]

    static var todayLesson: DailyLesson {
        DailyLesson(
            id: UUID(),
            assignmentDate: Date(),
            dayNumber: 12,
            languageName: french.name,
            word: words[0],
            isLearned: false,
            isFavorited: false,
            isSavedForReview: false
        )
    }

    static var archive: [ArchiveWord] {
        words.enumerated().map { index, word in
            ArchiveWord(
                id: UUID(),
                word: word,
                status: index.isMultiple(of: 3) ? .reviewDue : .learned,
                dayNumber: index + 1,
                isFavorited: index.isMultiple(of: 4),
                nextReviewAt: Calendar.current.date(byAdding: .day, value: max(0, index - 4), to: Date()),
                learnedAt: Calendar.current.date(byAdding: .day, value: -index, to: Date())
            )
        }
    }

    static var reviewCards: [ReviewCard] {
        words.prefix(5).map { word in
            let correct = ReviewOption(id: UUID(), text: word.definition, isCorrect: true)
            let distractors = words.shuffled().prefix(3).map { ReviewOption(id: UUID(), text: $0.definition, isCorrect: false) }
            return ReviewCard(
                id: UUID(),
                wordID: word.id,
                lemma: word.lemma,
                pronunciation: word.pronunciationIPA,
                options: ([correct] + distractors).shuffled(),
                correctMeaning: word.definition
            )
        }
    }

    static var progress: ProgressSnapshot {
        ProgressSnapshot(
            currentStreakDays: 12,
            bestStreakDays: 19,
            wordsLearned: 48,
            masteredCount: 19,
            reviewAccuracy: 0.87,
            weeklyActivity: [
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Mon", score: 40),
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Tue", score: 65),
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Wed", score: 50),
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Thu", score: 80),
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Fri", score: 70),
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Sat", score: 95),
                WeeklyActivityPoint(id: UUID(), weekdayLabel: "Sun", score: 75)
            ],
            bestRetentionCategory: "Greetings and common phrases"
        )
    }

    static var profile: UserProfile {
        UserProfile(
            id: UUID(),
            email: "alex@example.com",
            displayName: "Alex Carter",
            activeLanguage: french,
            learningGoal: .travel,
            level: .beginner,
            reminderTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
            timezoneIdentifier: TimeZone.current.identifier,
            joinedAt: Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        )
    }

    private static func makeWord(
        lemma: String,
        ipa: String,
        part: String,
        cefr: String,
        rank: Int,
        definition: String,
        usage: String,
        examples: [(String, String)]
    ) -> Word {
        Word(
            id: UUID(),
            languageCode: "fr",
            lemma: lemma,
            transliteration: nil,
            pronunciationIPA: ipa,
            partOfSpeech: part,
            cefrLevel: cefr,
            frequencyRank: rank,
            definition: definition,
            usageNotes: usage,
            examples: examples.enumerated().map { offset, pair in
                ExampleSentence(id: UUID(), sentence: pair.0, translation: pair.1, order: offset + 1)
            },
            audio: [
                WordAudio(id: UUID(), accent: "parisian", speed: "native", url: URL(string: "https://example.com/native.mp3")!, durationMS: 1500),
                WordAudio(id: UUID(), accent: "parisian", speed: "slow", url: URL(string: "https://example.com/slow.mp3")!, durationMS: 2400)
            ]
        )
    }
}
