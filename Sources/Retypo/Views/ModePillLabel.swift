import SwiftUI

/// A mode's pill in the Cmd+D picker. Enhanced modes carry a sparkle, so a
/// mode that reads files or searches the web (and takes longer) is
/// recognizable before it runs.
struct ModePillLabel: View {
    let action: EditAction
    let selected: Bool

    var body: some View {
        HStack(spacing: 3) {
            if action.isEnhanced {
                Image(systemName: "sparkles").font(.system(size: 9, weight: .semibold))
            }
            Text(action.title)
        }
        .font(.system(size: 11, weight: selected ? .semibold : .medium, design: .rounded))
        .foregroundStyle(selected ? Color.white : Palette.primaryText)
        .padding(.horizontal, 11)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(selected ? Color.retypoAccent : Palette.card))
        .overlay(Capsule(style: .continuous).strokeBorder(selected ? Color.clear : Palette.hairline, lineWidth: 1))
    }
}
