import Chai
import Latte
// MARK: - TextArea Style

/// Styles for the text area component.
public struct TextAreaStyle: Sendable {
    /// Base style applied to the entire text area.
    public var base: Style
    /// Style for the line containing the cursor.
    public var cursorLine: Style
    /// Style for line numbers on the cursor line.
    public var cursorLineNumber: Style
    /// Style for the end-of-buffer character.
    public var endOfBuffer: Style
    /// Style for line numbers.
    public var lineNumber: Style
    /// Style for placeholder text.
    public var placeholder: Style
    /// Style for the prompt.
    public var prompt: Style
    /// Style for the input text.
    public var text: Style

    /// Creates text area styles with sensible defaults.
    public init() {
        self.base = Style()
        self.cursorLine = Style()
        self.cursorLineNumber = Style()
        self.endOfBuffer = Style(isDim: true)
        self.lineNumber = Style(isDim: true)
        self.placeholder = Style(isDim: true)
        self.prompt = Style()
        self.text = Style()
    }
}

// MARK: - TextArea KeyMap

/// Keybindings for the text area component.
public struct TextAreaKeyMap: Sendable {
    public var characterForward: KeyBinding
    public var characterBackward: KeyBinding
    public var wordForward: KeyBinding
    public var wordBackward: KeyBinding
    public var lineNext: KeyBinding
    public var linePrevious: KeyBinding
    public var lineStart: KeyBinding
    public var lineEnd: KeyBinding
    public var deleteWordBackward: KeyBinding
    public var deleteWordForward: KeyBinding
    public var deleteAfterCursor: KeyBinding
    public var deleteBeforeCursor: KeyBinding
    public var deleteCharacterBackward: KeyBinding
    public var deleteCharacterForward: KeyBinding
    public var insertNewline: KeyBinding
    public var inputBegin: KeyBinding
    public var inputEnd: KeyBinding
    public var uppercaseWordForward: KeyBinding
    public var lowercaseWordForward: KeyBinding
    public var transposeCharacterBackward: KeyBinding

    /// Creates a text area key map with default bindings.
    public init() {
        characterForward = KeyBinding(.type(.right), .type(.ctrl("f")),
                                      help: KeyHelp("→", "forward"))
        characterBackward = KeyBinding(.type(.left), .type(.ctrl("b")),
                                       help: KeyHelp("←", "backward"))
        wordForward = KeyBinding(.type(.ctrlRight), .runeWithAlt("f"),
                                 help: KeyHelp("ctrl+→", "word forward"))
        wordBackward = KeyBinding(.type(.ctrlLeft), .runeWithAlt("b"),
                                  help: KeyHelp("ctrl+←", "word backward"))
        lineNext = KeyBinding(.type(.down), .type(.ctrl("n")),
                              help: KeyHelp("↓", "next line"))
        linePrevious = KeyBinding(.type(.up), .type(.ctrl("p")),
                                  help: KeyHelp("↑", "prev line"))
        lineStart = KeyBinding(.type(.home), .type(.ctrl("a")),
                               help: KeyHelp("home", "line start"))
        lineEnd = KeyBinding(.type(.end), .type(.ctrl("e")),
                             help: KeyHelp("end", "line end"))
        deleteWordBackward = KeyBinding(.type(.ctrl("w")),
                                        help: KeyHelp("ctrl+w", "delete word"))
        deleteWordForward = KeyBinding(.runeWithAlt("d"),
                                       help: KeyHelp("alt+d", "delete word →"))
        deleteAfterCursor = KeyBinding(.type(.ctrl("k")),
                                       help: KeyHelp("ctrl+k", "delete to end"))
        deleteBeforeCursor = KeyBinding(.type(.ctrl("u")),
                                        help: KeyHelp("ctrl+u", "delete to start"))
        deleteCharacterBackward = KeyBinding(.type(.backspace),
                                             help: KeyHelp("backspace", "delete"))
        deleteCharacterForward = KeyBinding(.type(.delete),
                                            help: KeyHelp("del", "delete →"))
        insertNewline = KeyBinding(.type(.enter),
                                   help: KeyHelp("enter", "new line"))
        inputBegin = KeyBinding(.type(.ctrlHome),
                                help: KeyHelp("ctrl+home", "beginning"))
        inputEnd = KeyBinding(.type(.ctrlEnd),
                              help: KeyHelp("ctrl+end", "end"))
        uppercaseWordForward = KeyBinding(.runeWithAlt("u"),
                                          help: KeyHelp("alt+u", "uppercase word"),
                                          isEnabled: false)
        lowercaseWordForward = KeyBinding(.runeWithAlt("l"),
                                          help: KeyHelp("alt+l", "lowercase word"),
                                          isEnabled: false)
        transposeCharacterBackward = KeyBinding(.type(.ctrl("t")),
                                                help: KeyHelp("ctrl+t", "transpose"),
                                                isEnabled: false)
    }
}

