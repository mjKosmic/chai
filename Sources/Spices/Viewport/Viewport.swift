import Chai
// MARK: - Viewport KeyMap

/// Keybindings for viewport scrolling.
public struct ViewportKeyMap: Sendable {
    public var pageDown: KeyBinding
    public var pageUp: KeyBinding
    public var halfPageDown: KeyBinding
    public var halfPageUp: KeyBinding
    public var down: KeyBinding
    public var up: KeyBinding
    public var left: KeyBinding
    public var right: KeyBinding

    /// Creates a viewport key map with default bindings.
    public init(
        pageDown: KeyBinding = KeyBinding(
            .type(.pageDown), .rune("f"),
            help: KeyHelp("f/pgdn", "page down")
        ),
        pageUp: KeyBinding = KeyBinding(
            .type(.pageUp), .rune("b"),
            help: KeyHelp("b/pgup", "page up")
        ),
        halfPageDown: KeyBinding = KeyBinding(
            .rune("d"),
            help: KeyHelp("d", "½ page down")
        ),
        halfPageUp: KeyBinding = KeyBinding(
            .rune("u"),
            help: KeyHelp("u", "½ page up")
        ),
        down: KeyBinding = KeyBinding(
            .type(.down), .rune("j"),
            help: KeyHelp("↓/j", "down")
        ),
        up: KeyBinding = KeyBinding(
            .type(.up), .rune("k"),
            help: KeyHelp("↑/k", "up")
        ),
        left: KeyBinding = KeyBinding(
            .type(.left), .rune("h"),
            help: KeyHelp("←/h", "left")
        ),
        right: KeyBinding = KeyBinding(
            .type(.right), .rune("l"),
            help: KeyHelp("→/l", "right")
        )
    ) {
        self.pageDown = pageDown
        self.pageUp = pageUp
        self.halfPageDown = halfPageDown
        self.halfPageUp = halfPageUp
        self.down = down
        self.up = up
        self.left = left
        self.right = right
    }
}

// MARK: - Viewport

/// A scrollable viewport for displaying text content.
///
/// The viewport handles vertical and horizontal scrolling of text that
/// may exceed the visible area. It supports keyboard navigation and
/// provides scroll position information.
///
/// > Note: Horizontal scrolling and line-width measurement use Swift's
/// > `Character`-count (`String.count`), not visible terminal columns.
/// > This means wide characters (CJK, emoji) and ANSI escape sequences
/// > are not measured accurately for the purposes of horizontal offset
/// > and truncation. Vertical scrolling is unaffected.
///
/// ```swift
/// var viewport = Viewport(width: 80, height: 24)
/// viewport.setContent(longText)
///
/// // In update():
/// viewport.update(msg)
///
/// // In body:
/// viewport.body
/// ```
public struct Viewport: View {
    /// The width of the viewport in columns.
    public var width: Int

    /// The height of the viewport in rows.
    public var height: Int

    /// The vertical scroll offset (number of lines scrolled from the top).
    public var yOffset: Int

    /// Style applied to the viewport content.
    public var style: Style

    /// Whether keyboard input should be handled.
    public var keyMap: ViewportKeyMap

    /// The horizontal scroll step size in characters.
    public var horizontalStep: Int

    // MARK: Private state

    private var _xOffset: Int
    private var _lines: [String]
    private var _longestLineWidth: Int

    // MARK: - Initializer

    /// Creates a new viewport.
    ///
    /// - Parameters:
    ///   - width: Viewport width in columns.
    ///   - height: Viewport height in rows.
    public init(width: Int = 80, height: Int = 24) {
        self.width = width
        self.height = height
        self.yOffset = 0
        self.style = Style()
        self.keyMap = ViewportKeyMap()
        self.horizontalStep = 4
        self._xOffset = 0
        self._lines = []
        self._longestLineWidth = 0
    }

    // MARK: - ELM interface

    /// No initial command needed.
    public func initialize() -> Command? { nil }

    /// Handles keyboard input for scrolling.
    public mutating func update(_ msg: any Message) -> Command? {
        if let key = msg as? KeyMsg {
            handleKey(key)
        } else if let size = msg as? WindowSizeMsg {
            width = size.width
            height = size.height
            clampOffsets()
        }
        return nil
    }

    /// Renders the visible portion of the content.
    public var body: ViewOutput {
        guard height > 0, width > 0 else { return "" }

        var visibleLines: [String] = []
        let startLine = yOffset
        let endLine = min(startLine + height, _lines.count)

        for i in startLine..<endLine {
            let line = _lines[i]
            let truncated = truncateLine(line, offset: _xOffset, width: width)
            visibleLines.append(truncated)
        }

        // Pad with empty lines if content is shorter than viewport
        while visibleLines.count < height {
            visibleLines.append(String(repeating: " ", count: width))
        }

        // Join lines as plain text (truncateLine returns no ANSI), then apply
        // the viewport style structurally so the cell-buffer renderer sees clean
        // TextAttributes metadata rather than embedded escape bytes.
        let output = visibleLines.joined(separator: "\n")
        return ViewOutput(style.styledText(output))
    }

