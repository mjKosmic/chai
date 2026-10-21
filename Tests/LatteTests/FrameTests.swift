import Testing
import Chai
import Latte

// MARK: - M4 frame() tests
//
// Milestone M4 of the phase-2 layout engine: `FrameView` + the
// `View.frame(width:height:horizontalAlignment:verticalAlignment:)` modifier.
// The frame is a proposal *generator*: fixed dimensions are proposed to the
// child and answered to the parent verbatim; flexible dimensions fill a
// non-`nil` offer and fall back to the child's ideal when the offer is `nil`.
//
// Expectations were derived by running the code (see the M4 report);
// alignment offsets pin the exact fraction math —
// `Int(Double(shortage) * fraction)` — including `Int()` truncation on odd
// shortages, mirroring the stacks' formula.
//
// `visibleRows` (from `LayoutParity/ParityHarness.swift`) is the parity
// convention: zero-width cells skipped, wide cells counted once, trailing
// spaces stripped.

// MARK: - Measurement

@Suite("Frame Measurement")
struct FrameMeasurementTests {

    @Test func bothDimsFixedAnswerExactSize() {
        let frame = Text("ab").frame(width: 10, height: 3)
        #expect(frame._sizeThatFits(.unspecified) == ViewSize(width: 10, height: 3))
        // Fixed dims answer regardless of the parent's proposal.
        #expect(
            frame._sizeThatFits(ProposedSize(width: 2, height: 1)) == ViewSize(width: 10, height: 3)
        )
    }

    @Test func widthFixedHeightFlexible() {
        let frame = Text("ab").frame(width: 10)
        // Flexible height: child ideal when the offer is nil.
        #expect(frame._sizeThatFits(.unspecified) == ViewSize(width: 10, height: 1))
        // Flexible height fills a non-nil offer; fixed width ignores the offer.
        #expect(
            frame._sizeThatFits(ProposedSize(width: 5, height: 4)) == ViewSize(width: 10, height: 4)
        )
    }

    @Test func heightFixedWidthFlexible() {
        let frame = Text("ab").frame(height: 3)
        // Flexible width: child ideal when the offer is nil.
        #expect(frame._sizeThatFits(.unspecified) == ViewSize(width: 2, height: 3))
        // Flexible width fills a non-nil offer; fixed height ignores the offer.
        #expect(
            frame._sizeThatFits(ProposedSize(width: 7, height: 1)) == ViewSize(width: 7, height: 3)
        )
    }

    @Test func neitherDimFixedPassesThrough() {
        let frame = Text("ab").frame()
        // No offer: the frame takes the child's ideal size.
        #expect(frame._sizeThatFits(.unspecified) == ViewSize(width: 2, height: 1))
        // Offer present: the frame fills it on both axes.
        #expect(
            frame._sizeThatFits(ProposedSize(width: 8, height: 5)) == ViewSize(width: 8, height: 5)
        )
    }
}

// MARK: - Placement within the frame

@Suite("Frame Placement")
struct FramePlacementTests {

    /// Render a frame view at the given proposal and buffer size, returning
    /// the visible rows (parity convention).
    private func rendered(
        _ view: some View,
        width: Int,
        height: Int
    ) -> [String] {
        var buffer = CellBuffer(width: width, height: height)
        let proposal = ProposedSize(width: width, height: height)
        let size = view._sizeThatFits(proposal)
        view._embed(into: &buffer, at: ViewRect(size: size))
        return visibleRows(buffer)
    }

    // MARK: Horizontal alignments

    @Test func leftKeepsContentFlushLeft() {
        let rows = rendered(
            Text("ab").frame(width: 6, height: 1, horizontalAlignment: .left),
            width: 6, height: 1
        )
        #expect(rows == ["ab"])
    }

    @Test func centerPlacesContentAtHalfShortage() {
        // Shortage 4, fraction 0.5 → Int(2.0) = 2.
        let rows = rendered(
            Text("ab").frame(width: 6, height: 1, horizontalAlignment: .center),
            width: 6, height: 1
        )
        #expect(rows == ["  ab"])
    }

