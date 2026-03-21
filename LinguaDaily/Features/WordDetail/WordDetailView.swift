import SwiftUI

struct WordDetailView: View {
    let word: Word

    private var relatedWords: [String] {
        switch word.lemma.lowercased() {
        case "bonjour": return ["Salut", "Bonsoir", "Au revoir"]
        case "merci": return ["De rien", "S'il vous plait", "Pardon"]
        default: return ["Expression", "Conversation", "Daily use"]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                LDCard {
                    VStack(alignment: .leading, spacing: LDSpacing.sm) {
                        Text(word.lemma)
                            .font(LDTypography.hero())
                        Text("\(word.partOfSpeech) • \(word.pronunciationIPA)")
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)

                        HStack(spacing: LDSpacing.sm) {
                            StatCardView(label: "CEFR", value: word.cefrLevel)
                            StatCardView(label: "Frequency", value: "#\(word.frequencyRank)")
                        }
                    }
                }

                LDCard(background: AnyShapeStyle(LDColor.surfaceMuted)) {
                    HStack {
                        Text("Status")
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)
                        Spacer()
                        Text("Check favorite/review in Today")
                            .font(LDTypography.bodyBold())
                            .foregroundStyle(LDColor.inkPrimary)
                    }
                }

                Text("How to pronounce it")
                    .font(LDTypography.section())

                if word.audio.isEmpty {
                    LDEmptyStateView(
                        title: "Audio unavailable offline",
                        subtitle: "Reconnect and try again.",
                        actionTitle: nil,
                        action: nil
                    )
                } else {
                    ForEach(word.audio) { track in
                        LDCard {
                            HStack {
                                Text(track.speed.capitalized + " speed")
                                    .font(LDTypography.body())
                                Spacer()
                                Image(systemName: "play.fill")
                                    .foregroundStyle(LDColor.inkSecondary)
                            }
                        }
                    }
                }

                Text("Usage notes")
                    .font(LDTypography.section())
                LDCard {
                    Text(word.usageNotes)
                        .font(LDTypography.body())
                        .foregroundStyle(LDColor.inkPrimary)
                }

                Text("Examples")
                    .font(LDTypography.section())
                ForEach(word.examples) { sentence in
                    SentenceCardView(sentence: sentence)
                }

                Text("Related words")
                    .font(LDTypography.section())
                HStack(spacing: LDSpacing.xs) {
                    ForEach(relatedWords, id: \.self) { related in
                        Text(related)
                            .font(LDTypography.caption())
                            .padding(.horizontal, LDSpacing.sm)
                            .padding(.vertical, LDSpacing.xs)
                            .background(LDColor.surfaceMuted)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(LDSpacing.lg)
        }
        .background(LDColor.background.ignoresSafeArea())
        .navigationTitle("Word Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        WordDetailView(word: SampleData.words[0])
    }
}
