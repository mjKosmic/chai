import Testing
@testable import Chai

// MARK: - Test helpers

/// A mock `TerminalOutput` that captures written strings for inspection.
final class MockTerminal: TerminalOutput, @unchecked Sendable {
    private(set) var output: String = ""

    func write(_ string: String) {
        output += string
    }

    func reset() { output = "" }
}

// MARK: - Tests

@Suite("Renderer")
struct RendererTests {

    // MARK: - Basic rendering

    @Test func firstRenderWritesView() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Hello, world!")
        await renderer.flush()
        #expect(mock.output.contains("Hello, world!"))
    }

    @Test func unchangedViewIsNotRewritten() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Same content")
        await renderer.flush()
        mock.reset()
        // Second flush with the same content — nothing should be written.
        await renderer.flush()
        #expect(mock.output.isEmpty)
    }

    @Test func changedViewIsRewritten() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("First frame")
        await renderer.flush()
        mock.reset()
        await renderer.write("Second frame")
        await renderer.flush()
        #expect(mock.output.contains("Second frame"))
    }

    @Test func emptyViewRendersSpace() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("")
        await renderer.flush()
        // Empty string is replaced with a single space to clear the line.
        #expect(mock.output.contains(" "))
    }

    // MARK: - Multi-line diff

    @Test func onlyChangedLinesAreRewritten() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Line 1\nLine 2\nLine 3")
        await renderer.flush()
        mock.reset()

        // Only line 2 changes.
        await renderer.write("Line 1\nLine 2 CHANGED\nLine 3")
        await renderer.flush()

        // The output should contain the changed line but not the unchanged ones.
        #expect(mock.output.contains("Line 2 CHANGED"))
        #expect(!mock.output.contains("Line 1"))
        #expect(!mock.output.contains("Line 3"))
    }

    @Test func fewerLinesClearsRemainder() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Line 1\nLine 2\nLine 3")
        await renderer.flush()
        mock.reset()

        // Render fewer lines — should erase below.
        await renderer.write("Line 1")
        await renderer.flush()
        #expect(mock.output.contains(ANSI.eraseScreenBelow))
    }

    // MARK: - Repaint

    @Test func repaintForcesFullRedraw() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Content")
        await renderer.flush()
        mock.reset()

        await renderer.repaint()
        await renderer.flush()
        // After repaint, the same content must be re-written.
        #expect(mock.output.contains("Content"))
    }

    // MARK: - Alt screen

    @Test func enterAltScreenEmitsSequence() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        #expect(mock.output.contains(ANSI.enterAltScreen))
        #expect(await renderer.altScreenActive)
    }

    @Test func exitAltScreenEmitsSequence() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        mock.reset()
        await renderer.exitAltScreen()
        #expect(mock.output.contains(ANSI.exitAltScreen))
        #expect(await !renderer.altScreenActive)
    }

    @Test func enterAltScreenIsIdempotent() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        mock.reset()
        await renderer.enterAltScreen() // second call — no-op
        #expect(!mock.output.contains(ANSI.enterAltScreen))
    }

    // MARK: - Cursor

    @Test func hideCursorEmitsSequence() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.hideCursor()
        #expect(mock.output.contains(ANSI.hideCursor))
    }

    @Test func showCursorEmitsSequence() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.hideCursor()
        mock.reset()
        await renderer.showCursor()
        #expect(mock.output.contains(ANSI.showCursor))
    }

    // MARK: - Window title

    @Test func setWindowTitleEmitsOSCSequence() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setWindowTitle("My App")
        #expect(mock.output.contains("My App"))
        #expect(mock.output.contains("\u{1B}]0;"))
    }

    // MARK: - Terminal size clamping

    @Test func linesClampedToTerminalHeight() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 80, height: 3)
        // 10-line view should be clamped to 3 lines.
        let content = (1...10).map { "Line \($0)" }.joined(separator: "\n")
        await renderer.write(ViewOutput(content))
        await renderer.flush()
        // Only the last 3 lines should appear.
        #expect(mock.output.contains("Line 8"))
        #expect(mock.output.contains("Line 9"))
        #expect(mock.output.contains("Line 10"))
        #expect(!mock.output.contains("Line 1\n"))
    }

    // MARK: - Println

    @Test func printlnQueuesLineAboveView() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Live view")
        await renderer.flush()
        mock.reset()

        await renderer.println("Logged message")
        await renderer.flush()
        // The queued line should appear before the live view content.
        let idx1 = mock.output.range(of: "Logged message")
        let idx2 = mock.output.range(of: "Live view")
        #expect(idx1 != nil)
        #expect(idx2 != nil)
        if let r1 = idx1, let r2 = idx2 {
            #expect(r1.lowerBound < r2.lowerBound)
        }
    }

    @Test func printlnNoopInAltScreen() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        mock.reset()
        await renderer.println("Should not appear")
        await renderer.flush()
        #expect(!mock.output.contains("Should not appear"))
    }

    // MARK: - Declarative ViewOutput terminal state

    @Test func viewOutputEntersAltScreen() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // Declare alt screen via ViewOutput.
        await renderer.write(ViewOutput("Hello", altScreen: true))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.enterAltScreen))
        #expect(await renderer.altScreenActive)
        #expect(mock.output.contains("Hello"))
    }

    @Test func viewOutputExitsAltScreen() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // Enter alt screen via ViewOutput.
        await renderer.write(ViewOutput("Frame 1", altScreen: true))
        await renderer.flush()
        mock.reset()
        // Exit alt screen via ViewOutput.
        await renderer.write(ViewOutput("Frame 2", altScreen: false))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.exitAltScreen))
        #expect(await !renderer.altScreenActive)
        #expect(mock.output.contains("Frame 2"))
    }

    @Test func viewOutputNilAltScreenDoesNotTransition() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        mock.reset()
        // ViewOutput with nil altScreen should NOT exit alt screen.
        await renderer.write(ViewOutput("Content"))
        await renderer.flush()
        #expect(!mock.output.contains(ANSI.exitAltScreen))
        #expect(await renderer.altScreenActive)
    }

    @Test func viewOutputSetsWindowTitle() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput("Content", windowTitle: "My App"))
        await renderer.flush()
        #expect(mock.output.contains("My App"))
        #expect(mock.output.contains("\u{1B}]0;"))
    }

    @Test func viewOutputWindowTitleNotRewrittenWhenUnchanged() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput("Frame 1", windowTitle: "My App"))
        await renderer.flush()
        mock.reset()
        // Same title, different content — title should not be rewritten.
        await renderer.write(ViewOutput("Frame 2", windowTitle: "My App"))
        await renderer.flush()
        #expect(!mock.output.contains("\u{1B}]0;"))
        #expect(mock.output.contains("Frame 2"))
    }

    @Test func altScreenAutoHidesCursor() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // Entering alt screen should automatically hide the cursor.
        await renderer.write(ViewOutput("Content", altScreen: true))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.hideCursor))
    }

    @Test func altScreenCursorShownWhenSpecified() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        mock.reset()
        // Alt screen auto-hides cursor, but specifying a cursor should show it.
        let cursor = Cursor(position: .init(col: 0, row: 0))
        await renderer.write(ViewOutput("Content", cursor: cursor))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.showCursor))
    }

    @Test func altScreenReHidesCursorWhenCursorRemoved() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        // First frame: cursor specified — cursor becomes visible.
        let cursor = Cursor(position: .init(col: 0, row: 0))
        await renderer.write(ViewOutput("Frame 1", cursor: cursor))
        await renderer.flush()
        mock.reset()
        // Second frame: no cursor — alt screen should auto-hide again.
        await renderer.write(ViewOutput("Frame 2"))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.hideCursor))
    }

    @Test func normalModeNoCursorDoesNotHide() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // In normal mode with no cursor, cursor state is unchanged.
        await renderer.write(ViewOutput("Content"))
        await renderer.flush()
        #expect(!mock.output.contains(ANSI.hideCursor))
        #expect(!mock.output.contains(ANSI.showCursor))
    }

    @Test func viewOutputCombinesMultipleTerminalStateChanges() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput(
            "Full featured",
            altScreen: true,
            windowTitle: "My App"
        ))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.enterAltScreen))
        #expect(mock.output.contains("My App"))
        // Alt screen automatically hides cursor.
        #expect(mock.output.contains(ANSI.hideCursor))
        #expect(mock.output.contains("Full featured"))
    }

    @Test func altScreenTransitionClearsRenderCache() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput("Same content"))
        await renderer.flush()
        mock.reset()
        // Enter alt screen with same content — should still render because
        // the transition clears the render cache.
        await renderer.write(ViewOutput("Same content", altScreen: true))
        await renderer.flush()
        #expect(mock.output.contains("Same content"))
    }

    @Test func stringLiteralViewOutputHasNilTerminalState() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // String literal creates ViewOutput with all-nil terminal state.
        await renderer.write("Just a string")
        await renderer.flush()
        // Should NOT enter alt screen, set title, or change cursor.
        #expect(!mock.output.contains(ANSI.enterAltScreen))
        #expect(!mock.output.contains("\u{1B}]0;"))
        #expect(!mock.output.contains(ANSI.hideCursor))
        #expect(mock.output.contains("Just a string"))
    }

    // MARK: - Synchronized output

    @Test func flushWrapsSyncUpdateMarkers() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Content")
        await renderer.flush()
        #expect(mock.output.hasPrefix(ANSI.beginSyncUpdate))
        #expect(mock.output.hasSuffix(ANSI.endSyncUpdate))
    }

    @Test func unchangedViewDoesNotEmitSyncMarkers() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write("Same")
        await renderer.flush()
        mock.reset()
        // Second flush with identical content — nothing written.
        await renderer.flush()
        #expect(!mock.output.contains(ANSI.beginSyncUpdate))
        #expect(mock.output.isEmpty)
    }

    // MARK: - ANSI-aware width truncation

    @Test func ansiCodesDoNotCountTowardWidth() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 10, height: 24)
        // "Red text" is 8 visible characters — fits in 10 columns.
        // But with ANSI codes, the string is 22 characters long.
        let styled = "\u{1B}[31mRed text\u{1B}[0m"
        await renderer.write(ViewOutput(styled))
        await renderer.flush()
        // The full styled string should appear because it's only 8 visible cols.
        #expect(mock.output.contains("Red text"))
        #expect(mock.output.contains("\u{1B}[31m"))
        #expect(mock.output.contains("\u{1B}[0m"))
    }

    @Test func longPlainTextIsTruncated() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.write("ABCDEFGH")
        await renderer.flush()
        #expect(mock.output.contains("ABCDE"))
        #expect(!mock.output.contains("ABCDEFGH"))
    }
}

