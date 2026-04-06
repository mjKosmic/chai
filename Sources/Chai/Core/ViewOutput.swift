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
    /// - Important: The string must be **plain text** with no embedded ANSI escape sequences.
    ///   Passing `Style.render(...)` output or other ANSI-encoded strings will cause escape
    ///   bytes to be treated as literal characters by the cell-buffer renderer, corrupting
    ///   the display and width calculations. Use ``init(_:)`` with a ``StyledText`` built
    ///   via `Style.styledText(_:)` (from Spices' `StyleBridge`) instead.
    public init(_ content: String) {
        assert(
            !content.contains("\u{1B}"),
            "ViewOutput(String) received a string with embedded ANSI escape sequences. "
            + "Use Style.styledText(_:) and ViewOutput(StyledText) instead, otherwise "
            + "escape bytes will be treated as literal characters by the cell-buffer renderer."
        )
        self.init(StyledText(content))
    }
}

// MARK: - String literal support

extension ViewOutput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        // Route through init(_ content: String) so the ESC-byte assertion is applied
        // consistently, whether the caller uses a string literal or passes a String directly.
        self.init(value)
    }
}

extension ViewOutput: ExpressibleByStringInterpolation {
    public typealias StringInterpolation = StyledText.StringInterpolation

    public init(stringInterpolation: StyledText.StringInterpolation) {
        self.init(StyledText(stringInterpolation: stringInterpolation))
    }
}