// MARK: - Line Info

/// Information about a specific line in the text area.
public struct LineInfo: Sendable {
    /// The line number (zero-indexed).
    public let lineNumber: Int
    /// The column position of the cursor on this line.
    public let columnOffset: Int
    /// The total number of characters on this line.
    public let width: Int
    /// The total number of characters in the text area.
    public let charCount: Int
}

// MARK: - TextArea

/// A multi-line text editor with word wrap, line numbers, and viewport scrolling.
///
/// `TextArea` supports all standard text editing operations including
/// character and word navigation, line movement, deletion operations,
/// and newline insertion. Content that exceeds the visible area is
/// scrollable via an embedded ``Viewport``.
///
/// ```swift
/// var textarea = TextArea(width: 60, height: 10)
/// textarea.placeholder = "Type something…"
/// textarea.focus()
///
/// // In update():
/// textarea.update(msg)
///
/// // In body:
/// textarea.body
///
/// // Access the value:
/// let text = textarea.value
/// ```
public struct TextArea: View {
    /// The prompt displayed at the start of each line.
    public var prompt: String

    /// Placeholder text shown when the text area is empty.
    public var placeholder: String

    /// Whether to show line numbers.
    public var showLineNumbers: Bool

    /// Character shown for lines beyond the buffer.
    public var endOfBufferCharacter: Character

    /// The text cursor.
    public var cursor: Cursor

    /// Maximum character count. `nil` for unlimited.
    public var charLimit: Int?

    /// Maximum height in lines. 0 for unlimited.
    public var maxHeight: Int

    /// Keybindings.
    public var keyMap: TextAreaKeyMap

    /// Styles when focused.
    public var focusedStyle: TextAreaStyle

    /// Styles when blurred.
    public var blurredStyle: TextAreaStyle

    // MARK: Private state

    private var _value: [[Character]]  // lines of characters
    private var _row: Int
    private var _col: Int
    private var _width: Int
    private var _height: Int
    private var _focused: Bool
    private var _viewport: Viewport

    // MARK: - Initializer

    /// Creates a new text area.
    ///
    /// - Parameters:
    ///   - width: Display width. Defaults to 60.
    ///   - height: Display height. Defaults to 6.
    public init(width: Int = 60, height: Int = 6) {
        self.prompt = ""
        self.placeholder = ""
        self.showLineNumbers = true
        self.endOfBufferCharacter = "~"
        self.cursor = Cursor()
        self.charLimit = nil
        self.maxHeight = 0
        self.keyMap = TextAreaKeyMap()
        self.focusedStyle = TextAreaStyle()
        self.blurredStyle = TextAreaStyle()
        self._value = [[]]  // Start with one empty line
        self._row = 0
        self._col = 0
        self._width = width
        self._height = height
        self._focused = false
        self._viewport = Viewport(width: width, height: height)
    }

    // MARK: - ELM interface

    /// Returns a command to start cursor blinking if focused.
    public func initialize() -> Command? {
        cursor.initialize()
    }

    /// Handles key input and cursor blink messages.
    public mutating func update(_ msg: any Message) -> Command? {
        // Delegate cursor blink
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
        } else if keyMap.lineNext.matches(key) {
            lineNext()
        } else if keyMap.linePrevious.matches(key) {
            linePrevious()
        } else if keyMap.lineStart.matches(key) {
            _col = 0
        } else if keyMap.lineEnd.matches(key) {
            _col = currentLine.count
        } else if keyMap.inputBegin.matches(key) {
            _row = 0
            _col = 0
        } else if keyMap.inputEnd.matches(key) {
            _row = _value.count - 1
            _col = currentLine.count
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
        // Newline
        else if keyMap.insertNewline.matches(key) {
            insertNewline()
        }
        // Word transforms
        else if keyMap.uppercaseWordForward.matches(key) {
            transformWordForward { $0.uppercased() }
        } else if keyMap.lowercaseWordForward.matches(key) {
            transformWordForward { $0.lowercased() }
        }
        // Transpose
        else if keyMap.transposeCharacterBackward.matches(key) {
            transposeCharacterBackward()
        }
        // Character input
        else if key.type.isRunes {
            for char in key.runes {
                insertCharacter(char)
            }
        }

        updateViewport()
        return nil
    }

