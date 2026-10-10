// MARK: - Model

/// The core protocol every Chai application model must conform to.
///
/// A model encapsulates your application's entire state and conforms to
/// ``View``. Chai calls the lifecycle methods in a tight loop to drive the UI:
///
/// 1. ``initialize()`` is called once at startup.
/// 2. ``update(_:)`` is called whenever a message arrives.
/// 3. ``body`` (from ``View``) is read after every update to produce the rendered output.
///
/// Terminal state is managed separately from the view tree:
/// - Alt screen: ``Program/Option/withAltScreen`` (set at program creation)
/// - Window title: ``Command/setWindowTitle(_:)`` (fire-and-forget command)
/// - Cursor: ``cursor`` (property on this protocol, default `nil`)
///
/// ## Example
///
/// ```swift
/// struct Counter: Model {
///     var count = 0
///
///     func initialize() -> Command? { nil }
///
///     mutating func update(_ msg: any Message) -> Command? {
///         guard let key = msg as? KeyMsg else { return nil }
///         switch key.type {
///         case .ctrl("c"):
///             return .quit
///         case .up:
///             count += 1
///         case .down:
///             count -= 1
///         default:
///             break
///         }
///         return nil
///     }
///
///     var body: ViewOutput {
///         "Count: \(count)\n\nPress ↑/↓ to change, Ctrl+C to quit.\n"
///     }
/// }
/// ```
public protocol Model: View, Sendable {
    /// Called once when the program starts.
    ///
    /// Return a ``Command`` to perform initial I/O (e.g. load data, start a
    /// timer), or `nil` if no initial work is needed.
    mutating func initialize() -> Command?

    /// Called whenever a ``Message`` is received.
    ///
    /// Inspect the message, mutate your model's state as needed, and
    /// optionally return a ``Command`` to trigger further asynchronous work.
    ///
    /// - Parameter msg: The incoming message.
    /// - Returns: An optional command to execute, or `nil`.
    mutating func update(_ msg: any Message) -> Command?

    /// The terminal cursor to display.
    ///
    /// When non-`nil`, the renderer shows the terminal cursor at the
    /// specified position with the given shape. When `nil` (the default),
    /// the cursor is hidden in alt-screen mode and left unchanged in
    /// normal mode.
    ///
    /// Components that track cursor state (e.g. text inputs) expose their
    /// cursor position as properties. Wire them here:
    ///
    /// ```swift
    /// var cursor: Cursor? {
    ///     Cursor(position: .init(col: textInput.cursorCol, row: textInput.cursorRow))
    /// }
    /// ```
    var cursor: Cursor? { get }
}

// MARK: - Defaults

extension Model {
    /// Default cursor is `nil` (hidden in alt screen, unchanged in normal mode).
    public var cursor: Cursor? { nil }
}
