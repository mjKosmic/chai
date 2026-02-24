/// Chai — A Swift-native terminal UI framework inspired by Bubble Tea.
///
/// Chai is built around the Elm Architecture (Model-Update-View):
///
/// - **Model** — your application state, conforming to ``Model``.
/// - **Update** — a `mutating func update(_ msg:) -> Command?` method that
///   handles incoming ``Message`` values and optionally returns a ``Command``
///   to trigger async work.
/// - **View** — a `func view() -> String` method that renders the current
///   state as a plain string (ANSI escape codes are supported).
///
/// ## Quick Start
///
/// ```swift
/// import Chai
///
/// struct Counter: Model {
///     var count = 0
///
///     func initialize() -> Command? { nil }
///
///     mutating func update(_ msg: any Message) -> Command? {
///         guard let key = msg as? KeyMsg else { return nil }
///         switch key.type {
///         case .ctrl("c"): return .quit
///         case .up:        count += 1
///         case .down:      count -= 1
///         default:         break
///         }
///         return nil
///     }
///
///     func view() -> String {
///         "Count: \(count)\n\nPress ↑/↓ to change, Ctrl+C to quit.\n"
///     }
/// }
///
/// @main struct App {
///     static func main() async throws {
///         try await Program(Counter()).run()
///     }
/// }
/// ```
///
/// ## Key Types
///
/// | Type | Description |
/// |------|-------------|
/// | ``Model`` | Protocol your app model conforms to |
/// | ``Message`` | Protocol for all event types |
/// | ``Command`` | Async side-effects returned from `update` |
/// | ``Program`` | The runtime that drives the event loop |
/// | ``KeyMsg`` | Keyboard event message |
/// | ``WindowSizeMsg`` | Terminal resize event |
/// | ``QuitMsg`` | Signals program exit |
/// | ``ProgramOption`` | Configuration options for ``Program`` |

// All public types are defined in their respective files.
// This file serves as the module documentation entry point.
// No additional re-exports are needed — Swift makes all `public` symbols
// in the module available automatically.
