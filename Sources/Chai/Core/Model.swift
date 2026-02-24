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
///     func view() -> String {
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

    /// Renders the current model state as a plain string.
    ///
    /// The string is written to the terminal after every call to ``update(_:)``.
    /// Use `\n` for line breaks. ANSI escape codes are supported for colour
    /// and styling.
    ///
    /// - Returns: The full UI as a string.
    func view() -> String
}