// MARK: - DisplayWidth Tests

@Suite("DisplayWidth")
struct DisplayWidthTests {

    // MARK: - displayWidth(of: Character)

    @Test func asciiCharacterIsWidth1() {
        #expect(displayWidth(of: Character("A")) == 1)
        #expect(displayWidth(of: Character("z")) == 1)
        #expect(displayWidth(of: Character("0")) == 1)
    }

    @Test func cjkCharacterIsWidth2() {
        #expect(displayWidth(of: Character("你")) == 2)   // U+4F60
        #expect(displayWidth(of: Character("好")) == 2)   // U+597D
        #expect(displayWidth(of: Character("漢")) == 2)   // U+6F22
    }

    @Test func hangulSyllableIsWidth2() {
        #expect(displayWidth(of: Character("한")) == 2)   // U+D55C
        #expect(displayWidth(of: Character("글")) == 2)   // U+AE00
    }

    @Test func fullwidthLatinIsWidth2() {
        #expect(displayWidth(of: Character("Ａ")) == 2)   // U+FF21 fullwidth A
    }

    @Test func controlCharacterIsWidth0() {
        #expect(displayWidth(of: Character("\u{00}")) == 0)
        #expect(displayWidth(of: Character("\u{1B}")) == 0)  // ESC
    }

