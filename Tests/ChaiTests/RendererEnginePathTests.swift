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
// - Inline truncation vs wrapping (A1): a proposal-consuming `Text` root
//   WRAPS at the terminal width, while a non-wrapping `ViewOutput` root
//   truncates at it — the two cases pin the proposal-consumer boundary.
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

    // MARK: - Fit/render proposal consistency (A0)

    @Test func proposalEchoSeesFitProposalAtRootRender() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 20, height: 24)
        await renderer.write(VStack {
            ProposalEchoView()
            Text("hi")
        })
        await renderer.flush()
        // The echo measures min(20, 12) = 12 wide, so the stack measures
        // 12×2 — narrower than the 20-column terminal. The echo's render-time
        // proposal must be the FIT proposal (terminal width 20), not its
        // assigned size (12). Pre-A0 this rendered "W:12" — the value-level
        // gap at the renderer root that the proposal-carrying `_render`
        // closes.
        #expect(mock.output.contains("W:20"))
    }

    // MARK: - Inline wrapping vs truncation (A1 proposal-consumer boundary)

    @Test func inlineTextWrapsThroughEngine() async {
        // A1 spec delta: `Text` is a proposal consumer, so the over-wide first
        // row now WRAPS at the 5-column terminal instead of being truncated.
        // The engine measures the root VStack at the terminal proposal, the
        // `Text("abcdefgh")` child wraps to "abcde"/"fgh", and the buffer is
        // sized to the wrapped height (3 rows). The inline truncate policy is
        // still in force — it is simply no longer reached, because the wrapped
        // content fits (see `inlineViewOutputTruncatesThroughEngine`).
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.write(VStack {
            Text("abcdefgh")
            Text("x")
        })
        await renderer.flush()
        #expect(mock.output.contains("abcde"))
        #expect(mock.output.contains("fgh"))
        #expect(mock.output.contains("x"))
        #expect(!mock.output.contains("abcdefgh"))
    }

    @Test func inlineViewOutputTruncatesThroughEngine() async {
        // The non-wrapping contrast at the same terminal: `ViewOutput` stays a
        // raster leaf that ignores proposals (the pinned A1 decision), so the
        // over-wide first row truncates and the following logical row is NOT
        // stolen by wrapping.
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.write(VStack {
            ViewOutput("abcdefgh")
            ViewOutput("x")
        })
        await renderer.flush()
        #expect(mock.output.contains("abcde"))
        #expect(mock.output.contains("x"))
        #expect(!mock.output.contains("fgh"))
        #expect(!mock.output.contains("abcdefgh"))
    }

    @Test func rootTextWrapsThroughEngine() async {
        // Root `Text` at a narrow terminal: the renderer's fit proposal is the
        // terminal width, and the root Text wraps into rows.
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.write(Text("abcdefgh"))
        await renderer.flush()
        #expect(mock.output.contains("abcde"))
        #expect(mock.output.contains("fgh"))
    }

    @Test func rootViewOutputTruncatesThroughEngine() async {
        // Root `ViewOutput` at the same narrow terminal: ignored proposal →
        // one truncated row, no "fgh".
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.write(ViewOutput("abcdefgh"))
        await renderer.flush()
        #expect(mock.output.contains("abcde"))
        #expect(!mock.output.contains("fgh"))
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
        // pending tree at the new width. A1: the root `Text` wraps to
        // 5-column rows instead of truncating.
        await renderer.setSize(width: 5, height: 24)
        await renderer.flush()
        #expect(mock.output.contains("ABCDE"))
        #expect(mock.output.contains("FGHIJ"))
        #expect(!mock.output.contains("ABCDEFGHIJKLMNOPQRSTUVWXYZ"))
    }

    // MARK: - Alt screen wraps

    @Test func altScreenTreeWrapsThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 5, height: 24)
        await renderer.enterAltScreen()
        mock.reset()
        // A non-wrapping child, so the overflow actually reaches the buffer:
        // `Text` would wrap itself at the terminal proposal (A1) and never
        // exercise the alt-screen buffer policy.
        await renderer.write(ViewOutput("abcdefgh"))
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

    // MARK: - Fill claims offered space (A2)

    @Test func fillClaimsOfferedHeightThroughEngine() async {
        // `Fill` answers the proposal, so the HStack is as tall as the frame's
        // 3-row offer (1×3). The bottom-aligned frame then has no vertical
        // shortage and places the stack at the TOP — "x" is painted on row 0
        // and rows 1–2 are painted blank (the space `Fill` claimed).
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 10, height: 3)
        await renderer.write(
            HStack {
                Fill()
                Text("x")
            }
            .frame(width: 4, height: 3, verticalAlignment: .bottom)
        )
        await renderer.flush()
        #expect(
            mock.output.contains(
                "x" + ANSI.eraseLineRight + "\r\n"
                    + ANSI.eraseLineRight + "\r\n"
                    + ANSI.eraseLineRight
            )
        )

        // Contrast: without `Fill` the stack is 1 row tall, so the same
        // bottom-aligned frame places "x" on the LAST row instead.
        let contrast = MockTerminal()
        let contrastRenderer = Renderer(terminal: contrast)
        await contrastRenderer.setSize(width: 10, height: 3)
        await contrastRenderer.write(
            HStack {
                Text("x")
            }
            .frame(width: 4, height: 3, verticalAlignment: .bottom)
        )
        await contrastRenderer.flush()
        #expect(
            contrast.output.contains(
                ANSI.eraseLineRight + "\r\n"
                    + ANSI.eraseLineRight + "\r\n"
                    + "x" + ANSI.eraseLineRight
            )
        )
    }

    // MARK: - Clipped trees (A3)

    @Test func clippedTreeShowsClippedRowsThroughEngine() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.setSize(width: 8, height: 4)
        await renderer.enterAltScreen()
        mock.reset()
        // The frame answers width 3; the clip masks the 6-wide raster to
        // "abc". The eager path would show "abcdef" (no clipping).
        await renderer.write(
            ViewOutput("abcdef").frame(width: 3).clipped()
        )
        await renderer.flush()
        #expect(mock.output.contains("abc" + ANSI.eraseLineRight))
        #expect(!mock.output.contains("abcdef"))
        #expect(!mock.output.contains("abcd"))
    }

    @Test func zeroProbedTextIsMeasuredCorrectly() async {
        // The renderer root never offers zero — it proposes the terminal
        // width — so `.zero` is a unit-level measurement pin (see
        // `ProposedSizeZeroTests`). Kept here as the renderer-path counterpart
        // so the A3 minimum semantics are pinned on both surfaces.
        #expect(Text("abcd")._sizeThatFits(.zero) == ViewSize(width: 1, height: 4))
    }
}
