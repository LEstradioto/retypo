import SwiftUI

/// Experimental live-translation card under the input box. Read-only
/// preview: translates the input as you type and never modifies it.
struct TranslationCardView: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                languageMenu
                engineMenu
                Spacer()
                if state.liveTranslationBusy {
                    ProgressView().controlSize(.small)
                }
                copyButton
            }
            translationBody
        }
        .padding(8)
        .background(cardBackground)
        .overlay(cardStroke)
        .appleTranslationTask()
    }

    private var languageMenu: some View {
        Menu {
            ForEach(TargetLanguage.supported) { language in
                Button(language.name) { state.setLiveTranslationTarget(language.code) }
            }
        } label: {
            Text(TargetLanguage.named(state.settings.liveTranslationTarget).name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .fixedSize()
    }

    private var engineMenu: some View {
        Menu {
            ForEach(LiveTranslationEngine.allCases, id: \.self) { engine in
                Button(engine.displayName) { state.setLiveTranslationEngine(engine) }
            }
        } label: {
            Text(state.settings.liveTranslationEngine.displayName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Palette.secondaryText)
        }
        .fixedSize()
    }

    @ViewBuilder
    private var translationBody: some View {
        if let error = state.liveTranslationError {
            Text(error)
                .font(.system(size: 11))
                .foregroundStyle(Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            ScrollView {
                Text(state.liveTranslationText.isEmpty ? hint : state.liveTranslationText)
                    .font(.system(size: 12))
                    .foregroundStyle(state.liveTranslationText.isEmpty ? Palette.secondaryText : Palette.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 72)
        }
    }

    private var hint: String {
        "Translation appears here as you type."
    }

    private var copyButton: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(state.liveTranslationText, forType: .string)
        } label: {
            Image(systemName: "doc.on.doc")
        }
        .buttonStyle(.plain)
        .disabled(state.liveTranslationText.isEmpty)
        .help("Copy translation")
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .fill(Palette.editor)
    }

    private var cardStroke: some View {
        RoundedRectangle(cornerRadius: 15, style: .continuous)
            .strokeBorder(Palette.hairline, lineWidth: 1)
    }
}
