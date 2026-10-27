import AppKit
import SwiftUI

/// The Enhanced section of the mode editor: attach files and folders the
/// mode may consult and switch web search on. Files dropped from Finder
/// attach too.
struct ModeEnhancementEditor: View {
    @EnvironmentObject private var state: AppState
    let action: EditAction
    @State private var preview: EnhancementPreview?
    @State private var dropTargeted = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: enhancedBinding) {
                Label("Enhanced", systemImage: "sparkles")
                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .help("Let this mode consult files, folders and the web before it answers")
            if enhancement.isOn { options }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !enhancement.sources.isEmpty {
                ReferenceChips(sources: enhancement.sources) { state.detachReference($0, modeID: action.id) }
            }
            controls
            Text(preview?.summary ?? "…")
                .foregroundStyle(Palette.secondaryText)
            if let warning = preview?.warning {
                Text(warning)
                    .foregroundStyle(Color.retypoAccent)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 9).fill(Palette.editor))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(dropTargeted ? Color.retypoAccent : Palette.hairline, lineWidth: 1))
        .dropDestination(for: URL.self) { urls, _ in
            state.attachReferences(urls, modeID: action.id)
            return !urls.isEmpty
        } isTargeted: { dropTargeted = $0 }
        .task(id: previewKey) {
            preview = await EnhancementPreview.make(enhancement, provider: state.settings.provider)
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button { attachFromOpenPanel() } label: { Label("Add files or folders", systemImage: "plus") }
                .buttonStyle(.borderless)
            Toggle("Search the web", isOn: webSearchBinding)
                .toggleStyle(.checkbox)
            Spacer(minLength: 0)
        }
    }

    private var enhancement: ModeEnhancement { action.enhancement ?? ModeEnhancement(isOn: false) }

    private var previewKey: EnhancementPreview.Key {
        EnhancementPreview.Key(sources: enhancement.sources, webSearch: enhancement.webSearch, provider: state.settings.provider)
    }

    private var enhancedBinding: Binding<Bool> {
        Binding(get: { enhancement.isOn }, set: { state.setEnhanced($0, modeID: action.id) })
    }

    private var webSearchBinding: Binding<Bool> {
        Binding(get: { enhancement.webSearch }, set: { state.setWebSearch($0, modeID: action.id) })
    }

    private func attachFromOpenPanel() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Attach"
        panel.message = "Files and folders this mode may consult. Their text goes to your model provider when the mode runs."
        guard panel.runModal() == .OK else { return }
        state.attachReferences(panel.urls, modeID: action.id)
    }
}

/// Attached sources as removable chips; the tooltip shows the full path.
private struct ReferenceChips: View {
    let sources: [ReferenceSource]
    let remove: (ReferenceSource) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(sources) { source in chip(source) }
            }
        }
    }

    private func chip(_ source: ReferenceSource) -> some View {
        HStack(spacing: 4) {
            Image(systemName: source.isFolder ? "folder" : "doc.text")
            Text(source.name).lineLimit(1)
            Button { remove(source) } label: { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.tertiaryText)
                .help("Detach \(source.name)")
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule(style: .continuous).fill(Palette.card))
        .overlay(Capsule(style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
        .help(source.path)
    }
}
