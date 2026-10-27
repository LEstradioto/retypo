import Foundation

extension URL {
    /// Construct a `URL` from a string literal known at compile time to be valid.
    /// Traps with a clear message if the literal is malformed (caught by tests / first launch).
    init(staticString: StaticString) {
        guard let url = URL(string: "\(staticString)") else {
            preconditionFailure("invalid static URL: \(staticString)")
        }
        self = url
    }
}