    /// Renders the text area.
    public var body: ViewOutput {
        let activeStyle = _focused ? focusedStyle : blurredStyle

        // Show placeholder if empty and unfocused
        if _value == [[]] && !_focused {
            return ViewOutput(activeStyle.placeholder.styledText(placeholder))
        }

        var lines: [StyledText] = []
        let lineNumberWidth = showLineNumbers ? String(_value.count).count + 1 : 0

        for (i, line) in _value.enumerated() {
            var renderedLine = StyledText()

            // Line number
            if showLineNumbers {
                let num = String(format: "%\(lineNumberWidth)d ", i + 1)
                if i == _row {
                    renderedLine += activeStyle.cursorLineNumber.styledText(num)
                } else {
                    renderedLine += activeStyle.lineNumber.styledText(num)
                }
            }

            // Prompt
            if !prompt.isEmpty {
                renderedLine += activeStyle.prompt.styledText(prompt)
            }

            // Line content
            let lineStr = String(line)
            if i == _row && _focused {
                // Render with cursor — use .content directly to preserve structured styling.
                let preCursor = String(line.prefix(_col))
                let cursorChar: String
                if _col < line.count {
                    cursorChar = String(line[_col])
                } else {
                    cursorChar = " "
                }
                let postCursor = _col + 1 < line.count
                    ? String(line[(_col + 1)...])
                    : ""

                renderedLine += activeStyle.text.styledText(preCursor)
                var cursorCopy = cursor
                cursorCopy.setChar(cursorChar)
                renderedLine += cursorCopy.body.content
                if !postCursor.isEmpty {
                    renderedLine += activeStyle.text.styledText(postCursor)
                }

                // Apply cursor-line background over all segments on this line.
                renderedLine = renderedLine.styled(activeStyle.cursorLine.textAttributes)
            } else {
                renderedLine += activeStyle.text.styledText(lineStr)
            }

            lines.append(renderedLine)
        }

        // End-of-buffer lines
        let totalLines = max(_height, lines.count)
        while lines.count < totalLines {
            var eob = StyledText()
            if showLineNumbers {
                eob += StyledText(String(repeating: " ", count: lineNumberWidth + 1))
            }
            eob += activeStyle.endOfBuffer.styledText(String(endOfBufferCharacter))
            lines.append(eob)
        }

        // Apply viewport-style windowing
        let startLine = max(0, min(_row - _height / 2, lines.count - _height))
        let endLine = min(startLine + _height, lines.count)
        let visibleStart = max(0, startLine)

        let visibleLines = Array(lines[visibleStart..<endLine])
        return ViewOutput(visibleLines.joined())
    }

    // MARK: - Public API

    /// The current text value (all lines joined with newlines).
    public var value: String {
        _value.map { String($0) }.joined(separator: "\n")
    }

    /// Sets the text value.
    public mutating func setValue(_ text: String) {
        _value = text.split(separator: "\n", omittingEmptySubsequences: false)
            .map { Array($0) }
        if _value.isEmpty { _value = [[]] }
        _row = min(_row, _value.count - 1)
        _col = min(_col, currentLine.count)
    }

    /// Whether the text area is focused.
    public var isFocused: Bool { _focused }

    /// Focuses the text area.
    @discardableResult
    public mutating func focus() -> Command? {
        _focused = true
        return cursor.focus()
    }

    /// Blurs the text area.
    public mutating func blur() {
        _focused = false
        cursor.blur()
    }

    /// Sets the display dimensions.
    public mutating func setSize(width: Int, height: Int) {
        _width = width
        _height = height
        _viewport.width = width
        _viewport.height = height
    }

    /// The number of lines in the text area.
    public var lineCount: Int { _value.count }

    /// Information about the current line.
    public var currentLineInfo: LineInfo {
        LineInfo(
            lineNumber: _row,
            columnOffset: _col,
            width: currentLine.count,
            charCount: _value.reduce(0) { $0 + $1.count } + _value.count - 1
        )
    }

