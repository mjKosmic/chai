import Chai

/// A configurable keybinding that maps one or more key patterns to an action.
///
/// `KeyBinding` pairs a set of key patterns with human-readable help text,
/// and can be enabled or disabled at runtime. Components expose their
/// keybindings via `KeyMap` structs whose fields are `KeyBinding` values.
///
/// ```swift
/// let quit = KeyBinding(
///     .rune("q"), .type(.ctrl("c")),
///     help: KeyHelp("q/ctrl+c", "quit")
/// )
///
/// // In update:
/// if quit.matches(keyMsg) {
///     return .quit
/// }
/// ```
public struct KeyBinding: Sendable {
    /// The key patterns this binding responds to.
    public var keys: [KeyPattern]

    /// Human-readable help text describing this binding.
    public var help: KeyHelp

    /// Whether this binding is active. Disabled bindings never match.
    public var isEnabled: Bool

    /// Creates a keybinding with the given patterns and help text.
    ///
    /// - Parameters:
    ///   - keys: One or more key patterns to match.
    ///   - help: Descriptive text shown in help views.
    ///   - isEnabled: Whether the binding starts enabled. Defaults to `true`.
    public init(
        _ keys: KeyPattern...,
        help: KeyHelp = .empty,
        isEnabled: Bool = true
    ) {
        self.keys = keys
        self.help = help
        self.isEnabled = isEnabled
    }

    /// Creates a keybinding from an array of patterns.
    public init(
        keys: [KeyPattern],
        help: KeyHelp = .empty,
        isEnabled: Bool = true
    ) {
        self.keys = keys
        self.help = help
        self.isEnabled = isEnabled
    }

    /// Returns `true` if the given key message matches any of this binding's
    /// patterns and the binding is enabled.
    ///
    /// - Parameter msg: A key message from Chai.
    /// - Returns: `true` if the key matches this binding.
    public func matches(_ msg: KeyMsg) -> Bool {
        guard isEnabled else { return false }
        return keys.contains { $0.matches(msg) }
    }

    /// Disables this binding so it no longer matches any key.
    public mutating func unbind() {
        keys = []
        isEnabled = false
    }
}

// MARK: - KeyPattern

/// A single key pattern that can be matched against a ``Chai/KeyMsg``.
///
/// Patterns cover the three common ways to identify a key press:
///
/// - By ``Chai/KeyType`` (e.g. `.type(.enter)`, `.type(.up)`)
/// - By printable character (e.g. `.rune("q")`)
/// - By printable character with the Alt modifier held (e.g. `.runeWithAlt("x")`)
public enum KeyPattern: Sendable {
    /// Matches a specific ``Chai/KeyType``.
    ///
    /// Use this for special keys, control combinations, and function keys:
    /// ```swift
    /// .type(.enter)
    /// .type(.ctrl("c"))
    /// .type(.f(1))
    /// ```
    case type(KeyType)

    /// Matches a printable character (without Alt).
    ///
    /// ```swift
    /// .rune("q")  // matches pressing the 'q' key
    /// .rune("j")  // matches pressing the 'j' key
    /// ```
    case rune(Character)

    /// Matches a printable character with the Alt modifier held.
    ///
    /// ```swift
    /// .runeWithAlt("x")  // matches Alt+X
    /// ```
    case runeWithAlt(Character)

    /// Returns `true` if the given ``Chai/KeyMsg`` matches this pattern.
    public func matches(_ msg: KeyMsg) -> Bool {
        switch self {
        case .type(let keyType):
            return msg.type.matches(keyType) && !msg.alt
        case .rune(let char):
            return msg.type.isRunes
                && msg.runes.count == 1
                && msg.runes.first == char
                && !msg.alt
        case .runeWithAlt(let char):
            return msg.type.isRunes
                && msg.runes.count == 1
                && msg.runes.first == char
                && msg.alt
        }
    }
}

// MARK: - KeyHelp

/// Human-readable help text for a keybinding.
///
/// Used by the ``Help`` component to render keybinding documentation.
public struct KeyHelp: Sendable, Equatable {
    /// The key description shown to the user (e.g. `"↑/k"`, `"ctrl+c"`).
    public var key: String

    /// A brief description of the action (e.g. `"move up"`, `"quit"`).
    public var description: String

    /// Creates a key help entry.
    public init(_ key: String, _ description: String) {
        self.key = key
        self.description = description
    }

    /// An empty help entry (no key text, no description).
    public static let empty = KeyHelp("", "")
}

// MARK: - KeyType matching helpers

extension KeyType {
    /// Whether this key type represents printable runes.
    var isRunes: Bool {
        if case .runes = self { return true }
        return false
    }

    /// Compares two `KeyType` values for equality.
    ///
    /// `KeyType` does not conform to `Equatable` in Chai, so this provides
    /// a pattern-match comparison for keybinding purposes.
    func matches(_ other: KeyType) -> Bool {
        switch (self, other) {
        case (.runes, .runes): return true
        case (.enter, .enter): return true
        case (.tab, .tab): return true
        case (.backspace, .backspace): return true
        case (.delete, .delete): return true
        case (.escape, .escape): return true
        case (.space, .space): return true
        case (.up, .up): return true
        case (.down, .down): return true
        case (.left, .left): return true
        case (.right, .right): return true
        case (.home, .home): return true
        case (.end, .end): return true
        case (.pageUp, .pageUp): return true
        case (.pageDown, .pageDown): return true
        case (.insert, .insert): return true
        case (.shiftUp, .shiftUp): return true
        case (.shiftDown, .shiftDown): return true
        case (.shiftLeft, .shiftLeft): return true
        case (.shiftRight, .shiftRight): return true
        case (.shiftHome, .shiftHome): return true
        case (.shiftEnd, .shiftEnd): return true
        case (.ctrlUp, .ctrlUp): return true
        case (.ctrlDown, .ctrlDown): return true
        case (.ctrlLeft, .ctrlLeft): return true
        case (.ctrlRight, .ctrlRight): return true
        case (.ctrlHome, .ctrlHome): return true
        case (.ctrlEnd, .ctrlEnd): return true
        case (.ctrlShiftUp, .ctrlShiftUp): return true
        case (.ctrlShiftDown, .ctrlShiftDown): return true
        case (.ctrlShiftLeft, .ctrlShiftLeft): return true
        case (.ctrlShiftRight, .ctrlShiftRight): return true
        case (.ctrlShiftHome, .ctrlShiftHome): return true
        case (.ctrlShiftEnd, .ctrlShiftEnd): return true
        case let (.ctrl(a), .ctrl(b)): return a == b
        case let (.f(a), .f(b)): return a == b
        case (.unknown, .unknown): return true
        default: return false
        }
    }
}

// MARK: - Convenience matching function

/// Check if a ``Chai/KeyMsg`` matches any of the given bindings.
///
/// A free function for concise matching in `update()`:
///
/// ```swift
/// if matches(keyMsg, keyMap.quit) {
///     return .quit
/// }
/// ```
///
/// - Parameters:
///   - msg: The key message to test.
///   - bindings: One or more keybindings to match against.
/// - Returns: `true` if the message matches any enabled binding.
public func matches(_ msg: KeyMsg, _ bindings: KeyBinding...) -> Bool {
    bindings.contains { $0.matches(msg) }
}
