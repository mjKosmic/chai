// MARK: - ViewOutput

/// The output of a view's ``View/body`` property.
///
/// `ViewOutput` carries rendered content as structured styled text. It serves
/// as a renderer-agnostic abstraction layer between the view tree and the
/// rendering backend.
///
/// Terminal state (alt screen, window title, cursor) is managed separately:
/// - Alt screen: ``Program/Option/withAltScreen`` (set at program creation)
/// - Window title: ``Command/setWindowTitle(_:)`` (fire-and-forget command)
/// - Cursor: ``Model/cursor`` (property on the model protocol)
///
/// ## Simple usage (string-only)
///
/// Return a string literal directly — `ViewOutput` conforms to
/// `ExpressibleByStringInterpolation`:
///
/// ```swift
/// var body: ViewOutput {
///     "Count: \(count)\n"
/// }
/// ```
///
/// ## Styled content
///
/// Use `StyledText` for structured styling without raw ANSI codes:
///
/// ```swift
/// var body: ViewOutput {
///     ViewOutput("Error: ".fg(.red).bold() + "file not found")
/// }
/// ```
public struct ViewOutput: Sendable, Equatable {

    /// The rendered content as structured styled text.
    public var content: StyledText

    /// Create a view output with styled content.
    ///
    /// - Parameter content: The rendered UI as styled text.
    public init(_ content: StyledText) {
        self.content = content
    }

    /// Create a view output from a plain string.
    ///
    /// The string is wrapped in a ``StyledText`` with default styling.
    ///
    /// Any ANSI escape sequences in `content` are removed before the text
    /// reaches layout, so the remaining characters are painted as plain text
    /// and contribute no display width. Styling is carried structurally: use
    /// ``init(_:)`` with a ``StyledText`` built via `Style.styledText(_:)`
    /// instead of embedding escape codes in the string.
    public init(_ content: String) {
        self.init(StyledText(content))
    }
}

// MARK: - String literal support

extension ViewOutput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        // Route through init(_ content: String) so escape sequences are stripped
        // consistently, whether the caller uses a string literal or a String.
        self.init(value)
    }
}

extension ViewOutput: ExpressibleByStringInterpolation {
    public typealias StringInterpolation = StyledText.StringInterpolation

    public init(stringInterpolation: StyledText.StringInterpolation) {
        self.init(StyledText(stringInterpolation: stringInterpolation))
    }
}
