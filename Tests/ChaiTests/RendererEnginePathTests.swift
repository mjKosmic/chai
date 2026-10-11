import Testing
@testable import Chai
import Latte

// MARK: - M3 renderer engine-path tests
//
// Milestone M3 of the phase-2 layout engine: `Renderer.flush()` now builds
// its ``CellBuffer`` through the layout engine (`_sizeThatFits` +
// `_render`) instead of resolving the tree eagerly to a ``ViewOutput`` and
// rasterizing the styled text. These tests pin every renderer-level policy
// through the engine path:
//
// - Real trees (VStack/HStack, control flow) written via the generic
//   `write` render correctly after `flush`.
// - Inline truncation: over-wide content truncates at the terminal width.
// - Inline suffix clamp: content taller than the terminal shows its LAST
//   `termHeight` rows (the engine's negative-row-origin equivalent of
//   `StyledText.suffix(lines:)`).
// - Empty trees produce no visible output (the 1-row cursor-tracking hack).
// - Diffing: an unchanged tree writes nothing on the second flush; a
//   modified tree repaints only its changed rows.
// - Resize: `setSize` with a new width re-lays-out the pending tree.
// - Alt screen: the buffer policy wraps instead of truncating.
//
// Expectations were derived by running the code — never hand-computed.

@Suite("Renderer Engine Path")
struct RendererEnginePathTests {

    // MARK: - Real trees through the generic write