    // MARK: - visibleWidth

    @Test func visibleWidthOfPlainASCII() {
        #expect(visibleWidth(of: "Hello") == 5)
    }

    @Test func visibleWidthIgnoresANSICodes() {
        let styled = "\u{1B}[31mHello\u{1B}[0m"
        #expect(visibleWidth(of: styled) == 5)
    }

    @Test func visibleWidthCountsCJKAsDouble() {
        #expect(visibleWidth(of: "你好") == 4)
    }

    @Test func visibleWidthMixedASCIIAndCJK() {
        #expect(visibleWidth(of: "Hi你好") == 6)  // 2 + 4
    }

    @Test func visibleWidthIgnoresOSCSequence() {
        let osc = "\u{1B}]0;Title\u{07}Hello"
        #expect(visibleWidth(of: osc) == 5)
    }

    // MARK: - truncateToVisibleWidth

    @Test func truncatePlainASCII() {
        #expect(truncateToVisibleWidth("ABCDEFGH", maxWidth: 5) == "ABCDE")
    }

    @Test func truncatePreservesANSICodes() {
        let styled = "\u{1B}[31mRed text\u{1B}[0m"
        let result = truncateToVisibleWidth(styled, maxWidth: 3)
        // Should keep "Red" (3 visible cols) plus the ANSI prefix.
        #expect(result.contains("\u{1B}[31m"))
        #expect(result.contains("Red"))
        #expect(!result.contains("text"))
    }

