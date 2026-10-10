/// A marker protocol for all messages in Chai.
///
/// Any `Sendable` type can be a message. The runtime delivers messages to your
/// model's `update(_:)` method. You can define your own message types by
/// conforming to this protocol:
///
/// ```swift
/// struct DataLoaded: Message {
///     let items: [String]
/// }
/// ```
///
/// Built-in messages such as ``KeyMsg`` and ``WindowSizeMsg`` are delivered
/// automatically by the runtime.
public protocol Message: Sendable {}

// MARK: - Built-in Messages

/// A keyboard event delivered when the user presses a key.
///
/// Use a type-switch in your model's `update(_:)` to handle key presses:
///
/// ```swift
/// mutating func update(_ msg: any Message) -> Command? {
///     guard let key = msg as? KeyMsg else { return nil }
///     switch key.type {
///     case .ctrl("c"):
///         return .quit
///     case .up:
///         cursor = max(0, cursor - 1)
///     default:
///         break
///     }
///     return nil
/// }
/// ```
public struct KeyMsg: Message {
    /// The type of key that was pressed.
    public let type: KeyType

    /// The Unicode characters associated with this key press.
    ///
    /// This is non-empty when `type == .runes`. For most key presses it
    /// contains exactly one character, but certain IMEs can produce multiple
    /// runes at once.
    public let runes: [Character]

    /// Whether the Alt (Option) modifier was held.
    public let alt: Bool

    public init(type: KeyType, runes: [Character] = [], alt: Bool = false) {
        self.type = type
        self.runes = runes
        self.alt = alt
    }

    /// A human-readable string representation of the key, suitable for
    /// display and comparison (e.g. `"ctrl+c"`, `"enter"`, `"up"`, `"a"`).
    public var description: String {
        var parts: [String] = []
        if alt { parts.append("alt") }
        switch type {
        case .runes:
            parts.append(String(runes))
        case .ctrl(let c):
            parts.append("ctrl+\(c)")
        default:
            parts.append(type.description)
        }
        return parts.joined(separator: "+")
    }
}

/// The category of key that was pressed.
public enum KeyType: Sendable, Equatable {
    // MARK: Printable characters
    /// One or more printable Unicode characters. Inspect `KeyMsg.runes` for the value.
    case runes

    // MARK: Whitespace / editing
    case enter
    case tab
    /// A Shift+Tab key press (BackTab). Sent by terminals as `ESC [ Z`.
    ///
    /// Distinct from ``tab`` so that applications can implement forward/backward
    /// focus traversal without an ambiguous `.tab` case.
    case shiftTab
    case backspace
    case delete
    case escape
    case space

    // MARK: Navigation
    case up
    case down
    case left
    case right
    case home
    case end
    case pageUp
    case pageDown
    case insert

    // MARK: Shift + navigation
    case shiftUp
    case shiftDown
    case shiftLeft
    case shiftRight
    case shiftHome
    case shiftEnd

    // MARK: Ctrl + navigation
    case ctrlUp
    case ctrlDown
    case ctrlLeft
    case ctrlRight
    case ctrlHome
    case ctrlEnd

    // MARK: Ctrl + Shift + navigation
    case ctrlShiftUp
    case ctrlShiftDown
    case ctrlShiftLeft
    case ctrlShiftRight
    case ctrlShiftHome
    case ctrlShiftEnd

    // MARK: Control characters
    /// A Ctrl+<character> combination, e.g. `.ctrl("c")` for Ctrl+C.
    case ctrl(Character)

    // MARK: Function keys
    /// A function key F1–F20. E.g. `.f(1)` for F1.
    case f(Int)

    // MARK: Unknown
    /// An unrecognised key or escape sequence.
    case unknown

    /// A short human-readable name for this key type.
    public var description: String {
        switch self {
        case .runes:         return "runes"
        case .enter:         return "enter"
        case .tab:           return "tab"
        case .shiftTab:      return "shift+tab"
        case .backspace:     return "backspace"
        case .delete:        return "delete"
        case .escape:        return "esc"
        case .space:         return "space"
        case .up:            return "up"
        case .down:          return "down"
        case .left:          return "left"
        case .right:         return "right"
        case .home:          return "home"
        case .end:           return "end"
        case .pageUp:        return "pgup"
        case .pageDown:      return "pgdown"
        case .insert:        return "insert"
        case .shiftUp:       return "shift+up"
        case .shiftDown:     return "shift+down"
        case .shiftLeft:     return "shift+left"
        case .shiftRight:    return "shift+right"
        case .shiftHome:     return "shift+home"
        case .shiftEnd:      return "shift+end"
        case .ctrlUp:        return "ctrl+up"
        case .ctrlDown:      return "ctrl+down"
        case .ctrlLeft:      return "ctrl+left"
        case .ctrlRight:     return "ctrl+right"
        case .ctrlHome:      return "ctrl+home"
        case .ctrlEnd:       return "ctrl+end"
        case .ctrlShiftUp:   return "ctrl+shift+up"
        case .ctrlShiftDown: return "ctrl+shift+down"
        case .ctrlShiftLeft: return "ctrl+shift+left"
        case .ctrlShiftRight:return "ctrl+shift+right"
        case .ctrlShiftHome: return "ctrl+shift+home"
        case .ctrlShiftEnd:  return "ctrl+shift+end"
        case .ctrl(let c):   return "ctrl+\(c)"
        case .f(let n):      return "f\(n)"
        case .unknown:       return "unknown"
        }
    }
}

// MARK: - Window Size

/// Delivered when the terminal window is resized, and once at program startup.
public struct WindowSizeMsg: Message {
    /// Terminal width in columns.
    public let width: Int
    /// Terminal height in rows.
    public let height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

// MARK: - Lifecycle

/// Signals the program to exit gracefully.
///
/// Return `.quit` from your model's `update(_:)` or use `Command.quit` to
/// trigger a clean shutdown.
public struct QuitMsg: Message {
    public init() {}
}

// MARK: - Internal message marker

/// A marker protocol for messages that are handled by the runtime and
/// should never be delivered to the user's ``Model/update(_:)``.
///
/// The event loop intercepts these messages after ``ProgramRunner/handleRendererMessage``
/// and skips the `model.update` → ``Model/body`` read → render cycle for them.
protocol InternalMessage: Message {}

// MARK: - Internal batch/sequence messages

/// Internal message wrapping a set of commands to run concurrently.
struct BatchMsg: InternalMessage {
    let commands: [Command]
}

/// Internal message wrapping a set of commands to run sequentially.
struct SequenceMsg: InternalMessage {
    let commands: [Command]
}

/// Internal message requesting a full repaint.
struct RepaintMsg: InternalMessage {}

/// Internal message carrying a line to print above the live view.
struct PrintLineMsg: InternalMessage {
    let body: String
}
