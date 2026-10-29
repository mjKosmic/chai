/// Chai — A Swift-native terminal UI framework inspired by Bubble Tea.
///
/// Chai is built around the Elm Architecture (Model-Update-View):
///
/// - **Model** — your application state, conforming to ``Model`` (which extends ``View``).
/// - **Update** — a `mutating func update(_ msg:) -> Command?` method that
///   handles incoming ``Message`` values and optionally returns a ``Command``
///   to trigger async work.
/// - **View** — a `var body` property that renders the current state as a
///   view tree, composed declaratively with `@ViewBuilder` and laid out by
///   the layout engine.
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
///     var body: ViewOutput {
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
/// | ``View`` | Protocol for visual components |
/// | ``Model`` | Protocol your app model conforms to (extends View) |
/// | ``Message`` | Protocol for all event types |
/// | ``Command`` | Async side-effects returned from `update` |
/// | ``Program`` | The runtime that drives the event loop |
/// | ``KeyMsg`` | Keyboard event message |
/// | ``WindowSizeMsg`` | Terminal resize event |
/// | ``QuitMsg`` | Signals program exit |

///
/// ## Layout & Styling
///
/// The view tree ships with the framework: ``VStack`` and ``HStack`` compose
/// children, ``Spacer`` and ``Fill`` absorb leftover space, and the modifiers
/// `.padded`, `.margined`, `.bordered`, `.frame`, `.beside`, and `.above`
/// adjust layout without leaving the tree.
///
/// ```swift
/// VStack {
///     Text("Groceries".bold())
///     HStack {
///         Text("milk")
///         Spacer()
///         Text("2")
///     }
/// }
/// .padded(1)
/// .bordered(.rounded, borderStyle: Style().foreground(.ansi(.cyan)))
/// .frame(width: 40, horizontalAlignment: .center)
/// ```
///
/// ``Style`` describes colors and text attributes as structured values for the
/// cell renderer (`Style.textAttributes`), and can also render an ANSI string
/// for output written outside the live view, such as ``Command/println(_:)``.
/// ``ColorProfile`` handles terminal capability detection and downsampling for
/// that path.
///
/// Border glyphs accept the same styling values. A shared `borderStyle`
/// applies to every edge; `topStyle`, `bottomStyle`, `leftStyle`, and
/// `rightStyle` override it per side, and corners inherit their horizontal
/// edge's style.
///
/// Tabs have no display width and are skipped by the cell renderer, so expand
/// them before they enter a view with ``expandTabs(_:tabWidth:)`` or
/// ``Swift/String/tabsExpanded(tabWidth:)``.
///
/// | Group | Types / Functions |
/// |-------|-------------------|
/// | **Containers** | ``VStack``, ``HStack``, ``FrameView`` |
/// | **Modifiers** | `.padded`, `.margined`, `.bordered`, `.frame`, `.beside`, `.above` |
/// | **Styling** | ``Style``, ``Color``, ``ANSIColor``, ``ColorProfile`` |
/// | **Borders** | ``Border`` and its presets |
/// | **Text utilities** | ``expandTabs(_:tabWidth:)`` |

// All public types are defined in their respective files.
// This file serves as the module documentation entry point.
// No additional re-exports are needed — Swift makes all `public` symbols
// in the module available automatically.