    @Test func vstackTreeRendersThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 40, height: 24)
        await renderer.write(VStack {
            Text("Title".bold())
            Text("Body line")
            Text("Footer")
        })
        await renderer.flush()
        #expect(mock.output.contains("Title"))
        #expect(mock.output.contains("Body line"))
        #expect(mock.output.contains("Footer"))
    }

    @Test func hstackTreeRendersThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 40, height: 24)
        await renderer.write(HStack {
            Text("left")
            Text("right")
        })
        await renderer.flush()
        // Both children lay out on one row, left-to-right.
        #expect(mock.output.contains("leftright"))
    }

    @Test func treeWithControlFlowRendersThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 40, height: 24)
        let tree = VStack {
            Text("header")
            if true {
                Text("included")
            }
            for item in ["a", "b"] {
                Text(item)
            }
            Text("footer")
        }
        await renderer.write(tree)
        await renderer.flush()
        #expect(mock.output.contains("header"))
        #expect(mock.output.contains("included"))
        #expect(mock.output.contains("a"))
        #expect(mock.output.contains("b"))
        #expect(mock.output.contains("footer"))
    }

    // MARK: - Inline truncation

    @Test func inlineTruncationThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.write(VStack {
            Text("abcdefgh")
            Text("x")
        })
        await renderer.flush()
        // The over-wide first row truncates at the 5-column terminal; the
        // following logical row is NOT stolen by wrapping.
        #expect(mock.output.contains("abcde"))
        #expect(!mock.output.contains("abcdefgh"))
    }

    // MARK: - Inline suffix clamp

    @Test func suffixClampThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 80, height: 3)
        let tree = VStack {
            Text("Row 1")
            Text("Row 2")
            Text("Row 3")
            Text("Row 4")
        }
        await renderer.write(tree)
        await renderer.flush()
        // Only the LAST 3 rows appear — the engine renders the 4-row tree at
        // origin row -1, so the bottom rows land at buffer rows 0…2.
        #expect(mock.output.contains("Row 2"))
        #expect(mock.output.contains("Row 3"))
        #expect(mock.output.contains("Row 4"))
        #expect(!mock.output.contains("Row 1"))
    }

    // MARK: - Empty tree

    @Test func emptyTreeProducesNoVisibleOutput() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(VStack {
            Empty()
        })
        await renderer.flush()
        // The 1-row cursor-tracking hack renders no visible output — only
        // sync update markers may be present.
        let stripped = mock.output
            .replacingOccurrences(of: ANSI.beginSyncUpdate, with: "")
            .replacingOccurrences(of: ANSI.endSyncUpdate, with: "")
            .replacingOccurrences(of: ANSI.eraseLineRight, with: "")
            .replacingOccurrences(of: "\r", with: "")
        #expect(stripped.isEmpty)
    }

    // MARK: - Diff behavior

    @Test func unchangedEngineTreeWritesNothingOnSecondFlush() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        let tree = VStack {
            Text("Same")
            Text("Tree")
        }
        await renderer.write(tree)
        await renderer.flush()
        mock.reset()
        await renderer.write(tree)
        await renderer.flush()
        #expect(mock.output.isEmpty)
    }

    @Test func modifiedEngineTreeRepaintsChangedRows() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(VStack {
            Text("First")
            Text("row")
        })
        await renderer.flush()
        mock.reset()
        await renderer.write(VStack {
            Text("First")
            Text("CHANGED")
        })
        await renderer.flush()
        #expect(mock.output.contains("CHANGED"))
        // The unchanged first row must not be repainted.
        #expect(!mock.output.contains("First"))
    }

    // MARK: - Resize

    @Test func resizeRelayoutsTreeAtNewWidth() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 30, height: 24)
        await renderer.write(Text("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
        await renderer.flush()
        mock.reset()
        // Shrink the terminal: the next flush re-measures and re-lays-out the
        // pending tree at the new width (truncating at 5 columns).
        await renderer.setSize(width: 5, height: 24)
        await renderer.flush()
        #expect(mock.output.contains("ABCDE"))
        #expect(!mock.output.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
    }

    // MARK: - Alt screen wraps

    @Test func altScreenTreeWrapsThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.enterAltScreen()
        mock.reset()
        await renderer.write(Text("abcdefgh"))
        await renderer.flush()
        // Alt-screen buffers wrap: overflow spills onto the next buffer row.
        #expect(mock.output.contains("abcde"))
        #expect(mock.output.contains("fgh"))
    }

    // MARK: - Framed centering (M4 acceptance)

    @Test func framedTreeCentersContentInTerminal() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 20, height: 5)
        await renderer.enterAltScreen()
        mock.reset()
        // The GroceryList motivating scenario: an HStack centered in the
        // terminal via a fixed-dimension frame.
        await renderer.write(
            HStack {
                Text("ab")
                Text("cd")
            }
            .frame(
                width: 20, height: 5,
                horizontalAlignment: .center, verticalAlignment: .middle
            )
        )
        await renderer.flush()
        // The frame answers the terminal size (20×5) and places the 4-wide,
        // 1-tall stack at its alignment fractions: col 8, row 2. The mock
        // output row carries 8 leading spaces before "abcd" (followed by the
        // row's erase-line-right).
        #expect(mock.output.contains("        abcd" + ANSI.eraseLineRight))
        // Vertical centering: rows 0 and 1 are painted blank before the
        // content row — the frame's vertical padding is drawn above it.
        #expect(
            mock.output.contains(
                ANSI.eraseLineRight + "\r\n"
                    + ANSI.eraseLineRight + "\r\n"
                    + "        abcd" + ANSI.eraseLineRight
            )
        )
    }

    @Test func framedTreeReflowsOnTerminalResize() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 20, height: 5)
        await renderer.enterAltScreen()
        mock.reset()
        await renderer.write(
            HStack {
                Text("ab")
                Text("cd")
            }
            .frame(horizontalAlignment: .center, verticalAlignment: .middle)
        )
        await renderer.flush()
        // Flexible frame: fills the 20-wide offer → centered at col 8.
        #expect(mock.output.contains("        abcd"))
        mock.reset()
        // Shrink the terminal: the flexible frame re-fills the new offer and
        // re-centers (4-wide stack in 10 columns → col 3).
        await renderer.setSize(width: 10, height: 5)
        await renderer.flush()
        #expect(mock.output.contains("   abcd"))
    }
}