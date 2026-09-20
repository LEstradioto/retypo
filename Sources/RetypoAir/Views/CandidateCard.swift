import SwiftUI

struct CandidateCard: View {
    var candidate: CandidateResult
    var selected: Bool
    var select: () -> Void
    var apply: () -> Void

    private var isFreeform: Bool { candidate.action.id == EditAction.freeformID }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if isFreeform {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.retypoAccent.opacity(0.95))
                }
                Text(candidate.action.title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer()
                Text(candidate.costUSD.map { String(format: "$%.4f", $0) } ?? "$—")
                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(candidate.diff)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(height: 120)
            HStack {
                Button("Select") { select() }
                    .buttonStyle(.borderless)
                    .pointingCursor()
                Spacer()
                Button("Apply") { apply() }
                    .buttonStyle(.borderless)
                    .pointingCursor()
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(cardFill))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(cardStroke, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture { select() }
        .pointingCursor()
    }

    private var cardFill: Color {
        if selected { return Color.retypoAccent.opacity(0.15) }
        if isFreeform { return Color.retypoAccent.opacity(0.10) }
        return Color.white.opacity(0.08)
    }

    private var cardStroke: Color {
        if selected { return Color.retypoAccent.opacity(0.55) }
        if isFreeform { return Color.retypoAccent.opacity(0.30) }
        return Color.white.opacity(0.12)
    }
}