    @Test func truncateHandlesWideCharacterBoundary() {
        // "AB你" is 4 columns (1+1+2). Truncating to 3 should drop 你.
        #expect(truncateToVisibleWidth("AB你", maxWidth: 3) == "AB")
    }

    @Test func truncateFitsExactly() {
        #expect(truncateToVisibleWidth("AB你", maxWidth: 4) == "AB你")
    }

    @Test func truncateZeroWidthReturnsEmpty() {
        #expect(truncateToVisibleWidth("Hello", maxWidth: 0) == "")
    }

    @Test func truncateCJKString() {
        // "你好世界" = 8 columns. Truncate to 5 → "你好" (4 cols).
        // "世" would push to 6, so it's excluded.
        #expect(truncateToVisibleWidth("你好世界", maxWidth: 5) == "你好")
    }

    @Test func truncatePreservesTrailingANSIReset() {
        // When the visible content fits, ANSI codes should pass through.
        let styled = "\u{1B}[1mBold\u{1B}[0m"
        let result = truncateToVisibleWidth(styled, maxWidth: 10)
        #expect(result == styled)
    }

    // MARK: - SS3 / SS2 / two-byte escape sequences

    @Test func visibleWidthIgnoresSS3Sequence() {
        // SS3 Up arrow: ESC O A — all three bytes should be skipped.
        let ss3 = "\u{1B}OAHello"
        #expect(visibleWidth(of: ss3) == 5)
    }

    @Test func visibleWidthIgnoresSS2Sequence() {
        // SS2 sequence: ESC N x — all three bytes should be skipped.
        let ss2 = "\u{1B}NxHello"
        #expect(visibleWidth(of: ss2) == 5)
    }

    @Test func visibleWidthIgnoresSimpleTwoByteEscape() {
        // Application keypad mode: ESC = — two bytes total.
        let esc = "\u{1B}=Hello"
        #expect(visibleWidth(of: esc) == 5)
    }

    @Test func truncateSkipsSS3Sequence() {
        // SS3 Up arrow followed by visible text — SS3 has zero visual width.
        let ss3 = "\u{1B}OAHello"
        let result = truncateToVisibleWidth(ss3, maxWidth: 3)
        #expect(result.contains("\u{1B}OA"))
        #expect(result.contains("Hel"))
        #expect(!result.contains("Hello"))
    }

