import Chai
import Latte
// MARK: - Spinner Type

/// A spinner animation defined by its frames and tick interval.
///
/// Use one of the built-in spinners (e.g. ``dot``, ``line``, ``moon``)
/// or create a custom one:
///
/// ```swift
/// let custom = SpinnerType(frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
///                           interval: .milliseconds(80))
/// ```
public struct SpinnerType: Sendable {
    /// The sequence of frames to display.
    public var frames: [String]

    /// The time between frame advances.
    public var interval: Duration

    /// Creates a custom spinner type.
    public init(frames: [String], interval: Duration) {
        self.frames = frames
        self.interval = interval
    }

    // MARK: - Built-in spinners

    /// A simple line spinner: `|`, `/`, `-`, `\`.
    public static let line = SpinnerType(
        frames: ["|", "/", "-", "\\"],
        interval: .milliseconds(130)
    )

    /// A Braille dot spinner.
    public static let dot = SpinnerType(
        frames: ["⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷"],
        interval: .milliseconds(80)
    )

    /// A small dot spinner.
    public static let miniDot = SpinnerType(
        frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"],
        interval: .milliseconds(80)
    )

    /// A jumping dot spinner.
    public static let jump = SpinnerType(
        frames: ["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"],
        interval: .milliseconds(80)
    )

    /// A pulsing dot.
    public static let pulse = SpinnerType(
        frames: ["█", "▓", "▒", "░"],
        interval: .milliseconds(130)
    )

    /// Trailing dots.
    public static let points = SpinnerType(
        frames: ["∙∙∙", "●∙∙", "∙●∙", "∙∙●"],
        interval: .milliseconds(130)
    )

    /// A rotating globe.
    public static let globe = SpinnerType(
        frames: ["🌍", "🌎", "🌏"],
        interval: .milliseconds(180)
    )

    /// Moon phases.
    public static let moon = SpinnerType(
        frames: ["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"],
        interval: .milliseconds(180)
    )

    /// A monkey covering its eyes, ears, and mouth.
    public static let monkey = SpinnerType(
        frames: ["🙈", "🙉", "🙊"],
        interval: .milliseconds(300)
    )

    /// A loading meter.
    public static let meter = SpinnerType(
        frames: ["▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▰▰▱", "▰▱▱", "▱▱▱"],
        interval: .milliseconds(150)
    )

    /// A hamburger menu.
    public static let hamburger = SpinnerType(
        frames: ["☱", "☲", "☴", "☲"],
        interval: .milliseconds(100)
    )

    /// Growing ellipsis.
    public static let ellipsis = SpinnerType(
        frames: ["", ".", "..", "..."],
        interval: .milliseconds(300)
    )
}

// MARK: - Internal messages

/// Internal tick message for advancing the spinner frame.
struct SpinnerTickMsg: Message {
    let id: Int
    let tag: Int
}

// MARK: - ID generation

private let _spinnerIDGenerator = IDGenerator()

// MARK: - Spinner

/// An animated loading spinner.
///
/// The spinner cycles through a set of frames at a configurable interval.
/// Use one of the built-in ``SpinnerType`` values or define your own.
///
/// ```swift
/// var spinner = Spinner(type: .dot, style: Style().foreground(.ansi(.cyan)))
///
/// // In initialize():
/// spinner.initialize()  // starts the animation
///
/// // In update():
/// spinner.update(msg)   // advances frames on tick
///
/// // In view():
/// spinner.view() + " Loading..."
/// ```
public struct Spinner: View {
    /// The spinner type (frames and interval).
    public var type: SpinnerType {
        didSet { _tag += 1 }
    }

    /// Style applied to the rendered spinner frame.
    public var style: Style

    // MARK: Private state

    private let _id: Int
    private var _tag: Int
    private var _frame: Int

    // MARK: - Initializer

    /// Creates a new spinner.
    ///
    /// - Parameters:
    ///   - type: The spinner animation type. Defaults to ``SpinnerType/line``.
    ///   - style: The style for the spinner text. Defaults to no style.
    public init(type: SpinnerType = .line, style: Style = Style()) {
        self.type = type
        self.style = style
        self._id = _spinnerIDGenerator.next()
        self._tag = 0
        self._frame = 0
    }

    // MARK: - ELM interface

    /// Returns a command that starts the spinner animation.
    public func initialize() -> Command? {
        tickCommand()
    }

    /// Advances the spinner frame on tick messages.
    ///
    /// Returns a command for the next tick to continue the animation.
    /// All other messages are ignored.
    public mutating func update(_ msg: any Message) -> Command? {
        guard let tick = msg as? SpinnerTickMsg else { return nil }
        guard tick.id == _id, tick.tag == _tag else { return nil }

        let frameCount = type.frames.count
        guard frameCount > 0 else { return nil }

        _frame = (_frame + 1) % frameCount
        return tickCommand()
    }

    /// Renders the current spinner frame with the configured style.
    public var body: ViewOutput {
        let frameCount = type.frames.count
        guard frameCount > 0 else { return "" }
        return ViewOutput(style.styledText(type.frames[_frame]))
    }

    // MARK: - Public API

    /// Resets the spinner to its first frame and generates a new tick cycle.
    public mutating func reset() {
        _frame = 0
        _tag += 1
    }

    /// Returns a command to start or restart the tick cycle.
    ///
    /// Useful when re-embedding a spinner after a pause.
    public func tick() -> Command? {
        tickCommand()
    }

    // MARK: - Private

    private func tickCommand() -> Command? {
        let id = self._id
        let tag = self._tag
        let interval = self.type.interval
        return .tick(interval) { _ in
            SpinnerTickMsg(id: id, tag: tag)
        }
    }
}
