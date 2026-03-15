import Chai

// MARK: - Echo Mode

/// Controls how typed characters are displayed.
public enum EchoMode: Sendable {
    /// Characters are displayed as typed.
    case normal
    /// Characters are replaced with the echo character (for passwords).
    case password
    /// Characters are not displayed at all.
    case none
}

// MARK: - TextInput KeyMap

/// Keybindings for the text input component.
public struct TextInputKeyMap: Sendable {
    public var characterForward: KeyBinding
    public var characterBackward: KeyBinding
    public var wordForward: KeyBinding
    public var wordBackward: KeyBinding
    public var deleteWordBackward: KeyBinding
    public var deleteWordForward: KeyBinding
    public var deleteAfterCursor: KeyBinding
    public var deleteBeforeCursor: KeyBinding
    public var deleteCharacterBackward: KeyBinding
    public var deleteCharacterForward: KeyBinding
    public var lineStart: KeyBinding
    public var lineEnd: KeyBinding
    public var acceptSuggestion: KeyBinding
    public var nextSuggestion: KeyBinding
    public var prevSuggestion: KeyBinding

    /// Creates a text input key map with default bindings.
    public init() {
        characterForward = KeyBinding(
            .type(.right), .type(.ctrl("f")),
            help: KeyHelp("→", "forward")
        )
        characterBackward = KeyBinding(
            .type(.left), .type(.ctrl("b")),
            help: KeyHelp("←", "backward")
        )
        wordForward = KeyBinding(
            .type(.ctrlRight), .runeWithAlt("f"),
            help: KeyHelp("ctrl+→", "word forward")
        )
        wordBackward = KeyBinding(
            .type(.ctrlLeft), .runeWithAlt("b"),
            help: KeyHelp("ctrl+←", "word backward")
        )
        deleteWordBackward = KeyBinding(
            .type(.ctrl("w")),
            help: KeyHelp("ctrl+w", "delete word")
        )
        deleteWordForward = KeyBinding(
            .runeWithAlt("d"),
            help: KeyHelp("alt+d", "delete word →")
        )
        deleteAfterCursor = KeyBinding(
            .type(.ctrl("k")),
            help: KeyHelp("ctrl+k", "delete to end")
        )
        deleteBeforeCursor = KeyBinding(
            .type(.ctrl("u")),
            help: KeyHelp("ctrl+u", "delete to start")
        )
        deleteCharacterBackward = KeyBinding(
            .type(.backspace),
            help: KeyHelp("backspace", "delete")
        )
        deleteCharacterForward = KeyBinding(
            .type(.delete),
            help: KeyHelp("del", "delete →")
        )
        lineStart = KeyBinding(
            .type(.home), .type(.ctrl("a")),
            help: KeyHelp("home", "start of line")
        )
        lineEnd = KeyBinding(
            .type(.end), .type(.ctrl("e")),
            help: KeyHelp("end", "end of line")
        )
        acceptSuggestion = KeyBinding(
            .type(.tab),
            help: KeyHelp("tab", "accept suggestion")
        )
        nextSuggestion = KeyBinding(
            .type(.ctrl("n")),
            help: KeyHelp("ctrl+n", "next suggestion"),
            isEnabled: false
        )
        prevSuggestion = KeyBinding(
            .type(.ctrl("p")),
            help: KeyHelp("ctrl+p", "prev suggestion"),
            isEnabled: false
        )
    }
}

// MARK: - TextInput

/// A single-line text input field.
///
/// Supports cursor movement, word navigation, deletion operations,
/// placeholder text, echo modes (for passwords), character limits,
/// validation, and autocompletion suggestions.
///
/// ```swift
/// var input = TextInput(placeholder: "Enter your name")
/// input.focus()
///
/// // In update():
/// input.update(msg)
///
/// // In view():
/// input.view()
///
/// // Access the value:
/// let name = input.value
/// ```
public struct TextInput: Sendable {
    /// The prompt displayed before the input text.
    public var prompt: String

