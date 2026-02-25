// MARK: - Cursor

/// Describes the terminal cursor's position, shape, and blink state.
///
/// When a ``Cursor`` is set on ``ViewOutput``, the renderer shows the terminal
/// cursor at the specified position with the given shape. When ``ViewOutput/cursor``
/// is `nil`, the cursor is hidden.
///
/// ## Example
///
/// ```swift
/// func view() -> ViewOutput {
///     ViewOutput(
///         "Enter name: \(name)",
///         cursor: Cursor(position: .init(col: cursorCol, row: 0))
///     )
/// }
/// ```
public struct Cursor: Sendable, Equatable {

    /// The cursor's position relative to the view content.
    public var position: Position

    /// The cursor's shape (block, underline, or bar).
    public var shape: Shape

    /// Whether the cursor should blink.
    public var blink: Bool

    /// Create a cursor with the given position, shape, and blink state.
    ///
    /// - Parameters:
    ///   - position: The position relative to the view content (0-based row and column).
    ///   - shape: The cursor shape (defaults to ``Shape/block``).
    ///   - blink: Whether the cursor blinks (defaults to `true`).
    public init(position: Position, shape: Shape = .block, blink: Bool = true) {
        self.position = position
        self.shape = shape
        self.blink = blink
    }
}

// MARK: - Cursor.Position

extension Cursor {

    /// A 0-based position within the view content.
    ///
    /// Both `col` and `row` are measured from the top-left corner of the
    /// rendered content string (not the terminal screen).
    public struct Position: Sendable, Equatable {

        /// The column (0-based).
        public var col: Int

        /// The row (0-based).
        public var row: Int

        /// Create a position with the given column and row.
        ///
        /// - Parameters:
        ///   - col: The column (0-based).
        ///   - row: The row (0-based).
        public init(col: Int, row: Int) {
            self.col = col
            self.row = row
        }
    }
}

// MARK: - Cursor.Shape

extension Cursor {

    /// The visual shape of the terminal cursor.
    public enum Shape: Sendable, Equatable {
        /// A solid block cursor (█).
        case block
        /// A horizontal line below the character (_).
        case underline
        /// A vertical bar to the left of the character (|).
        case bar
    }
}