    /// Inserts a string at the current cursor position.
    public mutating func insertString(_ text: String) {
        for char in text {
            if char == "\n" {
                insertNewline()
            } else {
                insertCharacter(char)
            }
        }
    }

    // MARK: - Private helpers

    private var currentLine: [Character] {
        _value[_row]
    }

    private mutating func insertCharacter(_ char: Character) {
        if let limit = charLimit {
            let totalChars = _value.reduce(0) { $0 + $1.count }
            guard totalChars < limit else { return }
        }
        _value[_row].insert(char, at: _col)
        _col += 1
    }

    private mutating func insertNewline() {
        if maxHeight > 0 && _value.count >= maxHeight { return }

        let remainder = Array(_value[_row][_col...])
        _value[_row] = Array(_value[_row][..<_col])
        _row += 1
        _value.insert(remainder, at: _row)
        _col = 0
    }

    private mutating func deleteCharacterBackward() {
        if _col > 0 {
            _col -= 1
            _value[_row].remove(at: _col)
        } else if _row > 0 {
            // Merge with previous line
            let currentChars = _value[_row]
            _value.remove(at: _row)
            _row -= 1
            _col = _value[_row].count
            _value[_row].append(contentsOf: currentChars)
        }
    }

    private mutating func deleteCharacterForward() {
        if _col < currentLine.count {
            _value[_row].remove(at: _col)
        } else if _row < _value.count - 1 {
            // Merge next line into current
            let nextChars = _value[_row + 1]
            _value.remove(at: _row + 1)
            _value[_row].append(contentsOf: nextChars)
        }
    }

    private mutating func deleteWordBackward() {
        let oldCol = _col
        wordBackward()
        if _row < _value.count && _col < oldCol {
            _value[_row].removeSubrange(_col..<oldCol)
        }
    }

    private mutating func deleteWordForward() {
        let oldCol = _col
        let oldRow = _row
        wordForward()
        if _row == oldRow {
            _value[_row].removeSubrange(oldCol..<_col)
            _col = oldCol
        }
    }

    private mutating func deleteAfterCursor() {
        _value[_row].removeSubrange(_col..<_value[_row].count)
    }

    private mutating func deleteBeforeCursor() {
        _value[_row].removeSubrange(0..<_col)
        _col = 0
    }

    private mutating func characterForward() {
        if _col < currentLine.count {
            _col += 1
        } else if _row < _value.count - 1 {
            _row += 1
            _col = 0
        }
    }

    private mutating func characterBackward() {
        if _col > 0 {
            _col -= 1
        } else if _row > 0 {
            _row -= 1
            _col = _value[_row].count
        }
    }

    private mutating func wordForward() {
        let line = currentLine
        while _col < line.count && !line[_col].isLetter { _col += 1 }
        while _col < line.count && line[_col].isLetter { _col += 1 }
    }

    private mutating func wordBackward() {
        let line = currentLine
        while _col > 0 && !line[_col - 1].isLetter { _col -= 1 }
        while _col > 0 && line[_col - 1].isLetter { _col -= 1 }
    }

    private mutating func lineNext() {
        if _row < _value.count - 1 {
            _row += 1
            _col = min(_col, currentLine.count)
        }
    }

    private mutating func linePrevious() {
        if _row > 0 {
            _row -= 1
            _col = min(_col, currentLine.count)
        }
    }

    private mutating func transposeCharacterBackward() {
        guard _col > 0 && _col <= currentLine.count else { return }
        let swapIndex = _col < currentLine.count ? _col : _col - 1
        guard swapIndex > 0 else { return }
        _value[_row].swapAt(swapIndex - 1, swapIndex)
    }

    private mutating func transformWordForward(_ transform: (String) -> String) {
        let startCol = _col
        wordForward()
        guard _col > startCol else { return }

        let word = String(_value[_row][startCol..<_col])
        let transformed = Array(transform(word))
        _value[_row].replaceSubrange(startCol..<_col, with: transformed)
        _col = startCol + transformed.count
    }

    private mutating func updateViewport() {
        let content = _value.map { String($0) }.joined(separator: "\n")
        _viewport.setContent(content)

        // Keep cursor row visible
        if _row < _viewport.yOffset {
            _viewport.yOffset = _row
        } else if _row >= _viewport.yOffset + _height {
            _viewport.yOffset = _row - _height + 1
        }
    }
}

// MARK: - Array subscript helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