    /// Placeholder text shown when the input is empty.
    public var placeholder: String

    /// How typed characters are displayed.
    public var echoMode: EchoMode

    /// The character used to mask input in password mode.
    public var echoCharacter: Character

    /// The text cursor.
    public var cursor: Cursor

    /// Maximum number of characters allowed. `nil` for unlimited.
    public var charLimit: Int?

    /// The display width of the input field.
    public var width: Int

    /// Keybindings for the text input.
    public var keyMap: TextInputKeyMap

    /// Whether to show autocompletion suggestions.
    public var showSuggestions: Bool

    /// Style for the prompt text.
    public var promptStyle: Style

    /// Style for the input text.
    public var textStyle: Style

    /// Style for placeholder text.
    public var placeholderStyle: Style

    /// Style for the suggestion ghost text.
    public var completionStyle: Style

    /// Validation function. Returns an error message if invalid, nil if valid.
    public var validate: (@Sendable (String) -> String?)?

    /// The current validation error, if any.
    public private(set) var validationError: String?

    // MARK: Private state

    private var _value: [Character]
    private var _position: Int
    private var _offset: Int  // horizontal scroll offset
    private var _focused: Bool
    private var _suggestions: [String]
    private var _matchedSuggestions: [String]
    private var _currentSuggestionIndex: Int

    // MARK: - Initializer

    /// Creates a new text input.
    ///
    /// - Parameters:
    ///   - prompt: The prompt prefix. Defaults to `"> "`.
    ///   - placeholder: Placeholder text. Defaults to empty.
    ///   - width: Display width. Defaults to 40.
    public init(
        prompt: String = "> ",
        placeholder: String = "",
        width: Int = 40
    ) {
        self.prompt = prompt
        self.placeholder = placeholder
        self.echoMode = .normal
        self.echoCharacter = "*"
        self.cursor = Cursor()
        self.charLimit = nil
        self.width = width
        self.keyMap = TextInputKeyMap()
        self.showSuggestions = false
        self.promptStyle = Style()
        self.textStyle = Style()
        self.placeholderStyle = Style(isDim: true)
        self.completionStyle = Style(isDim: true)
        self.validate = nil
        self.validationError = nil
        self._value = []
        self._position = 0
        self._offset = 0
        self._focused = false
        self._suggestions = []
        self._matchedSuggestions = []
        self._currentSuggestionIndex = 0
    }

    // MARK: - ELM interface

    /// Returns a command to start cursor blinking if focused.
    public func initialize() -> Command? {
        cursor.initialize()
    }

    /// Handles key input and cursor blink messages.
    public mutating func update(_ msg: any Message) -> Command? {
        // Delegate to cursor for blink handling
        if let cursorCmd = cursor.update(msg) {
            return cursorCmd
        }

        guard _focused else { return nil }
        guard let key = msg as? KeyMsg else { return nil }

        // Navigation
        if keyMap.characterForward.matches(key) {
            characterForward()
        } else if keyMap.characterBackward.matches(key) {
            characterBackward()
        } else if keyMap.wordForward.matches(key) {
            wordForward()
        } else if keyMap.wordBackward.matches(key) {
            wordBackward()
        }
        // Deletion
        else if keyMap.deleteCharacterBackward.matches(key) {
            deleteCharacterBackward()
        } else if keyMap.deleteCharacterForward.matches(key) {
            deleteCharacterForward()
        } else if keyMap.deleteWordBackward.matches(key) {
            deleteWordBackward()
        } else if keyMap.deleteWordForward.matches(key) {
            deleteWordForward()
        } else if keyMap.deleteAfterCursor.matches(key) {
            deleteAfterCursor()
        } else if keyMap.deleteBeforeCursor.matches(key) {
            deleteBeforeCursor()
        }
        // Line start/end
        else if keyMap.lineStart.matches(key) {
            _position = 0
        } else if keyMap.lineEnd.matches(key) {
            _position = _value.count
        }
        // Suggestions
        else if keyMap.acceptSuggestion.matches(key) && showSuggestions {
            acceptSuggestion()
        } else if keyMap.nextSuggestion.matches(key) && showSuggestions {
            nextSuggestion()
        } else if keyMap.prevSuggestion.matches(key) && showSuggestions {
            prevSuggestion()
        }
        // Character input
        else if key.type.isRunes {
            for char in key.runes {
                insertCharacter(char)
            }
        }

        updateOffset()
        return nil
    }