    @Test func centerTruncatesOddShortage() {
        // Shortage 3, fraction 0.5 → Int(1.5) = 1 (truncation, not rounding).
        let rows = rendered(
            Text("ab").frame(width: 5, height: 1, horizontalAlignment: .center),
            width: 5, height: 1
        )
        #expect(rows == [" ab"])
    }

    @Test func rightPlacesContentAtFullShortage() {
        // Shortage 4, fraction 1.0 → offset 4.
        let rows = rendered(
            Text("ab").frame(width: 6, height: 1, horizontalAlignment: .right),
            width: 6, height: 1
        )
        #expect(rows == ["    ab"])
    }

    @Test func fractionalAlignmentPlacesProportionally() {
        // Shortage 6, fraction 0.25 → Int(1.5) = 1.
        let rows = rendered(
            Text("ab").frame(width: 8, height: 1, horizontalAlignment: HorizontalAlignment(fraction: 0.25)),
            width: 8, height: 1
        )
        #expect(rows == [" ab"])
    }

    // MARK: Vertical alignments

    @Test func topKeepsContentFlushTop() {
        let rows = rendered(
            Text("a\nb").frame(height: 4, verticalAlignment: .top),
            width: 1, height: 4
        )
        #expect(rows == ["a", "b", "", ""])
    }

    @Test func middlePlacesContentAtHalfShortage() {
        // Shortage 2, fraction 0.5 → Int(1.0) = 1.
        let rows = rendered(
            Text("a\nb").frame(height: 4, verticalAlignment: .middle),
            width: 1, height: 4
        )
        #expect(rows == ["", "a", "b", ""])
    }

    @Test func middleTruncatesOddShortage() {
        // Shortage 1, fraction 0.5 → Int(0.5) = 0 (truncation, not rounding).
        let rows = rendered(
            Text("a\nb").frame(height: 3, verticalAlignment: .middle),
            width: 1, height: 3
        )
        #expect(rows == ["a", "b", ""])
    }

    @Test func bottomPlacesContentAtFullShortage() {
        // Shortage 2, fraction 1.0 → offset 2.
        let rows = rendered(
            Text("a\nb").frame(height: 4, verticalAlignment: .bottom),
            width: 1, height: 4
        )
        #expect(rows == ["", "", "a", "b"])
    }

    // MARK: Both axes at once

    @Test func centerMiddlePlacesContentInBothAxes() {
        let rows = rendered(
            Text("ab").frame(
                width: 8, height: 3,
                horizontalAlignment: .center, verticalAlignment: .middle
            ),
            width: 8, height: 3
        )
        // Width: shortage 6 → col 3. Height: shortage 2 → row 1 (odd
        // remainder below — same as `enforceHeight`).
        #expect(rows == ["", "   ab", ""])
    }
}

// MARK: - Overflow (no clipping — pinned decision)

@Suite("Frame Overflow")
struct FrameOverflowTests {

    /// A non-wrapping raster leaf: its `body` is a `ViewOutput`, so its
    /// measured and rendered size ignores the frame's width proposal — exactly
    /// the pre-A1 `Text` behavior. Used to pin the frame's no-clip semantics
    /// independently of A1's proposal-consuming `Text`, which wraps its
    /// content to the frame's fixed width and therefore no longer overflows
    /// horizontally (see `textWrapsToFrameWidthInsteadOfOverflowing` below).
    private struct Raster: View {
        let content: String
        init(_ content: String) { self.content = content }
        var body: ViewOutput { ViewOutput(content) }
    }

