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
/// | ``Help`` | Keybinding help renderer |
/// | ``Timer`` | Countdown timer |
/// | ``Stopwatch`` | Elapsed-time counter |
/// | ``FilePicker`` | Filesystem browser |
/// | ``Cursor`` | Blinking text cursor |
///
/// ## Foundation
///
/// | Module | Description |
/// |--------|-------------|
/// | ``Style`` | ANSI color and text attribute styling |
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
