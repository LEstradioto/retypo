import SwiftUI

extension RetypoView {
    /// The status line is the panel's only error surface and it truncates to a
    /// single line, which made API errors ("`temperature` is deprecated for
    /// this model") unreadable. On failure it turns red, carries the full text
    /// as a tooltip, and copies that text when clicked.
    var statusText: some View {
        Button { state.copyLastError() } label: {
            HStack(spacing: 3) {
                if hasError {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 9, weight: .semibold))
                }
                Text(state.status)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(hasError ? Color.red.opacity(0.85) : statColor)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(hasError)
        .help(hasError ? "\(errorDetail)\n\nClick to copy" : state.status)
    }

    private var hasError: Bool { state.lastErrorDetail != nil }

    private var errorDetail: String { state.lastErrorDetail ?? state.status }
}