    @Test func truncateSkipsSS2Sequence() {
        let ss2 = "\u{1B}NxHello"
        let result = truncateToVisibleWidth(ss2, maxWidth: 5)
        #expect(result == ss2)
    }

    // MARK: - OSC with ST terminator (ESC \)

    @Test func visibleWidthIgnoresOSCWithSTTerminator() {
        // OSC terminated by ST (ESC \) instead of BEL.
        let osc = "\u{1B}]0;Title\u{1B}\\Hello"
        #expect(visibleWidth(of: osc) == 5)
    }

    @Test func truncateSkipsOSCWithSTTerminator() {
        let osc = "\u{1B}]0;Title\u{1B}\\Hello"
        let result = truncateToVisibleWidth(osc, maxWidth: 3)
        #expect(result.contains("Hel"))
        #expect(!result.contains("Hello"))
        // OSC sequence is preserved (zero visual width).
        #expect(result.contains("\u{1B}]0;"))
    }
}

// MARK: - ViewOutput Tests

@Suite("ViewOutput")
struct ViewOutputTests {

    @Test func stringLiteralCreatesViewOutput() {
        let view: ViewOutput = "Hello, world!"
        #expect(view.content == "Hello, world!")
        #expect(view.altScreen == nil)
        #expect(view.windowTitle == nil)
        #expect(view.cursor == nil)
    }

    @Test func stringInterpolationCreatesViewOutput() {
        let count = 42
        let view: ViewOutput = "Count: \(count)"
        #expect(view.content == "Count: 42")
        #expect(view.altScreen == nil)
    }

    @Test func explicitInitSetsAllFields() {
        let cursor = Cursor(position: .init(col: 0, row: 0))
        let view = ViewOutput(
            "Content",
            altScreen: true,
            windowTitle: "Title",
            cursor: cursor
        )
        #expect(view.content == "Content")
        #expect(view.altScreen == true)
        #expect(view.windowTitle == "Title")
        #expect(view.cursor == cursor)
    }

    @Test func defaultsAreNil() {
        let view = ViewOutput("Just content")
        #expect(view.content == "Just content")
        #expect(view.altScreen == nil)
        #expect(view.windowTitle == nil)
        #expect(view.cursor == nil)
    }

    @Test func equatable() {
        let a = ViewOutput("Hello", altScreen: true)
        let b = ViewOutput("Hello", altScreen: true)
        let c = ViewOutput("Hello", altScreen: false)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func equatableContent() {
        let a = ViewOutput("Hello")
        let b = ViewOutput("World")
        #expect(a != b)
    }

    @Test func initWithCursor() {
        let cursor = Cursor(position: .init(col: 5, row: 2))
        let view = ViewOutput("Content", cursor: cursor)
        #expect(view.cursor == cursor)
    }

    @Test func cursorFieldDefaultsToNil() {
        let view = ViewOutput("Content")
        #expect(view.cursor == nil)
    }

    @Test func equatableWithCursor() {
        let c = Cursor(position: .init(col: 1, row: 0))
        let a = ViewOutput("Hello", cursor: c)
        let b = ViewOutput("Hello", cursor: c)
        let d = ViewOutput("Hello")
        #expect(a == b)
        #expect(a != d)
    }
}

// MARK: - Cursor Tests

@Suite("Cursor")
struct CursorTests {

    @Test func defaultShapeAndBlink() {
        let cursor = Cursor(position: .init(col: 0, row: 0))
        #expect(cursor.shape == .block)
        #expect(cursor.blink == true)
    }

    @Test func customShapeAndBlink() {
        let cursor = Cursor(position: .init(col: 3, row: 1), shape: .bar, blink: false)
        #expect(cursor.position.col == 3)
        #expect(cursor.position.row == 1)
        #expect(cursor.shape == .bar)
        #expect(cursor.blink == false)
    }

