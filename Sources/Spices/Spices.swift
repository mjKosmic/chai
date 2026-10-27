/// Spices — TUI components for the Chai framework.
///
/// Spices provides a collection of reusable, composable terminal UI
/// components that follow the ELM architecture. Each component is a
/// value-type struct exposing `initialize()`, `update(_:)`, and a `body`
/// property (a ``Chai/Model``), or is a reusable ``Chai/View`` designed to be
/// embedded in a parent model.
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
/// | ``Menu`` | Single-selection menu with confirm/cancel |
/// | ``Help`` | Keybinding help renderer |
/// | ``Timer`` | Countdown timer |
/// | ``Stopwatch`` | Elapsed-time counter |
/// | ``FilePicker`` | Filesystem browser |
/// | ``Cursor`` | Blinking text cursor |
///
/// ## Styling & Layout
///
/// `Style`, `Color`, and `ColorProfile` live in **Latte**, which Spices
/// depends on. To use these types in your own code, add the `Latte` product
/// as a dependency and import it explicitly:
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
/// ## Terminal Color Safety
///
/// Spices automatically downsample colors to match the connected terminal's
/// capabilities. Detect the profile once and pass it to every render call:
///
/// ```swift
/// let profile = ColorProfile.detect()
/// let style = Style().foreground(.trueColor(r: 255, g: 100, b: 50)).bold()
///
/// // Colors automatically downsampled to fit the terminal
/// let output = style.render("Warning!", profile: profile)
///
/// // Or strip all styling for piped / file output
/// let plain = style.render("Warning!", profile: .noColor)  // returns "Warning!"
/// ```
///
/// ## Usage
///
/// Embed Spices components as properties of your ``Chai/Model`` struct
/// and delegate `update` / `body` calls:
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
///     var body: ViewOutput {
///         ViewOutput(spinner.body.content + " Loading…")
///     }
/// }
/// ```