    /// Renders the text input field.
    public func view() -> ViewOutput {
        var output = promptStyle.render(prompt)

        if _value.isEmpty && !_focused {
            // Show placeholder
            output += placeholderStyle.render(placeholder)
            return ViewOutput(output)
        }

        // Build the displayed text
        let displayChars: [Character]
        switch echoMode {
        case .normal:
            displayChars = _value
        case .password:
            displayChars = Array(repeating: echoCharacter, count: _value.count)
        case .none:
            displayChars = []
        }

        // Calculate visible window
        let availableWidth = max(1, width - prompt.count)
        let visibleStart = _offset
        let visibleEnd = min(visibleStart + availableWidth, displayChars.count)

        // Render text before cursor
        let cursorPosInView = _position - _offset
        if !displayChars.isEmpty && echoMode != .none {
            let preStart = visibleStart
            let preEnd = min(visibleStart + cursorPosInView, displayChars.count)

            if preEnd > preStart {
                let preCursor = String(displayChars[preStart..<preEnd])
                output += textStyle.render(preCursor)
            }

            // Render cursor
            if _focused {
                let cursorChar: String
                if _position < displayChars.count {
                    cursorChar = String(displayChars[_position])
                } else {
                    cursorChar = " "
                }
                var cursorCopy = cursor
                cursorCopy.setChar(cursorChar)
                output += cursorCopy.view().content
            }

            // Render text after cursor
            let postStart = min(_position + 1, displayChars.count)
            let postEnd = min(visibleEnd, displayChars.count)
            if postEnd > postStart {
                let postCursor = String(displayChars[postStart..<min(postEnd, displayChars.count)])
                output += textStyle.render(postCursor)
            }
        } else if _focused {
            // Empty value, show cursor
            output += cursor.view().content
        }

        // Suggestion ghost text
        if showSuggestions && _focused {
            if let suggestion = currentSuggestion {
                let remaining = suggestion.dropFirst(_value.count)
                if !remaining.isEmpty {
                    output += completionStyle.render(String(remaining))
                }
            }
        }

        return ViewOutput(output)
    }

    // MARK: - Public API

    /// The current text value.
    public var value: String {
        String(_value)
    }

    /// Sets the text value and moves the cursor to the end.
    public mutating func setValue(_ text: String) {
        _value = Array(text)
        if let limit = charLimit {
            _value = Array(_value.prefix(limit))
        }
        _position = _value.count
        updateOffset()
        runValidation()
        updateSuggestionMatches()
    }

    /// Whether the input is currently focused.
    public var isFocused: Bool { _focused }

    /// The current cursor position within the value.
    public var position: Int { _position }

    /// Focuses the input and starts cursor blinking.
    @discardableResult
    public mutating func focus() -> Command? {
        _focused = true
        return cursor.focus()
    }

    /// Unfocuses the input and stops cursor blinking.
    public mutating func blur() {
        _focused = false
        cursor.blur()
    }

    /// Sets the cursor position.
    public mutating func setCursorPosition(_ pos: Int) {
        _position = max(0, min(pos, _value.count))
        updateOffset()
    }

    // MARK: - Suggestions

    /// Sets the available suggestions.
    public mutating func setSuggestions(_ suggestions: [String]) {
        _suggestions = suggestions
        updateSuggestionMatches()
    }

    /// The currently matched suggestion, if any.
    public var currentSuggestion: String? {
        guard !_matchedSuggestions.isEmpty else { return nil }
        return _matchedSuggestions[_currentSuggestionIndex]
    }

