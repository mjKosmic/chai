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

    @Test func viewOutputHidesCursor() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput("Content", cursorHidden: true))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.hideCursor))
    }

    @Test func viewOutputShowsCursorAfterHiding() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        // Hide cursor.
        await renderer.write(ViewOutput("Frame 1", cursorHidden: true))
        await renderer.flush()
        mock.reset()
        // Show cursor.
        await renderer.write(ViewOutput("Frame 2", cursorHidden: false))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.showCursor))
    }

    @Test func viewOutputNilCursorDoesNotTransition() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.hideCursor()
        mock.reset()
        // ViewOutput with nil cursorHidden should NOT show cursor.
        await renderer.write(ViewOutput("Content"))
        await renderer.flush()
        #expect(!mock.output.contains(ANSI.showCursor))
    }

    @Test func viewOutputCombinesMultipleTerminalStateChanges() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput(
            "Full featured",
            altScreen: true,
            windowTitle: "My App",
            cursorHidden: true
        ))
        await renderer.flush()
        #expect(mock.output.contains(ANSI.enterAltScreen))
        #expect(mock.output.contains("My App"))
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
}

// MARK: - ViewOutput Tests

@Suite("ViewOutput")
struct ViewOutputTests {

    @Test func stringLiteralCreatesViewOutput() {
        let view: ViewOutput = "Hello, world!"
        #expect(view.content == "Hello, world!")
        #expect(view.altScreen == nil)
        #expect(view.windowTitle == nil)
        #expect(view.cursorHidden == nil)
    }

    @Test func stringInterpolationCreatesViewOutput() {
        let count = 42
        let view: ViewOutput = "Count: \(count)"
        #expect(view.content == "Count: 42")
        #expect(view.altScreen == nil)
    }

    @Test func explicitInitSetsAllFields() {
        let view = ViewOutput(
            "Content",
            altScreen: true,
            windowTitle: "Title",
            cursorHidden: false
        )
        #expect(view.content == "Content")
        #expect(view.altScreen == true)
        #expect(view.windowTitle == "Title")
        #expect(view.cursorHidden == false)
    }

    @Test func defaultsAreNil() {
        let view = ViewOutput("Just content")
        #expect(view.content == "Just content")
        #expect(view.altScreen == nil)
        #expect(view.windowTitle == nil)
        #expect(view.cursorHidden == nil)
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
}
