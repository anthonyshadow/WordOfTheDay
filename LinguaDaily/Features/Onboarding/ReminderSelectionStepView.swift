import SwiftUI

struct ReminderSelectionStepView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @State private var reminder = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()

    var body: some View {
        VStack(alignment: .leading, spacing: LDSpacing.md) {
            stepHeader

            LDCard {
                DatePicker(
                    "Reminder time",
                    selection: $reminder,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .onChange(of: reminder) { _, newValue in
                    viewModel.updateReminder(newValue)
                }
            }

            Text("You can change this anytime in Settings.")
                .font(LDTypography.caption())
                .foregroundStyle(LDColor.inkSecondary)
        }
        .onAppear {
            if let existing = viewModel.onboardingState.reminderTime {
                reminder = existing
            } else {
                viewModel.updateReminder(reminder)
            }
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: LDSpacing.xs) {
            Text(viewModel.step.stepLabel)
                .font(LDTypography.overline())
                .foregroundStyle(LDColor.inkSecondary)
                .textCase(.uppercase)
            Text(viewModel.step.title)
                .font(LDTypography.title())
                .foregroundStyle(LDColor.inkPrimary)
        }
    }
}