    // MARK: - Character operations

    private mutating func insertCharacter(_ char: Character) {
        if let limit = charLimit, _value.count >= limit {
            return
        }
        _value.insert(char, at: _position)
        _position += 1
        runValidation()
        updateSuggestionMatches()
    }

    private mutating func deleteCharacterBackward() {
        guard _position > 0 else { return }
        _position -= 1
        _value.remove(at: _position)
        runValidation()
        updateSuggestionMatches()
    }

    private mutating func deleteCharacterForward() {
        guard _position < _value.count else { return }
        _value.remove(at: _position)
        runValidation()
        updateSuggestionMatches()
    }

    // MARK: - Word operations

    private mutating func wordForward() {
        // Skip non-word characters, then skip word characters
        while _position < _value.count && !_value[_position].isLetter {
            _position += 1
        }
        while _position < _value.count && _value[_position].isLetter {
            _position += 1
        }
    }

    private mutating func wordBackward() {
        // Skip non-word characters backward, then skip word characters
        while _position > 0 && !_value[_position - 1].isLetter {
            _position -= 1
        }
        while _position > 0 && _value[_position - 1].isLetter {
            _position -= 1
        }
    }

    private mutating func deleteWordBackward() {
        let oldPos = _position
        wordBackward()
        _value.removeSubrange(_position..<oldPos)
        runValidation()
        updateSuggestionMatches()
    }

    private mutating func deleteWordForward() {
        let oldPos = _position
        wordForward()
        _value.removeSubrange(oldPos..<_position)
        _position = oldPos
        runValidation()
        updateSuggestionMatches()
    }

    // MARK: - Line operations

    private mutating func deleteAfterCursor() {
        _value.removeSubrange(_position..<_value.count)
        runValidation()
        updateSuggestionMatches()
    }

    private mutating func deleteBeforeCursor() {
        _value.removeSubrange(0..<_position)
        _position = 0
        runValidation()
        updateSuggestionMatches()
    }

    // MARK: - Navigation

    private mutating func characterForward() {
        if _position < _value.count {
            _position += 1
        }
    }

    private mutating func characterBackward() {
        if _position > 0 {
            _position -= 1
        }
    }

    // MARK: - Suggestions

    private mutating func acceptSuggestion() {
        guard let suggestion = currentSuggestion else { return }
        _value = Array(suggestion)
        _position = _value.count
        _matchedSuggestions = []
        _currentSuggestionIndex = 0
        runValidation()
    }

    private mutating func nextSuggestion() {
        guard !_matchedSuggestions.isEmpty else { return }
        _currentSuggestionIndex = (_currentSuggestionIndex + 1) % _matchedSuggestions.count
    }

    private mutating func prevSuggestion() {
        guard !_matchedSuggestions.isEmpty else { return }
        _currentSuggestionIndex = (_currentSuggestionIndex - 1 + _matchedSuggestions.count) % _matchedSuggestions.count
    }

    private mutating func updateSuggestionMatches() {
        guard showSuggestions, !_suggestions.isEmpty, !_value.isEmpty else {
            _matchedSuggestions = []
            _currentSuggestionIndex = 0
            return
        }
        let prefix = String(_value)
        _matchedSuggestions = _suggestions.filter {
            $0.hasPrefix(prefix) && $0 != prefix
        }
        _currentSuggestionIndex = 0
    }

    // MARK: - Scroll offset

    private mutating func updateOffset() {
        let availableWidth = max(1, width - prompt.count)

        // Ensure cursor is visible
        if _position < _offset {
            _offset = _position
        } else if _position >= _offset + availableWidth {
            _offset = _position - availableWidth + 1
        }

        // Don't scroll past the end of input
        _offset = max(0, _offset)
    }

    // MARK: - Validation

    private mutating func runValidation() {
        validationError = validate?(String(_value))
    }
}
