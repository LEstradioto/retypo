import SwiftUI
import AppKit

struct NativeTextEditor: NSViewRepresentable {
    @Binding var text: String
    var nativeSpellcheck: Bool
    var highlightRanges: [NSRange] = []
    var onSubmit: () -> Void
    var onRunAll: () -> Void = {}
    var onChange: () -> Void
    var onCancel: () -> Void = {}
    var onTab: () -> Bool = { false }
    var onShiftTab: () -> Bool = { false }
    var onFocusCycle: () -> Void = {}
    var onEnterInOverlay: () -> Bool = { false }
    var onToggleOverlay: () -> Void = {}
    var onSettings: () -> Void = {}
    var onUndo: () -> Bool = { false }
    var onRedo: () -> Bool = { false }
    var onShortcut: (String) -> Bool = { _ in false }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        let textView = KeyHandlingTextView()
        textView.delegate = context.coordinator
        bindCallbacks(to: textView)
        configure(textView)
        textView.string = text

        scroll.documentView = textView
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let textView = scroll.documentView as? KeyHandlingTextView else { return }
        let selected = textView.selectedRange()
        if textView.string != text {
            textView.string = text
            textView.undoManager?.removeAllActions()
            let safeLocation = min(selected.location, (text as NSString).length)
            textView.setSelectedRange(NSRange(location: safeLocation, length: 0))
        }
        bindCallbacks(to: textView)
        configure(textView)
        applyHighlights(to: textView)
    }

    private func bindCallbacks(to textView: KeyHandlingTextView) {
        textView.onSubmit = onSubmit
        textView.onRunAll = onRunAll
        textView.onCancel = onCancel
        textView.onTab = onTab
        textView.onShiftTab = onShiftTab
        textView.onFocusCycle = onFocusCycle
        textView.onEnterInOverlay = onEnterInOverlay
        textView.onToggleOverlay = onToggleOverlay
        textView.onSettings = onSettings
        textView.onUndo = onUndo
        textView.onRedo = onRedo
        textView.onShortcut = onShortcut
    }

    private func configure(_ textView: KeyHandlingTextView) {
        textView.isRichText = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isContinuousSpellCheckingEnabled = nativeSpellcheck
        textView.isGrammarCheckingEnabled = nativeSpellcheck
        textView.isAutomaticSpellingCorrectionEnabled = nativeSpellcheck
        textView.font = NSFont.monospacedSystemFont(ofSize: 15, weight: .regular)
        textView.textColor = NSColor.labelColor
        textView.insertionPointColor = NSColor.labelColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 16, height: 16)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
    }

    private func applyHighlights(to textView: NSTextView) {
        guard let layoutManager = textView.layoutManager else { return }
        let full = NSRange(location: 0, length: (textView.string as NSString).length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)
        layoutManager.removeTemporaryAttribute(.foregroundColor, forCharacterRange: full)
        let color = NSColor.systemGreen.withAlphaComponent(0.28)
        let underline = NSColor.systemGreen.withAlphaComponent(0.60)
        for range in highlightRanges where NSMaxRange(range) <= full.length {
            layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
            layoutManager.addTemporaryAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, forCharacterRange: range)
            layoutManager.addTemporaryAttribute(.underlineColor, value: underline, forCharacterRange: range)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NativeTextEditor
        init(_ parent: NativeTextEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
            guard !textView.hasMarkedText() else { return }
            parent.onChange()
        }
    }
}
