import SwiftUI
import Translation
import UIKit

struct TranslateView: View {
    @StateObject private var viewModel: TranslateViewModel
    @StateObject private var savedLibraryViewModel: SavedTranslationsViewModel
    @State private var isPresentingSourceLanguagePicker = false
    @State private var isPresentingTargetLanguagePicker = false
    @State private var copyStatusMessage: String?

    init(viewModel: TranslateViewModel, savedLibraryViewModel: SavedTranslationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _savedLibraryViewModel = StateObject(wrappedValue: savedLibraryViewModel)
    }

    var body: some View {
        Group {
            switch viewModel.languagePhase {
            case .idle, .loading:
                LDLoadingStateView(title: "Loading translation tools")
                    .padding(LDSpacing.lg)
            case let .failure(error):
                LDErrorStateView(error: error) {
                    Task { await viewModel.load() }
                }
                .padding(LDSpacing.lg)
            case .empty:
                LDEmptyStateView(
                    title: "No languages available",
                    subtitle: "Add an app language first, then come back to translate text.",
                    actionTitle: "Retry",
                    action: {
                        Task { await viewModel.load() }
                    }
                )
                .padding(LDSpacing.lg)
            case .success:
                ScrollView {
                    VStack(spacing: LDSpacing.md) {
                        headerCard
                        modeCard
                        languageCard
                        activeInputCard

                        if viewModel.selectedInputMode == .text {
                            translateButton
                        }

                        if let translationError = viewModel.translationError {
                            LDErrorStateView(error: translationError) {
                                viewModel.handleVisibleErrorAction()
                            }
                        }

                        resultSection
                    }
                    .padding(LDSpacing.lg)
                }
            }
        }
        .background(LDColor.background.ignoresSafeArea())
        .navigationTitle("Translate")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Saved") {
                    viewModel.isPresentingSavedLibrary = true
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingSavedLibrary) {
            SavedTranslationsView(viewModel: savedLibraryViewModel)
        }
        .sheet(isPresented: $isPresentingSourceLanguagePicker) {
            TranslationLanguagePickerSheet(
                title: "Source Language",
                availableLanguages: viewModel.availableLanguages,
                selectedLanguageCode: viewModel.sourceSelection.language?.code,
                supportsAutoDetect: true,
                targetLanguageCode: viewModel.targetLanguage?.code
            ) { selection in
                viewModel.sourceSelection = selection
            }
        }
        .sheet(isPresented: $isPresentingTargetLanguagePicker) {
            TranslationLanguagePickerSheet(
                title: "Target Language",
                availableLanguages: viewModel.availableLanguages,
                selectedLanguageCode: viewModel.targetLanguage?.code,
                supportsAutoDetect: false,
                targetLanguageCode: nil
            ) { selection in
                if case let .manual(language) = selection {
                    viewModel.targetLanguage = language
                }
            }
        }
        .translationTask(viewModel.translationConfiguration) { session in
            await viewModel.performTranslation(using: session)
        }
        .task {
            await viewModel.load()
        }
    }

    private var headerCard: some View {
        LDCard(background: AnyShapeStyle(LDColor.accent.opacity(0.12))) {
            VStack(alignment: .leading, spacing: LDSpacing.xs) {
                Text(viewModel.selectedInputMode == .voice ? "Voice translation is live" : "Text translation is live")
                    .font(LDTypography.section())
                    .foregroundStyle(LDColor.inkPrimary)
                Text(
                    viewModel.selectedInputMode == .voice
                        ? "Speak a phrase, let LinguaDaily transcribe it, and save the useful translations to your library."
                        : "Translate a word, phrase, or sentence, then save the useful ones to your personal library."
                )
                    .font(LDTypography.body())
                    .foregroundStyle(LDColor.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var modeCard: some View {
        LDCard {
            VStack(alignment: .leading, spacing: LDSpacing.sm) {
                Text("Mode")
                    .font(LDTypography.section())
                    .foregroundStyle(LDColor.inkPrimary)

                HStack(spacing: LDSpacing.xs) {
                    ForEach([TranslationInputMode.voice, .text], id: \.self) { mode in
                        LDFilterChip(title: mode.title, isActive: viewModel.selectedInputMode == mode) {
                            viewModel.selectedInputMode = mode
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var languageCard: some View {
        LDCard {
            VStack(alignment: .leading, spacing: LDSpacing.sm) {
                Text("Languages")
                    .font(LDTypography.section())
                    .foregroundStyle(LDColor.inkPrimary)

                HStack(spacing: LDSpacing.sm) {
                    Button {
                        isPresentingSourceLanguagePicker = true
                    } label: {
                        languageSelectionLabel(
                            title: "Source",
                            value: viewModel.sourceSelection.title
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        viewModel.swapLanguages()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(viewModel.canSwapLanguages ? LDColor.accent : LDColor.inkSecondary)
                            .frame(width: 44, height: 44)
                            .background(LDColor.surfaceMuted)
                            .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!viewModel.canSwapLanguages)

                    Button {
                        isPresentingTargetLanguagePicker = true
                    } label: {
                        languageSelectionLabel(
                            title: "Target",
                            value: viewModel.targetLanguage?.name ?? "Choose language"
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var activeInputCard: some View {
        switch viewModel.selectedInputMode {
        case .voice:
            voiceInputCard
        case .text:
            inputCard
        case .camera:
            EmptyView()
        }
    }

    private var inputCard: some View {
        LDCard {
            VStack(alignment: .leading, spacing: LDSpacing.sm) {
                HStack {
                    Text("Text")
                        .font(LDTypography.section())
                        .foregroundStyle(LDColor.inkPrimary)
                    Spacer()
                    if !viewModel.inputText.isEmpty {
                        Button("Clear") {
                            viewModel.clearInput()
                        }
                        .font(LDTypography.caption())
                        .foregroundStyle(LDColor.accent)
                    }
                }

                ZStack(alignment: .topLeading) {
                    if viewModel.inputText.isEmpty {
                        Text("Type something you want translated")
                            .font(LDTypography.body())
                            .foregroundStyle(LDColor.inkSecondary)
                            .padding(.top, 8)
                            .padding(.leading, 4)
                    }

                    TextEditor(text: $viewModel.inputText)
                        .font(LDTypography.body())
                        .foregroundStyle(LDColor.inkPrimary)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var voiceInputCard: some View {
        LDCard {
            VStack(alignment: .leading, spacing: LDSpacing.md) {
                HStack {
                    Text("Voice")
                        .font(LDTypography.section())
                        .foregroundStyle(LDColor.inkPrimary)
                    Spacer()
                    if !viewModel.liveVoiceTranscript.isEmpty && !viewModel.isListeningForVoice && !viewModel.isProcessingVoiceCapture {
                        Button("Clear") {
                            viewModel.clearVoiceTranscript()
                        }
                        .font(LDTypography.caption())
                        .foregroundStyle(LDColor.accent)
                    }
                }

                Button {
                    Task {
                        if viewModel.isListeningForVoice {
                            await viewModel.stopVoiceCaptureAndTranslate()
                        } else {
                            await viewModel.startVoiceCapture()
                        }
                    }
                } label: {
                    HStack(spacing: LDSpacing.sm) {
                        if viewModel.isProcessingVoiceCapture {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: viewModel.isListeningForVoice ? "stop.fill" : "mic.fill")
                                .font(.system(size: 18, weight: .semibold))
                        }

                        Text(voicePrimaryActionTitle)
                            .font(LDTypography.bodyBold())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(LDPrimaryButtonStyle())
                .disabled((!viewModel.canStartVoiceCapture && !viewModel.isListeningForVoice) || viewModel.isProcessingVoiceCapture)

                VStack(alignment: .leading, spacing: LDSpacing.xs) {
                    Text(voiceStatusTitle)
                        .font(LDTypography.bodyBold())
                        .foregroundStyle(LDColor.inkPrimary)
                    Text(voiceStatusSubtitle)
                        .font(LDTypography.body())
                        .foregroundStyle(LDColor.inkSecondary)
                }

                Group {
                    if viewModel.liveVoiceTranscript.isEmpty {
                        Text("Tap the microphone and speak a word, phrase, or sentence to translate.")
                            .font(LDTypography.body())
                            .foregroundStyle(LDColor.inkSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, LDSpacing.sm)
                    } else {
                        Text(viewModel.liveVoiceTranscript)
                            .font(LDTypography.body())
                            .foregroundStyle(LDColor.inkPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, LDSpacing.sm)
                    }
                }
                .padding(.horizontal, LDSpacing.sm)
                .background(LDColor.surfaceMuted)
                .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var translateButton: some View {
        Button {
            viewModel.requestTranslation()
        } label: {
            HStack {
                Spacer()
                if viewModel.isTranslating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Translate")
                        .font(LDTypography.bodyBold())
                }
                Spacer()
            }
        }
        .buttonStyle(LDPrimaryButtonStyle())
        .disabled(!viewModel.canTranslate)
    }

    @ViewBuilder
    private var resultSection: some View {
        if viewModel.isTranslating || viewModel.isProcessingVoiceCapture {
            LDLoadingStateView(title: viewModel.selectedInputMode == .voice ? "Translating speech" : "Translating text")
        } else if let result = viewModel.currentResult {
            LDCard {
                VStack(alignment: .leading, spacing: LDSpacing.md) {
                    VStack(alignment: .leading, spacing: LDSpacing.xs) {
                        Text(result.inputMode == .voice ? "Transcription" : "Original")
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)
                        Text(result.sourceText)
                            .font(LDTypography.body())
                            .foregroundStyle(LDColor.inkPrimary)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: LDSpacing.xs) {
                        Text("Translation")
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.inkSecondary)
                        Text(result.translatedText)
                            .font(LDTypography.section())
                            .foregroundStyle(LDColor.inkPrimary)
                    }

                    HStack {
                        Text(viewModel.sourceSelection.language == nil ? "Detected: \(result.sourceLanguageName)" : "Source: \(result.sourceLanguageName)")
                        Spacer()
                        Text("Target: \(result.targetLanguageName)")
                    }
                    .font(LDTypography.caption())
                    .foregroundStyle(LDColor.inkSecondary)

                    if let copyStatusMessage {
                        Text(copyStatusMessage)
                            .font(LDTypography.caption())
                            .foregroundStyle(LDColor.accent)
                    }

                    HStack(spacing: LDSpacing.sm) {
                        Button {
                            Task { await viewModel.toggleSaveForCurrentResult() }
                        } label: {
                            actionLabel(
                                icon: result.isSaved ? "bookmark.fill" : "bookmark",
                                title: result.isSaved ? "Saved" : "Save"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSavingResult)

                        Button {
                            Task { await viewModel.toggleFavoriteForCurrentResult() }
                        } label: {
                            actionLabel(
                                icon: result.isFavorited ? "heart.fill" : "heart",
                                title: result.isFavorited ? "Favorited" : "Favorite"
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isSavingResult)

                        Button {
                            UIPasteboard.general.string = result.translatedText
                            viewModel.trackCopiedCurrentResult()
                            showCopyMessage("Copied translation")
                        } label: {
                            actionLabel(icon: "doc.on.doc", title: "Copy")
                        }
                        .buttonStyle(.plain)

                        ShareLink(item: result.shareText) {
                            actionLabel(icon: "square.and.arrow.up", title: "Share")
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.trackSharedCurrentResult()
                        })
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            LDEmptyStateView(
                title: "Your translation will appear here",
                subtitle: viewModel.selectedInputMode == .voice
                    ? "Pick a target language, speak into the microphone, and stop recording to translate it."
                    : "Pick a target language, type some text, and translate it to see the result.",
                actionTitle: nil,
                action: nil
            )
        }
    }

    private func languageSelectionLabel(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: LDSpacing.xxs) {
            Text(title)
                .font(LDTypography.caption())
                .foregroundStyle(LDColor.inkSecondary)
            HStack(spacing: LDSpacing.xs) {
                Text(value)
                    .font(LDTypography.bodyBold())
                    .foregroundStyle(LDColor.inkPrimary)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LDColor.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LDSpacing.sm)
        .padding(.vertical, LDSpacing.sm)
        .background(LDColor.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
    }

    private func actionLabel(icon: String, title: String) -> some View {
        VStack(spacing: LDSpacing.xxs) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(LDTypography.caption())
        }
        .foregroundStyle(LDColor.accent)
        .frame(maxWidth: .infinity)
        .padding(.vertical, LDSpacing.xs)
        .background(LDColor.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
    }

    private var voicePrimaryActionTitle: String {
        if viewModel.isProcessingVoiceCapture {
            return "Preparing Translation"
        }

        return viewModel.isListeningForVoice ? "Stop and Translate" : "Start Listening"
    }

    private var voiceStatusTitle: String {
        if viewModel.isProcessingVoiceCapture {
            return "Processing your speech"
        }

        return viewModel.isListeningForVoice ? "Listening now" : "Ready when you are"
    }

    private var voiceStatusSubtitle: String {
        if viewModel.isProcessingVoiceCapture {
            return "We're finalizing the transcript and sending it to translation."
        }

        return viewModel.isListeningForVoice
            ? "Speak clearly, then tap stop when you're done."
            : "LinguaDaily will transcribe your speech first, then translate it into your selected target language."
    }

    private func showCopyMessage(_ message: String) {
        copyStatusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if copyStatusMessage == message {
                    copyStatusMessage = nil
                }
            }
        }
    }
}

struct SavedTranslationsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: SavedTranslationsViewModel

    init(viewModel: SavedTranslationsViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: LDSpacing.md) {
                LDSearchField(placeholder: "Search saved translations", text: $viewModel.query)
                    .onChange(of: viewModel.query) { _, newValue in
                        viewModel.updateQuery(newValue)
                    }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: LDSpacing.xs) {
                        ForEach(TranslationLibraryFilter.allCases, id: \.self) { filter in
                            LDFilterChip(title: filter.title, isActive: viewModel.filter == filter) {
                                viewModel.updateFilter(filter)
                            }
                        }
                    }
                }

                if let bannerError = viewModel.bannerError {
                    LDErrorStateView(error: bannerError) {
                        viewModel.clearBannerError()
                    }
                }

                content
            }
            .padding(LDSpacing.lg)
            .navigationTitle("Saved Translations")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: UUID.self) { translationID in
                SavedTranslationDetailView(viewModel: viewModel, translationID: translationID)
            }
        }
        .background(LDColor.background.ignoresSafeArea())
        .task {
            await viewModel.load()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .idle, .loading:
            LDLoadingStateView(title: "Loading saved translations")
        case let .failure(error):
            LDErrorStateView(error: error) {
                Task { await viewModel.load() }
            }
        case .empty:
            LDEmptyStateView(
                title: viewModel.filter == .favorites ? "No favorite translations yet" : "No saved translations yet",
                subtitle: viewModel.query.isEmpty
                    ? "Save a useful translation from the Translate tab to build your library."
                    : "Try a different search term or switch filters.",
                actionTitle: viewModel.query.isEmpty ? nil : "Clear search",
                action: viewModel.query.isEmpty ? nil : {
                    viewModel.updateQuery("")
                }
            )
        case let .success(translations):
            ScrollView {
                VStack(spacing: LDSpacing.sm) {
                    ForEach(translations) { translation in
                        NavigationLink(value: translation.id) {
                            LDCard {
                                HStack(alignment: .top, spacing: LDSpacing.sm) {
                                    VStack(alignment: .leading, spacing: LDSpacing.xs) {
                                        Text(translation.sourceText)
                                            .font(LDTypography.bodyBold())
                                            .foregroundStyle(LDColor.inkPrimary)
                                            .lineLimit(2)
                                        Text(translation.translatedText)
                                            .font(LDTypography.body())
                                            .foregroundStyle(LDColor.inkPrimary)
                                            .lineLimit(2)
                                        Text("\(translation.languagePairLabel) • \(translation.inputMode.title)")
                                            .font(LDTypography.caption())
                                            .foregroundStyle(LDColor.inkSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: translation.isFavorited ? "heart.fill" : "chevron.right")
                                        .foregroundStyle(translation.isFavorited ? LDColor.danger : LDColor.inkSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct SavedTranslationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: SavedTranslationsViewModel
    let translationID: UUID
    @State private var copyStatusMessage: String?

    var body: some View {
        Group {
            if let translation = viewModel.translation(id: translationID) {
                ScrollView {
                    VStack(spacing: LDSpacing.md) {
                        LDCard {
                            VStack(alignment: .leading, spacing: LDSpacing.md) {
                                VStack(alignment: .leading, spacing: LDSpacing.xs) {
                                    Text("Original")
                                        .font(LDTypography.caption())
                                        .foregroundStyle(LDColor.inkSecondary)
                                    Text(translation.sourceText)
                                        .font(LDTypography.body())
                                        .foregroundStyle(LDColor.inkPrimary)
                                }

                                Divider()

                                VStack(alignment: .leading, spacing: LDSpacing.xs) {
                                    Text("Translation")
                                        .font(LDTypography.caption())
                                        .foregroundStyle(LDColor.inkSecondary)
                                    Text(translation.translatedText)
                                        .font(LDTypography.section())
                                        .foregroundStyle(LDColor.inkPrimary)
                                }

                                HStack {
                                    Text(translation.languagePairLabel)
                                    Spacer()
                                    Text(translation.inputMode.title)
                                }
                                .font(LDTypography.caption())
                                .foregroundStyle(LDColor.inkSecondary)

                                if let copyStatusMessage {
                                    Text(copyStatusMessage)
                                        .font(LDTypography.caption())
                                        .foregroundStyle(LDColor.accent)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        LDCard {
                            VStack(spacing: LDSpacing.sm) {
                                Button {
                                    Task { await viewModel.toggleFavorite(id: translation.id) }
                                } label: {
                                    detailActionRow(
                                        icon: translation.isFavorited ? "heart.fill" : "heart",
                                        title: translation.isFavorited ? "Remove favorite" : "Add favorite"
                                    )
                                }
                                .buttonStyle(.plain)

                                Button {
                                    UIPasteboard.general.string = translation.translatedText
                                    viewModel.trackCopiedTranslation(id: translation.id)
                                    showCopyMessage("Copied translation")
                                } label: {
                                    detailActionRow(icon: "doc.on.doc", title: "Copy translation")
                                }
                                .buttonStyle(.plain)

                                ShareLink(item: translation.shareText) {
                                    detailActionRow(icon: "square.and.arrow.up", title: "Share")
                                }
                                .simultaneousGesture(TapGesture().onEnded {
                                    viewModel.trackSharedTranslation(id: translation.id)
                                })

                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.removeSave(id: translation.id)
                                        dismiss()
                                    }
                                } label: {
                                    detailActionRow(icon: "trash", title: "Remove from saved")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(LDSpacing.lg)
                }
            } else {
                LDEmptyStateView(
                    title: "Translation removed",
                    subtitle: "This translation is no longer saved in your library.",
                    actionTitle: "Close",
                    action: {
                        dismiss()
                    }
                )
                .padding(LDSpacing.lg)
            }
        }
        .background(LDColor.background.ignoresSafeArea())
        .navigationTitle("Translation")
        .task {
            viewModel.trackDetailOpened(id: translationID)
        }
    }

    private func detailActionRow(icon: String, title: String) -> some View {
        HStack(spacing: LDSpacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
            Text(title)
                .font(LDTypography.bodyBold())
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(LDColor.inkSecondary)
        }
        .foregroundStyle(LDColor.inkPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, LDSpacing.sm)
        .padding(.vertical, LDSpacing.sm)
        .background(LDColor.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: LDRadius.md, style: .continuous))
    }

    private func showCopyMessage(_ message: String) {
        copyStatusMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                if copyStatusMessage == message {
                    copyStatusMessage = nil
                }
            }
        }
    }
}

private struct TranslationLanguagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let title: String
    let availableLanguages: [Language]
    let selectedLanguageCode: String?
    let supportsAutoDetect: Bool
    let targetLanguageCode: String?
    let onSelect: (TranslationSourceSelection) -> Void

    var body: some View {
        NavigationStack {
            List {
                if supportsAutoDetect {
                    Button {
                        onSelect(.autoDetect)
                        dismiss()
                    } label: {
                        HStack {
                            Text("Auto-detect")
                                .foregroundStyle(LDColor.inkPrimary)
                            Spacer()
                            if selectedLanguageCode == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(LDColor.accent)
                            }
                        }
                    }
                }

                ForEach(availableLanguages) { language in
                    Button {
                        onSelect(.manual(language))
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: LDSpacing.xxs) {
                                Text(language.name)
                                    .foregroundStyle(LDColor.inkPrimary)
                                Text(language.nativeName)
                                    .font(LDTypography.caption())
                                    .foregroundStyle(LDColor.inkSecondary)
                            }
                            Spacer()
                            if selectedLanguageCode == language.code {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(LDColor.accent)
                            } else if targetLanguageCode == language.code {
                                Text("Target")
                                    .font(LDTypography.caption())
                                    .foregroundStyle(LDColor.inkSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return TranslateView(
        viewModel: TranslateViewModel(
            onboardingService: dependencies.onboardingService,
            translationService: dependencies.translationService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService,
            appState: dependencies.appState
        ),
        savedLibraryViewModel: SavedTranslationsViewModel(
            translationService: dependencies.translationService,
            analytics: dependencies.analyticsService,
            crash: dependencies.crashService
        )
    )
    .environmentObject(dependencies.appState)
    .environmentObject(dependencies)
}