    @Test func positionEquatable() {
        let a = Cursor.Position(col: 5, row: 3)
        let b = Cursor.Position(col: 5, row: 3)
        let c = Cursor.Position(col: 5, row: 4)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func shapeEquatable() {
        #expect(Cursor.Shape.block == Cursor.Shape.block)
        #expect(Cursor.Shape.block != Cursor.Shape.underline)
        #expect(Cursor.Shape.underline != Cursor.Shape.bar)
    }

    @Test func cursorEquatable() {
        let a = Cursor(position: .init(col: 1, row: 2), shape: .underline, blink: true)
        let b = Cursor(position: .init(col: 1, row: 2), shape: .underline, blink: true)
        let c = Cursor(position: .init(col: 1, row: 2), shape: .bar, blink: true)
        let d = Cursor(position: .init(col: 1, row: 2), shape: .underline, blink: false)
        #expect(a == b)
        #expect(a != c)
        #expect(a != d)
    }
}

// MARK: - ANSI Cursor Shape Tests

@Suite("ANSI Cursor Shape")
struct ANSICursorShapeTests {

    @Test func setCursorShapeBlockBlinking() {
        #expect(ANSI.setCursorShape(.block, blink: true) == "\u{1B}[1 q")
    }

    @Test func setCursorShapeBlockSteady() {
        #expect(ANSI.setCursorShape(.block, blink: false) == "\u{1B}[2 q")
    }

    @Test func setCursorShapeUnderlineBlinking() {
        #expect(ANSI.setCursorShape(.underline, blink: true) == "\u{1B}[3 q")
    }

    @Test func setCursorShapeUnderlineSteady() {
        #expect(ANSI.setCursorShape(.underline, blink: false) == "\u{1B}[4 q")
    }

    @Test func setCursorShapeBarBlinking() {
        #expect(ANSI.setCursorShape(.bar, blink: true) == "\u{1B}[5 q")
    }

    @Test func setCursorShapeBarSteady() {
        #expect(ANSI.setCursorShape(.bar, blink: false) == "\u{1B}[6 q")
    }

    @Test func resetCursorShape() {
        #expect(ANSI.resetCursorShape == "\u{1B}[0 q")
    }

    @Test func cursorColumn() {
        #expect(ANSI.cursorColumn(1) == "\u{1B}[1G")
        #expect(ANSI.cursorColumn(10) == "\u{1B}[10G")
    }
}

// MARK: - Renderer Cursor Positioning Tests

@Suite("Renderer Cursor Positioning")
struct RendererCursorPositionTests {

    // MARK: - Cursor visibility

    @Test func cursorShownWhenSpecified() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.hideCursor()
        mock.reset()

