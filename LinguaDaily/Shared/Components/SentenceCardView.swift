import SwiftUI

struct SentenceCardView: View {
    let sentence: ExampleSentence

    var body: some View {
        LDCard {
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text(sentence.sentence)
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkPrimary)
                Text(sentence.translation)
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)
            }
        }
    }
}
