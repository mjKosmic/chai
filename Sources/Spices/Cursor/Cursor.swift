import Chai
import Latte
// MARK: - Cursor Mode

/// The display mode of a text cursor.
public enum CursorMode: Sendable, Equatable {
    /// The cursor blinks on and off at a regular interval.
    case blink
    /// The cursor is always visible.
    case `static`
    /// The cursor is hidden.
    case hidden
}

// MARK: - Internal messages

/// Internal message that drives the cursor blink animation.
///
/// Uses `id` and `tag` to prevent stale ticks from affecting a cursor
/// that has been reconfigured or replaced.
struct CursorBlinkMsg: Message {
    let id: Int
    let tag: Int
}

// MARK: - ID generation

private let _cursorIDGenerator = IDGenerator()

// MARK: - Cursor

/// A text cursor with blink, static, and hidden display modes.
///
/// `Cursor` is a sub-component used internally by ``TextInput`` and
/// ``TextArea``. It manages blink animation via Chai's tick command
/// system.
///
/// ```swift
/// var cursor = Cursor()
/// cursor.focus()  // returns a Command to start blinking
/// cursor.view()   // renders the cursor character with appropriate style
/// ```
public struct Cursor: Sendable {
    /// The character displayed at the cursor position.
    public var char: String

    /// The style applied when the cursor is visible (typically reverse video).
    public var style: Style

    /// The style applied to the character when the cursor is hidden/blinked off.
    public var textStyle: Style

    /// The interval between blink state toggles.
    public var blinkSpeed: Duration

    /// The cursor display mode.
    public var mode: CursorMode {
        didSet {
            // Bump the tag to invalidate any already-scheduled blink ticks
            // from the previous mode, preventing stale ticks from toggling
            // visibility after a mode change.
            _tag += 1
            // Reset blink visibility when mode changes
            switch mode {
            case .blink:
                _visible = true
            case .static:
                _visible = true
            case .hidden:
                _visible = false
            }
        }
    }

    // MARK: Private state

    private let _id: Int
    private var _tag: Int
    private var _focused: Bool
    private var _visible: Bool

    // MARK: - Initializer

    /// Creates a new cursor.
    ///
    /// - Parameters:
    ///   - char: The character to display. Defaults to a space.
    ///   - mode: The display mode. Defaults to `.blink`.
    ///   - blinkSpeed: Duration between blink toggles. Defaults to 530ms.
    ///   - style: Style when cursor is visible. Defaults to reverse video.
    ///   - textStyle: Style when cursor is hidden. Defaults to no style.
    public init(
        char: String = " ",
        mode: CursorMode = .blink,
        blinkSpeed: Duration = .milliseconds(530),
        style: Style = Style().reverse(),
        textStyle: Style = Style()
    ) {
        self.char = char
        self.mode = mode
        self.blinkSpeed = blinkSpeed
        self.style = style
        self.textStyle = textStyle
        self._id = _cursorIDGenerator.next()
        self._tag = 0
        self._focused = false
        self._visible = mode != .hidden
    }

    // MARK: - ELM interface

    /// Returns a command to start the blink animation if the cursor is
    /// focused and in blink mode.
    public func initialize() -> Command? {
        blinkCommand()
    }

    /// Handles blink tick messages.
    ///
    /// All other messages are ignored. Returns a command for the next
    /// blink tick if the cursor should continue blinking.
    public mutating func update(_ msg: any Message) -> Command? {
        guard let blink = msg as? CursorBlinkMsg else { return nil }

        // Reject stale ticks (also rejects ticks from before a mode change,
        // because mode.didSet bumps _tag).
        guard blink.id == _id, blink.tag == _tag else { return nil }

        // Only toggle visibility when actually blinking and focused; a stale
        // tick that slips past the tag check (e.g. same-generation mode change)
        // should not leave the cursor in an unexpected hidden state.
        guard mode == .blink, _focused else { return nil }

        // Toggle visibility
        _visible.toggle()
        return blinkCommand()
    }

    /// Renders the cursor character with the appropriate style.
    ///
    /// - When visible: renders with ``style`` (typically reverse video).
    /// - When hidden or blinked off: renders with ``textStyle``.
    public func view() -> ViewOutput {
        if _visible && mode != .hidden {
            return ViewOutput(style.render(char))
        } else {
            return ViewOutput(textStyle.render(char))
        }
    }

    // MARK: - Focus management

    /// Whether the cursor is currently focused.
    public var isFocused: Bool { _focused }

    /// Focuses the cursor and returns a command to start blinking.
    @discardableResult
    public mutating func focus() -> Command? {
        _focused = true
        _visible = true
        _tag += 1
        return blinkCommand()
    }

    /// Blurs (unfocuses) the cursor and stops blinking.
    public mutating func blur() {
        _focused = false
        _visible = true
        _tag += 1
    }

    /// Updates the character displayed at the cursor position.
    public mutating func setChar(_ char: String) {
        self.char = char
    }

    // MARK: - Private

    /// Returns a tick command for the next blink, or nil if blinking is
    /// not appropriate.
    private func blinkCommand() -> Command? {
        guard _focused, mode == .blink else { return nil }
        let id = self._id
        let tag = self._tag
        let speed = self.blinkSpeed
        return .tick(speed) { _ in
            CursorBlinkMsg(id: id, tag: tag)
        }
    }
}
