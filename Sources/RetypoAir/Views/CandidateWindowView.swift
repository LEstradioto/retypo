import SwiftUI

/// Candidate results overlay. Mode picking moved to the header picker
/// (Cmd+D); this panel only shows multi-run results for apply/copy.
struct CandidateOverlayWindowView: View {
    @EnvironmentObject private var state: AppState
    private let cardSpacing: CGFloat = 10

    var body: some View {
        ZStack {
            Palette.window.ignoresSafeArea()
            content
        }
        .tint(Color.retypoAccent)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Palette.hairline, lineWidth: 1))
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 8) {
            header
            candidates
        }
        .padding(12)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("Candidates")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
            Text("Tab selects + copies · Apply writes back")
                .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Palette.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer()
            Button { state.setCandidateOverlayVisible(false) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
            }
            .buttonStyle(.plain)
            .pointingCursor()
        }
    }

    private var candidates: some View {
        GeometryReader { proxy in
            let width = responsiveCardWidth(
                available: proxy.size.width,
                count: state.candidateResults.count,
                preferred: 260,
                minimum: 180
            )
            ScrollViewReader { scrollProxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: cardSpacing) {
                        ForEach(Array(state.candidateResults.enumerated()), id: \.element.id) { index, candidate in
                            CandidateCard(candidate: candidate, selected: index == state.selectedCandidateIndex) {
                                state.selectCandidate(at: index)
                            } apply: {
                                state.selectedCandidateIndex = index
                                state.restoreSelectedCandidateToEditor()
                            }
                            .id(candidate.id)
                            .frame(width: width)
                        }
                    }
                    .frame(minWidth: proxy.size.width, alignment: .leading)
                    .padding(.bottom, 2)
                }
                .onAppear { scrollToSelectedCandidate(using: scrollProxy) }
                .onChange(of: state.selectedCandidateIndex) { _ in
                    scrollToSelectedCandidate(using: scrollProxy)
                }
                .onChange(of: state.candidateResults.count) { _ in
                    scrollToSelectedCandidate(using: scrollProxy)
                }
            }
        }
        .frame(height: 178)
    }

    private func responsiveCardWidth(available: CGFloat, count: Int, preferred: CGFloat, minimum: CGFloat) -> CGFloat {
        let available = max(1, available)
        guard count > 0 else { return min(preferred, available) }
        let visibleColumns: Int
        if available < 420 {
            visibleColumns = 1
        } else if available < 760 {
            visibleColumns = min(2, count)
        } else {
            visibleColumns = min(3, count)
        }
        let usable = available - CGFloat(max(0, visibleColumns - 1)) * cardSpacing
        let calculated = usable / CGFloat(max(1, visibleColumns))
        let clamped = min(preferred, max(minimum, calculated))
        return min(clamped, available)
    }

    private func scrollToSelectedCandidate(using proxy: ScrollViewProxy) {
        guard state.candidateResults.indices.contains(state.selectedCandidateIndex) else { return }
        let id = state.candidateResults[state.selectedCandidateIndex].id
        scrollTo(id, using: proxy)
    }

    private func scrollTo<ID: Hashable>(_ id: ID, using proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.16)) {
                proxy.scrollTo(id, anchor: .center)
            }
        }
    }
}
