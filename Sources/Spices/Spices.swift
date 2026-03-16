/// Spices — TUI components for the Chai framework.
///
/// Spices provides a collection of reusable, composable terminal UI
/// components that follow the ELM architecture. Each component is a
/// value-type struct with `initialize()`, `update(_:)`, and `view()`
/// methods that mirror the ``Chai/Model`` protocol.
///
/// ## Components
///
/// | Component | Description |
/// |-----------|-------------|
/// | ``Spinner`` | Animated loading indicator |
/// | ``TextInput`` | Single-line text editor |
/// | ``TextArea`` | Multi-line text editor |
/// | ``Viewport`` | Scrollable content pane |
/// | ``Progress`` | Animated progress bar |
/// | ``Paginator`` | Page navigation state and rendering |
/// | ``Table`` | Interactive data table |
/// | ``List`` | Browsable list with filtering |
/// | ``SelectableList`` | Multi-select list with configurable runes |
/// | ``Help`` | Keybinding help renderer |
/// | ``Timer`` | Countdown timer |
/// | ``Stopwatch`` | Elapsed-time counter |
/// | ``FilePicker`` | Filesystem browser |
/// | ``Cursor`` | Blinking text cursor |
///
/// ## Styling & Layout
///
/// `Style`, `Color`, and `ColorProfile` live in **Latte** and are available
/// to all Spices users through the transitive dependency. Import `Latte`
/// directly to use them:
///
/// ```swift
/// import Chai
/// import Latte
/// import Spices
///
/// let profile = ColorProfile.detect()
/// let style   = Style().foreground(.trueColor(r: 255, g: 100, b: 50)).bold()
/// let output  = style.render("Warning!", profile: profile)
/// let plain   = style.render("Warning!", profile: .noColor)  // "Warning!"
/// ```
///
/// Layout primitives (`border`, `pad`, `align`, etc.) also live in Latte and
/// accept `Style` values natively — no closure adapters needed.
///
/// ## Key Bindings
///
/// | Type | Description |
/// |------|-------------|
/// | ``KeyBinding`` | Configurable keybinding definitions |
///
/// ## Usage
///
/// Embed Spices components as properties of your ``Chai/Model`` struct
/// and delegate `update` / `view` calls:
///
/// ```swift
/// import Chai
/// import Spices
///
/// struct MyApp: Model {
///     var spinner = Spinner()
///
///     func initialize() -> Command? {
///         spinner.initialize()
///     }
///
///     mutating func update(_ msg: any Message) -> Command? {
///         spinner.update(msg)
///     }
///
///     func view() -> ViewOutput {
///         ViewOutput(spinner.view().content + " Loading…")
///     }
/// }
/// ```
