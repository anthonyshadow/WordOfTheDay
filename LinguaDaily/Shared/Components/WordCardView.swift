import SwiftUI

struct WordCardView: View {
    let lesson: DailyLesson
    let onPlay: () -> Void

    var body: some View {
        LDCard(background: AnyShapeStyle(LDColor.cardWarm)) {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: LDSpacing.xs) {
                        Text("\(lesson.languageName) • Day \(lesson.dayNumber)")
                            .font(LDTypography.overline())
                            .foregroundStyle(LDColor.inkSecondary)
                            .textCase(.uppercase)
                        Text(lesson.word.lemma)
                            .font(LDTypography.hero())
                            .foregroundStyle(LDColor.inkPrimary)
                        Text(lesson.word.pronunciationIPA)
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)
                    }
                    Spacer()
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .foregroundStyle(LDColor.inkPrimary)
                            .padding(LDSpacing.sm)
                            .background(Color.white.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                    }
                    .accessibilityLabel("Play pronunciation")
                }
                Text(lesson.word.definition)
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkPrimary)
            }
        }
    }
}
