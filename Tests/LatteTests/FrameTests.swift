import Testing
import Chai
import Latte

// MARK: - M4 frame() tests
//
// Milestone M4 of the phase-2 layout engine: `FrameView` + the
// `View.frame(width:height:horizontalAlignment:verticalAlignment:)` modifier.
// The frame is an allocator: fixed dimensions are assigned to the
// child and owned verbatim; flexible dimensions pass the parent's
// assignment through, falling back to the child's report when there is none.
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
        #expect(frame._measure(in: .unconstrained) == ViewSize(width: 10, height: 3))
        // Fixed dims answer regardless of the parent's query context.
        #expect(
            frame._measure(in: AvailableSize(width: 2, height: 1)) == ViewSize(width: 10, height: 3)
        )
    }

    @Test func negativeFixedDimensionsClampToZero() {
        // Negative fixed dimensions are not meaningful; they clamp at init so
        // a frame cannot report (and a parent cannot propagate) a negative
        // size. Spacer counts and padding insets clamp the same way.
        let frame = Text("ab").frame(width: -3, height: -2)
        #expect(frame._measure(in: .unconstrained) == ViewSize(width: 0, height: 0))
    }

    @Test func widthFixedHeightFlexible() {
        let frame = Text("ab").frame(width: 10)
        // Flexible height: child ideal when the query is unconstrained.
        #expect(frame._measure(in: .unconstrained) == ViewSize(width: 10, height: 1))
        // Flexible height fills a non-nil assignment; fixed width ignores the query.
        #expect(
            frame._measure(in: AvailableSize(width: 5, height: 4)) == ViewSize(width: 10, height: 4)
        )
    }

    @Test func heightFixedWidthFlexible() {
        let frame = Text("ab").frame(height: 3)
        // Flexible width: child ideal when the query is unconstrained.
        #expect(frame._measure(in: .unconstrained) == ViewSize(width: 2, height: 3))
        // Flexible width fills a non-nil assignment; fixed height ignores the query.
        #expect(
            frame._measure(in: AvailableSize(width: 7, height: 1)) == ViewSize(width: 7, height: 3)
        )
    }

    @Test func neitherDimFixedPassesThrough() {
        let frame = Text("ab").frame()
        // No assignment (unconstrained query): the frame takes the child's ideal size.
        #expect(frame._measure(in: .unconstrained) == ViewSize(width: 2, height: 1))
        // Offer present: the frame fills it on both axes.
        #expect(
            frame._measure(in: AvailableSize(width: 8, height: 5)) == ViewSize(width: 8, height: 5)
        )
    }
}

// MARK: - Placement within the frame

@Suite("Frame Placement")
struct FramePlacementTests {

    /// Render a frame view at the given query context and buffer size, returning
    /// the visible rows (parity convention).
    private func rendered(
        _ view: some View,
        width: Int,
        height: Int
    ) -> [String] {
        var buffer = CellBuffer(width: width, height: height)
        let available = AvailableSize(width: width, height: height)
        let size = view._measure(in: available)
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

// MARK: - Overflow (clipped by the hard box)

@Suite("Frame Overflow")
struct FrameOverflowTests {

    /// A non-wrapping raster leaf: its `body` is a `ViewOutput`, so its
    /// measured and rendered size ignores the frame's width query — exactly
    /// the pre-A1 `Text` behavior. Used to pin the frame's clipping semantics
    /// independently of A1's query-consuming `Text`, which wraps its
    /// content to the frame's fixed width and therefore no longer overflows
    /// horizontally (see `textWrapsAtFrameWidthAndClipsHeight` below).
    private struct Raster: View {
        let content: String
        init(_ content: String) { self.content = content }
        var body: ViewOutput { ViewOutput(content) }
    }

    @Test func childLargerThanFrameIsClipped() {
        // Frame is 2×1 around a 4×2 non-wrapping child. The hard-box contract
        // clips the child to the frame's box: only "ab" on row 0 survives.
        var buffer = CellBuffer(width: 4, height: 2)
        let frame = Raster("abcd\nef").frame(width: 2, height: 1)
        let size = frame._measure(in: AvailableSize(width: 2, height: 1))
        #expect(size == ViewSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))

        #expect(buffer[0, 0].character == "a")
        #expect(buffer[1, 0].character == "b")
        // Content beyond the frame's box is clipped.
        #expect(buffer[2, 0] == .empty)
        #expect(buffer[0, 1] == .empty)
        #expect(visibleRows(buffer) == ["ab", ""])
    }

    @Test func frameClipsAtItsOwnBoxNotTheBuffer() {
        // The buffer is larger than the frame; the frame still clips.
        let frame = Raster("abcd\nef").frame(width: 2, height: 1)
        var buffer = CellBuffer(width: 2, height: 1)
        let size = frame._measure(in: AvailableSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        #expect(visibleRows(buffer) == ["ab"])
    }

    @Test func overflowCenteredIsClippedAtTheBox() {
        // A larger child under a non-zero alignment: the shortage clamps to
        // 0, so the child starts at the box origin and is clipped to it.
        var buffer = CellBuffer(width: 4, height: 2)
        let frame = Raster("abcd\nef").frame(width: 2, height: 1, horizontalAlignment: .right)
        let size = frame._measure(in: AvailableSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        #expect(buffer[0, 0].character == "a")
        #expect(visibleRows(buffer) == ["ab", ""])
    }

    @Test func textWrapsAtFrameWidthAndClipsHeight() {
        // A fixed-width frame wraps its text child to the frame's width; the
        // hard-box contract then clips the wrapped rows to the frame's height.
        // A 1-row frame with long content shows the first wrapped line.
        var buffer = CellBuffer(width: 4, height: 3)
        let frame = Text("abcd\nef").frame(width: 2, height: 1)
        let size = frame._measure(in: AvailableSize(width: 2, height: 1))
        #expect(size == ViewSize(width: 2, height: 1))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        // "abcd" wraps to "ab"/"cd"; "ef" would be a third row, but only the
        // first row fits the 1-tall box.
        #expect(visibleRows(buffer) == ["ab", "", ""])
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

// MARK: - Degenerate sizes

@Suite("Frame Degenerate Sizes")
struct FrameDegenerateTests {

    @Test func zeroWidthFramePaintsNothing() {
        var buffer = CellBuffer(width: 4, height: 1)
        let frame = Text("abcd").frame(width: 0)
        let size = frame._measure(in: .unconstrained)
        // Fixed width 0 answers 0; the Text child's minimum form (1 wide,
        // 4 rows) sets the flexible height.
        #expect(size == ViewSize(width: 0, height: 4))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        // A zero-width box has no painting area: nothing lands in the buffer.
        #expect(visibleRows(buffer) == [""])
    }

    @Test func zeroHeightFramePaintsNothing() {
        var buffer = CellBuffer(width: 4, height: 1)
        let frame = Text("abcd").frame(height: 0)
        let size = frame._measure(in: .unconstrained)
        #expect(size == ViewSize(width: 4, height: 0))
        frame._embed(into: &buffer, at: ViewRect(size: size))
        // A zero-height box has no painting area.
        #expect(visibleRows(buffer) == [""])
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
