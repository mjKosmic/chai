// MARK: - ViewOutput

/// The output of a model's ``Model/view()`` method.
///
/// `ViewOutput` carries both the rendered content string and optional
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
/// ## Declarative terminal state
///
/// To control terminal features per-frame, construct a `ViewOutput` explicitly:
///
/// ```swift
/// func view() -> ViewOutput {
///     ViewOutput(
///         "Detail view content here...",
///         altScreen: isShowingDetail,
///         windowTitle: "My App - \(currentPage)"
///     )
/// }
/// ```
///
/// Terminal state fields default to `nil`, meaning "don't change from the
/// current state." This preserves backward compatibility with string-only views
/// and with program options like ``ProgramOption/withAltScreen``.
public struct ViewOutput: Sendable, Equatable {

    /// The rendered content string. Supports `\n` for line breaks and
    /// ANSI escape codes for colour and styling.
    public var content: String

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

    /// Whether the cursor should be hidden.
    ///
    /// - `nil`: Don't change the current cursor visibility.
    /// - `true`: Hide the cursor.
    /// - `false`: Show the cursor.
    public var cursorHidden: Bool?

    /// Create a view output with content and optional terminal state.
    ///
    /// - Parameters:
    ///   - content: The rendered UI as a string.
    ///   - altScreen: Whether to use the alternate screen buffer (`nil` = don't change).
    ///   - windowTitle: The window title to set (`nil` = don't change).
    ///   - cursorHidden: Whether to hide the cursor (`nil` = don't change).
    public init(
        _ content: String,
        altScreen: Bool? = nil,
        windowTitle: String? = nil,
        cursorHidden: Bool? = nil
    ) {
        self.content = content
        self.altScreen = altScreen
        self.windowTitle = windowTitle
        self.cursorHidden = cursorHidden
    }
}

// MARK: - String literal support

extension ViewOutput: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

extension ViewOutput: ExpressibleByStringInterpolation {
    public init(stringInterpolation: DefaultStringInterpolation) {
        self.init(String(stringInterpolation: stringInterpolation))
    }
}

// MARK: - Model

/// The core protocol every Chai application model must conform to.
///
/// A model encapsulates your application's entire state. Chai calls the
/// three methods below in a tight loop to drive the UI:
///
/// 1. ``initialize()`` is called once at startup.
/// 2. ``update(_:)`` is called whenever a message arrives.
/// 3. ``view()`` is called after every update to produce the rendered output.
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
///     func view() -> ViewOutput {
///         "Count: \(count)\n\nPress ↑/↓ to change, Ctrl+C to quit.\n"
///     }
/// }
/// ```
public protocol Model: Sendable {
    /// Called once when the program starts.
    ///
    /// Return a ``Command`` to perform initial I/O (e.g. load data, start a
    /// timer), or `nil` if no initial work is needed.
    func initialize() -> Command?

    /// Called whenever a ``Message`` is received.
    ///
    /// Inspect the message, mutate your model's state as needed, and
    /// optionally return a ``Command`` to trigger further asynchronous work.
    ///
    /// - Parameter msg: The incoming message.
    /// - Returns: An optional command to execute, or `nil`.
    mutating func update(_ msg: any Message) -> Command?

    /// Renders the current model state as a ``ViewOutput``.
    ///
    /// The view output is written to the terminal after every call to
    /// ``update(_:)``. Return a string literal for simple text output, or
    /// construct a ``ViewOutput`` explicitly to control terminal features
    /// like the alternate screen buffer or window title per-frame.
    ///
    /// - Returns: A ``ViewOutput`` describing the UI and desired terminal state.
    func view() -> ViewOutput
}