    // MARK: - Content management

    /// Sets the viewport content, splitting it into lines.
    ///
    /// Line widths are measured by `String.count` (Swift `Character` count),
    /// not by visible terminal columns. Wide characters and ANSI sequences
    /// will therefore be counted incorrectly for horizontal scrolling purposes.
    ///
    /// - Parameter content: The full text content.
    public mutating func setContent(_ content: String) {
        _lines = content.split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        _longestLineWidth = _lines.reduce(0) { max($0, $1.count) }
        clampOffsets()
    }

    /// The total number of lines in the content.
    public var totalLineCount: Int { _lines.count }

    /// The number of visible lines.
    public var visibleLineCount: Int {
        min(height, max(0, _lines.count - yOffset))
    }

    // MARK: - Vertical scrolling

    /// Scrolls down by the given number of lines.
    public mutating func scrollDown(_ n: Int = 1) {
        yOffset = min(yOffset + n, maxYOffset)
    }

    /// Scrolls up by the given number of lines.
    public mutating func scrollUp(_ n: Int = 1) {
        yOffset = max(yOffset - n, 0)
    }

    /// Scrolls down by one full page.
    public mutating func pageDown() {
        scrollDown(height)
    }

    /// Scrolls up by one full page.
    public mutating func pageUp() {
        scrollUp(height)
    }

    /// Scrolls down by half a page.
    public mutating func halfPageDown() {
        scrollDown(height / 2)
    }

    /// Scrolls up by half a page.
    public mutating func halfPageUp() {
        scrollUp(height / 2)
    }

    /// Scrolls to the top of the content.
    public mutating func gotoTop() {
        yOffset = 0
    }

    /// Scrolls to the bottom of the content.
    public mutating func gotoBottom() {
        yOffset = maxYOffset
    }

    /// Whether the viewport is scrolled to the top.
    public var atTop: Bool { yOffset <= 0 }

    /// Whether the viewport is scrolled to the bottom.
    public var atBottom: Bool { yOffset >= maxYOffset }

    /// The vertical scroll percentage (0.0 – 1.0).
    ///
    /// Returns `0.0` when there is no scrollable overflow, consistent with
    /// ``horizontalScrollPercent`` which also returns `0.0` in that case.
    public var scrollPercent: Double {
        guard maxYOffset > 0 else { return 0.0 }
        return Double(yOffset) / Double(maxYOffset)
    }

    // MARK: - Horizontal scrolling

    /// Scrolls right by the horizontal step size.
    public mutating func scrollRight(_ n: Int = 0) {
        let step = n > 0 ? n : horizontalStep
        _xOffset = min(_xOffset + step, maxXOffset)
    }

    /// Scrolls left by the horizontal step size.
    public mutating func scrollLeft(_ n: Int = 0) {
        let step = n > 0 ? n : horizontalStep
        _xOffset = max(_xOffset - step, 0)
    }

    /// The horizontal scroll percentage (0.0 – 1.0).
    public var horizontalScrollPercent: Double {
        guard maxXOffset > 0 else { return 0.0 }
        return Double(_xOffset) / Double(maxXOffset)
    }

    // MARK: - Computed limits

    private var maxYOffset: Int {
        max(0, _lines.count - height)
    }

    private var maxXOffset: Int {
        max(0, _longestLineWidth - width)
    }

    // MARK: - Private

    private mutating func handleKey(_ key: KeyMsg) {
        if keyMap.down.matches(key) {
            scrollDown()
        } else if keyMap.up.matches(key) {
            scrollUp()
        } else if keyMap.pageDown.matches(key) {
            pageDown()
        } else if keyMap.pageUp.matches(key) {
            pageUp()
        } else if keyMap.halfPageDown.matches(key) {
            halfPageDown()
        } else if keyMap.halfPageUp.matches(key) {
            halfPageUp()
        } else if keyMap.left.matches(key) {
            scrollLeft()
        } else if keyMap.right.matches(key) {
            scrollRight()
        }
    }

    private mutating func clampOffsets() {
        yOffset = max(0, min(yOffset, maxYOffset))
        _xOffset = max(0, min(_xOffset, maxXOffset))
    }

    /// Truncates a line to the visible horizontal window.
    ///
    /// Uses `Array(Character)` slicing, so offsets and widths are in Swift
    /// `Character` units rather than visible terminal columns. Wide characters
    /// (CJK, emoji) and ANSI escape sequences are not column-aware.
    private func truncateLine(_ line: String, offset: Int, width: Int) -> String {
        let chars = Array(line)
        guard offset < chars.count else {
            return String(repeating: " ", count: width)
        }
        let end = min(offset + width, chars.count)
        let visible = String(chars[offset..<end])

        // Pad if the visible portion is shorter than the viewport width
        let padding = width - (end - offset)
        if padding > 0 {
            return visible + String(repeating: " ", count: padding)
        }
        return visible
    }
}
