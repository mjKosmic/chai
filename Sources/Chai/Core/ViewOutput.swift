// MARK: - ViewOutput

/// The output of a model's ``Model/view()`` method.
///
/// `ViewOutput` carries both the rendered content and optional
/// declarative terminal state. The renderer diffs the terminal state
/// between frames and automatically handles transitions (e.g. entering/exiting
/// the alternate screen buffer, changing the window title).
///
/// ## Simple usage (string-only)
///
/// When you only need to render text, return a string literal directly —
/// `ViewOutput` conforms to `ExpressibleByStringInterpolation`:
///
/// ```swift
/// func view() -> ViewOutput {
///     "Count: \(count)\n"
/// }
/// ```
///
/// ## Styled content
///
/// Use `StyledText` for structured styling without raw ANSI codes:
///
/// ```swift
/// func view() -> ViewOutput {
///     ViewOutput("Error: ".fg(.red).bold() + "file not found")
/// }
/// ```
///
/// ## Declarative terminal state
///
/// To control terminal features per-frame, construct a `ViewOutput` explicitly:
///
/// ```swift
/// func view() -> ViewOutput {
///     ViewOutput(
///         "Detail view content here...",
///         altScreen: isShowingDetail,
///         windowTitle: "My App - \(currentPage)",
///         cursor: Cursor(position: .init(col: cursorCol, row: 0))
///     )
/// }
/// ```
///
/// Terminal state fields default to `nil`, meaning "don't change from the
/// current state." This preserves backward compatibility with string-only views
/// and with program options like ``ProgramOption/withAltScreen``.
public struct ViewOutput: Sendable, Equatable {

    /// The rendered content as structured styled text.
    public var content: StyledText

    /// Whether the alternate screen buffer should be active.
    ///
    /// - `nil`: Don't change the current alt screen state.
    /// - `true`: Enter the alternate screen buffer.
    /// - `false`: Exit the alternate screen buffer.
    public var altScreen: Bool?

    /// The terminal window title.
    ///
    /// - `nil`: Don't change the current window title.
    /// - A string value: Set the window title to this value.
    public var windowTitle: String?

    /// The cursor to display.
    ///
    /// When non-`nil`, the terminal cursor is shown at the specified position
    /// with the given shape. When `nil`, the cursor is hidden automatically
    /// in alternate-screen mode; in normal (inline) mode the cursor state is
    /// left unchanged.
    public var cursor: Cursor?

    /// Create a view output with styled content and optional terminal state.
    ///
    /// - Parameters:
    ///   - content: The rendered UI as styled text.
    ///   - altScreen: Whether to use the alternate screen buffer (`nil` = don't change).
    ///   - windowTitle: The window title to set (`nil` = don't change).
    ///   - cursor: The cursor to display (`nil` = hidden in alt screen, unchanged in normal mode).
    public init(
        _ content: StyledText,
        altScreen: Bool? = nil,
        windowTitle: String? = nil,
        cursor: Cursor? = nil
    ) {
        self.content = content
        self.altScreen = altScreen
        self.windowTitle = windowTitle
        self.cursor = cursor
    }

    /// Create a view output from a plain string and optional terminal state.
    ///
    /// The string is wrapped in a ``StyledText`` with default styling.
    ///
    /// - Important: The string must be **plain text** with no embedded ANSI escape sequences.
    ///   Passing `Style.render(...)` output or other ANSI-encoded strings will cause escape
    ///   bytes to be treated as literal characters by the cell-buffer renderer, corrupting
    ///   the display and width calculations. Use ``init(_:altScreen:windowTitle:cursor:)-swift.init``
    ///   with a ``StyledText`` built via `Style.styledText(_:)` (from Spices' `StyleBridge`) instead.
    public init(
        _ content: String,
        altScreen: Bool? = nil,
        windowTitle: String? = nil,
        cursor: Cursor? = nil
    ) {
        assert(
            !content.contains("\u{1B}"),
            "ViewOutput(String) received a string with embedded ANSI escape sequences. "
            + "Use Style.styledText(_:) and ViewOutput(StyledText) instead, otherwise "
            + "escape bytes will be treated as literal characters by the cell-buffer renderer."
        )
        self.init(
            StyledText(content),
            altScreen: altScreen,
            windowTitle: windowTitle,
            cursor: cursor
        )
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