        let cursor = Cursor(position: .init(col: 0, row: 0))
        await renderer.write(ViewOutput("Hello", cursor: cursor))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.showCursor))
    }

    @Test func cursorRemainsVisibleWhenSpecified() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // Cursor was never hidden — should not emit showCursor.
        let cursor = Cursor(position: .init(col: 0, row: 0))
        await renderer.write(ViewOutput("Hello", cursor: cursor))
        await renderer.flush()
        #expect(!mock.output.contains(ANSI.showCursor))
        #expect(!mock.output.contains(ANSI.hideCursor))
    }

    // MARK: - Cursor positioning in alt screen

    @Test func cursorPositionInAltScreen() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()
        mock.reset()

        let cursor = Cursor(position: .init(col: 5, row: 2))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2\nLine 3", cursor: cursor))
        await renderer.flush()
        // Row 2 (0-based) → terminal row 3 (1-based), col 5 → terminal col 6.
        #expect(mock.output.contains(ANSI.cursorPosition(row: 3, col: 6)))
    }

    // MARK: - Cursor positioning in normal mode

    @Test func cursorPositionInNormalMode() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        let cursor = Cursor(position: .init(col: 3, row: 1))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2", cursor: cursor))
        await renderer.flush()
        // After painting 3 lines, cursor is at row 2 (last line).
        // Target is row 1 → move up by 1.
        // Col 3 → cursorColumn(4) [1-based].
        #expect(mock.output.contains(ANSI.cursorUp(1)))
        #expect(mock.output.contains(ANSI.cursorColumn(4)))
    }

    @Test func cursorAtLastLineNoUpMovement() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        let cursor = Cursor(position: .init(col: 0, row: 2))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2", cursor: cursor))
        await renderer.flush()
        // Cursor is already at row 2 (last line) — no cursorUp needed.
        #expect(!mock.output.contains(ANSI.cursorUp(1)))
        // Column 0 → cursorColumn(1).
        #expect(mock.output.contains(ANSI.cursorColumn(1)))
    }

    // MARK: - Cursor shape

    @Test func cursorShapeEmitted() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        let cursor = Cursor(position: .init(col: 0, row: 0), shape: .bar, blink: false)
        await renderer.write(ViewOutput("Hello", cursor: cursor))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.setCursorShape(.bar, blink: false)))
    }

    @Test func cursorShapeNotReemittedWhenUnchanged() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        let cursor = Cursor(position: .init(col: 0, row: 0), shape: .underline)
        await renderer.write(ViewOutput("Frame 1", cursor: cursor))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.setCursorShape(.underline, blink: true)))
        mock.reset()

        // Same shape, different content — shape should not be re-emitted.
        await renderer.write(ViewOutput("Frame 2", cursor: cursor))
        await renderer.flush()
        #expect(!mock.output.contains(ANSI.setCursorShape(.underline, blink: true)))
    }

    @Test func cursorShapeChangeEmitted() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        let cursor1 = Cursor(position: .init(col: 0, row: 0), shape: .block)
        await renderer.write(ViewOutput("Frame 1", cursor: cursor1))
        await renderer.flush()
        mock.reset()

        // Change shape to bar.
        let cursor2 = Cursor(position: .init(col: 0, row: 0), shape: .bar)
        await renderer.write(ViewOutput("Frame 2", cursor: cursor2))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.setCursorShape(.bar, blink: true)))
    }

    // MARK: - Cursor-only updates (content unchanged)

    @Test func cursorOnlyUpdateEmitsPosition() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.enterAltScreen()

        let cursor1 = Cursor(position: .init(col: 0, row: 0))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2", cursor: cursor1))
        await renderer.flush()
        mock.reset()

        // Same content, different cursor position.
        let cursor2 = Cursor(position: .init(col: 5, row: 1))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2", cursor: cursor2))
        await renderer.flush()
        // Content unchanged, but cursor position should be emitted.
        #expect(mock.output.contains(ANSI.cursorPosition(row: 2, col: 6)))
        // Content lines should NOT be re-rendered.
        #expect(!mock.output.contains("Line 0"))
    }

    @Test func cursorOnlyUpdateNormalMode() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        // First render: cursor at row 0.
        let cursor1 = Cursor(position: .init(col: 0, row: 0))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2", cursor: cursor1))
        await renderer.flush()
        mock.reset()

        // Same content, cursor moves to row 2 (down from row 0).
        let cursor2 = Cursor(position: .init(col: 3, row: 2))
        await renderer.write(ViewOutput("Line 0\nLine 1\nLine 2", cursor: cursor2))
        await renderer.flush()
        // Should move down 2 rows and to column 4.
        #expect(mock.output.contains(ANSI.cursorDown(2)))
        #expect(mock.output.contains(ANSI.cursorColumn(4)))
    }

    // MARK: - Combined state

    @Test func cursorWithAltScreenAndTitle() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)

        let cursor = Cursor(position: .init(col: 2, row: 1), shape: .underline, blink: false)
        await renderer.write(ViewOutput(
            "Line 0\nLine 1\nLine 2",
            altScreen: true,
            windowTitle: "Cursor Test",
            cursor: cursor
        ))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.enterAltScreen))
        #expect(mock.output.contains("Cursor Test"))
        #expect(mock.output.contains(ANSI.setCursorShape(.underline, blink: false)))
        #expect(mock.output.contains(ANSI.cursorPosition(row: 2, col: 3)))
        #expect(mock.output.contains("Line 1"))
    }
}