    @Test func childLargerThanFrameOverflowsBounds() {
        // Frame is 2×1 around a 4×2 NON-WRAPPING child. The buffer is 4×2 —
        // larger than the frame — so the overflow is visible: content extends
        // past the frame's assigned bounds in both axes.
        var buffer = CellBuffer(width: 4, height: 2)
        let frame = Raster("abcd\nef").frame(width: 2, height: 1)
        let size = frame._sizeThatFits(ProposedSize(width: 2, height: 1))
        #expect(size == ViewSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))

        // Shortage is clamped: the child renders from offset 0.
        #expect(buffer[0, 0].character == "a")
        // Content beyond the frame's width (2 columns):
        #expect(buffer[3, 0].character == "d")
        // Content beyond the frame's height (1 row):
        #expect(buffer[0, 1].character == "e")
        #expect(visibleRows(buffer) == ["abcd", "ef"])
    }

    @Test func overflowIsClippedOnlyAtBufferWidth() {
        // A buffer the size of the frame truncates the overflowing content
        // at the buffer edge — the buffer is the final backstop, not the
        // frame.
        let frame = Raster("abcd\nef").frame(width: 2, height: 1)
        var buffer = CellBuffer(width: 2, height: 1)
        let size = frame._sizeThatFits(ProposedSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        #expect(visibleRows(buffer) == ["ab"])
    }

    @Test func overflowCenteredStillClampsShortageToZero() {
        // A larger child under a non-zero alignment: shortage clamps to 0,
        // so the child still renders from the alignment offset of the
        // available (zero) shortage — column 0.
        var buffer = CellBuffer(width: 4, height: 2)
        let frame = Raster("abcd\nef").frame(width: 2, height: 1, horizontalAlignment: .right)
        let size = frame._sizeThatFits(ProposedSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        #expect(buffer[0, 0].character == "a")
        #expect(visibleRows(buffer) == ["abcd", "ef"])
    }

    @Test func textWrapsToFrameWidthInsteadOfOverflowing() {
        // A1 spec delta: `Text` is now a proposal consumer, so a fixed-width
        // frame WRAPS its text child to the frame's width instead of letting
        // it overflow horizontally (the char-level fallback guarantees the
        // wrapped content fits any positive width). The frame still does not
        // clip, so the vertical overflow remains: the frame answers 2×1 but
        // the wrapped child is 2 columns × 3 rows.
        var buffer = CellBuffer(width: 4, height: 3)
        let frame = Text("abcd\nef").frame(width: 2, height: 1)
        let size = frame._sizeThatFits(ProposedSize(width: 2, height: 1))
        #expect(size == ViewSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        // "abcd" wraps to "ab"/"cd"; "ef" stays; all three rows land below the
        // 1-tall frame's bounds (no clipping).
        #expect(visibleRows(buffer) == ["ab", "cd", "ef"])
    }
}

// MARK: - Nesting

@Suite("Frame Nesting")
struct FrameNestingTests {

    @Test func fixedHeightFrameInsideVStackContributesExactlyItsRows() {
        let buffer = embedBuffer(
            VStack {
                Text("a").frame(width: 5, height: 2, horizontalAlignment: .center)
                Text("b")
            },
            width: 5
        )
        // The frame occupies rows 0–1 (fixed height 2): "a" centered within
        // its 5-column frame, one blank row, then "b" on row 2.
        #expect(visibleRows(buffer) == ["  a", "", "b"])
    }

    @Test func frameAroundHStackWithForLoop() {
        let buffer = embedBuffer(
            HStack {
                for item in ["a", "b", "c"] {
                    Text(item)
                }
            }
            .frame(width: 7, height: 1, horizontalAlignment: .right),
            width: 7
        )
        // The HStack measures 3 wide; shortage 4 → col 4.
        #expect(visibleRows(buffer) == ["    abc"])
    }

    @Test func frameOfFrame() {
        let buffer = embedBuffer(
            Text("x")
                .frame(width: 5, height: 1, horizontalAlignment: .center)
                .frame(width: 9, height: 3, horizontalAlignment: .right, verticalAlignment: .middle),
            width: 9
        )
        // Outer frame 9×3: inner frame (5×1) sits at col 4 (right), row 1
        // (middle). Inner frame centers "x" in its 5 columns → col 4 + 2 = 6.
        #expect(visibleRows(buffer) == ["", "      x", ""])
    }
}

// MARK: - Legacy body (eager path)

@Suite("Frame Legacy Body")
struct FrameLegacyBodyTests {

    @Test func fixedBothEqualsWidthThenHeightComposition() {
        let framed = Text("ab")
            .frame(width: 6, height: 2, horizontalAlignment: .center, verticalAlignment: .middle)
            ._resolveToViewOutput()
        let composed = ViewOutput("ab")
            .width(6, align: .center)
            .height(2, align: .middle)
        #expect(framed.content.plainText == composed.content.plainText)
    }

    @Test func fixedWidthOnlyAppliesWidthModifier() {
        let framed = Text("ab")
            .frame(width: 6, horizontalAlignment: .right)
            ._resolveToViewOutput()
        #expect(framed.content.plainText == "    ab")
    }

    @Test func fixedHeightOnlyAppliesHeightModifier() {
        let framed = Text("a\nb")
            .frame(height: 4, verticalAlignment: .bottom)
            ._resolveToViewOutput()
        // `enforceHeight` pads with blank lines of the content's width (1):
        // " \n \na\nb".
        #expect(framed.content.plainText == " \n \na\nb")
    }

    @Test func noFixedDimsResolvesPlain() {
        let framed = Text("ab").frame()._resolveToViewOutput()
        #expect(framed.content.plainText == "ab")
    }
}

// MARK: - Degenerate sizes

@Suite("Frame Degenerate Sizes")
struct FrameDegenerateTests {

    @Test func zeroWidthFrameCompressesTextToMinimumAndOverflows() {
        var buffer = CellBuffer(width: 4, height: 1)
        let frame = Text("abcd").frame(width: 0)
        let size = frame._sizeThatFits(.unspecified)
        // Fixed width 0 answers 0. A3: the frame's fixed 0 width reaches the
        // `Text` child as its proposal, so the child answers its MINIMUM (1
        // wide, 4 rows — one character per row); the flexible height then
        // forwards the child's ideal height, 4.
        #expect(size == ViewSize(width: 0, height: 4))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        // No clipping: the 1-wide child renders past the 0-wide frame's bounds
        // (col 0), clipped only at the 4-wide buffer. Only the first row lands
        // (the buffer is 1 tall).
        #expect(buffer[0, 0].character == "a")
        #expect(buffer[1, 0] == .empty)
        #expect(buffer[3, 0] == .empty)
    }

    @Test func zeroHeightFrameDoesNotCrashAndOverflows() {
        var buffer = CellBuffer(width: 4, height: 1)
        let frame = Text("abcd").frame(height: 0)
        let size = frame._sizeThatFits(.unspecified)
        #expect(size == ViewSize(width: 4, height: 0))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        // The child renders at row 0 (shortage clamped), clipped only at the
        // buffer.
        #expect(buffer[0, 0].character == "a")
        #expect(buffer[3, 0].character == "d")
    }
}

// MARK: - Allocation assignment (phase 4)

@Suite("Frame Allocation Assignment")
struct FrameAllocationAssignmentTests {

    @Test func flexibleAxisFramePassesTheAssignedWidthToChild() {
        // FrameView(width: nil) in an 8-column root rect: the flexible axis
        // passes the assigned 8 through, so the echo is allocated 8.
        let buffer = embedBuffer(
            FrameView(width: nil) {
                RectEchoView()
            },
            width: 8
        )
        #expect(visibleRows(buffer) == ["W:8"])
    }

    @Test func fixedAxisFrameAllocatesItsFixedWidthToChild() {
        // A fixed-width frame allocates its fixed width regardless of the
        // incoming assignment.
        let buffer = embedBuffer(
            FrameView(width: 4) {
                RectEchoView()
            },
            width: 8
        )
        #expect(visibleRows(buffer) == ["W:4"])
    }
}
