import SwiftUI

/// Track-changes styling for a `TextDiff`, shared by the review over the
/// editor and the run-all cards: removed text red and struck through, added
/// text with the editor's green tint, line breaks inside an edit shown as ¶.
enum TrackChanges {
    static func attributed(_ diff: TextDiff) -> AttributedString {
        diff.segments.reduce(into: AttributedString()) { text, segment in
            switch segment {
            case .kept(let kept):
                text += AttributedString(kept)
            case .edit(let removed, let added):
                text += styled(removed, removedStyle)
                text += styled(added, addedStyle)
            }
        }
    }

    /// Without the ¶ a removed line break would be invisible.
    static func styled(_ text: String, _ style: AttributeContainer) -> AttributedString {
        let marked = text.reduce(into: "") { result, character in
            if character.isNewline { result.append("¶") }
            result.append(character)
        }
        return AttributedString(marked, attributes: style)
    }

    static var removedStyle: AttributeContainer {
        var style = AttributeContainer()
        style.swiftUI.foregroundColor = Color(nsColor: ChangeColors.removed)
        style.swiftUI.backgroundColor = Color(nsColor: ChangeColors.removedTint)
        style.swiftUI.strikethroughStyle = Text.LineStyle(pattern: .solid, color: Color(nsColor: ChangeColors.removed))
        return style
    }

    static var addedStyle: AttributeContainer {
        var style = AttributeContainer()
        style.swiftUI.backgroundColor = Color(nsColor: ChangeColors.addedTint)
        style.swiftUI.underlineStyle = Text.LineStyle(pattern: .solid, color: Color(nsColor: ChangeColors.addedUnderline))
        return style
    }
}

/// The last run as track changes, laid over the editor in its font and
/// margins. Read-only: a click, Esc, ⌘⇧D or the next keystroke (which still
/// reaches the editor underneath) returns to editing.
struct ChangeReviewOverlay: View {
    @EnvironmentObject var state: AppState
    let diff: TextDiff

    var body: some View {
        ScrollView {
            Text(TrackChanges.attributed(diff))
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Color(nsColor: state.editorFontColor ?? .labelColor))
                .frame(maxWidth: .infinity, alignment: .leading)
                // NSTextView's 16-pt inset plus its 5-pt line fragment padding.
                .padding(.horizontal, 21)
                .padding(.vertical, 16)
        }
        .contentShape(Rectangle())
        .onTapGesture { state.closeChangeReview() }
        .help("Click or press Esc to go back to editing")
    }
}

extension View {
    /// Lays the review over the editor while it is on. The editor stays,
    /// hidden rather than removed, so it keeps focus and the next keystroke
    /// both reaches it and ends the review.
    func changeReview(_ state: AppState) -> some View {
        opacity(state.isReviewingChanges ? 0 : 1)
            .overlay { if state.isReviewingChanges { ChangeReviewOverlay(diff: state.inlineChanges) } }
    }
}

/// Footer Δ: how many places the last run changed. Clicking it (or ⌘⇧D)
/// shows them as track changes while the editor still holds that result.
struct ChangeCountButton: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        Button { state.toggleChangeReview() } label: {
            Text("Δ\(state.wordsChangedLast)")
                .foregroundStyle(state.wordsChangedLast == 0 ? Palette.secondaryText : Color.retypoAccent)
                .monospacedDigit()
                .padding(.horizontal, state.isReviewingChanges ? 5 : 0)
                .background(Capsule(style: .continuous).fill(state.isReviewingChanges ? Color.retypoAccent.opacity(0.15) : Color.clear))
        }
        .buttonStyle(.plain)
        .disabled(!state.inlineChanges.hasEdits)
        .help(state.isReviewingChanges ? "Back to editing (⌘⇧D)" : "Show what the last run changed (⌘⇧D)")
        .pointingCursor()
    }
}
