import Testing
import Chai
import Latte

// MARK: - Phase-4 allocation rules (containers)
//
// The per-conformer allocation rules of P1 (UPGRADE.md, "Phase 4 —
// Architecture"): stacks, frames and clips decide; children report. These are
// the spike's five probes turned into assertions (`TOP-DOWN-SPIKE.md` §3) plus
// the rules that the corpus cannot express.
//
// `visibleRows` (from `LayoutParity/ParityHarness.swift`) is the parity
// convention: zero-width cells skipped, wide cells counted once, trailing
// spaces stripped. Expectations were derived by running the code.

/// A view that reports a fixed width and paints the width it was allocated.
/// Used to observe the stack's clamping independently of `Text`'s wrapping.
private struct WidthProbe: View {
    let reported: Int

    func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: reported, height: 1)
    }

    func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        buffer.write(
            StyledText("W:\(rect.size.width)"),
            at: rect.origin.col,
            row: rect.origin.row
        )
    }
}

@Suite("Phase-4 allocation rules")
struct AllocationRulesTests {

    private func embed(_ view: some View, width: Int, height: Int) -> [String] {
        var buffer = CellBuffer(width: width, height: height)
        buffer.embed(
            view,
            at: ViewRect(size: ViewSize(width: width, height: height))
        )
        return visibleRows(buffer)
    }

    // MARK: Stack occupancy (decision 1: shrink-wrap)

    @Test func vstackOccupiesMaxChildWidthNotTheAssignedWidth() {
        let tree = VStack(alignment: .right) {
            Text("ab")
            Text("c")
        }
        // Occupied width 2, so "c" is right-aligned to col 1 — NOT col 7.
        #expect(embed(tree, width: 8, height: 2) == ["ab", " c"])
    }

    @Test func vstackStretchesFlexibleRowsToTheAssignedHeight() {
        let tree = VStack(alignment: .right) {
            Text("ab")
            Spacer()
        }
        // Rigid total 1, assigned height 6 → the spacer absorbs the 5-row
        // leftover. The stack still shrink-wraps to width 2.
        #expect(embed(tree, width: 8, height: 6) == ["ab", "", "", "", "", ""])
    }

    @Test func vstackRigidContentDoesNotStretch() {
        let tree = VStack {
            Text("a")
            Text("b")
        }
        #expect(embed(tree, width: 8, height: 5) == ["a", "b", "", "", ""])
    }

    @Test func vstackClampsAnOverflowingRowToItsAllocation() {
        let tree = VStack {
            ViewOutput("abcd")
            Text("e")
        }
        // The raster reports 4 wide; the stack allocates row 0
        // min(4, rect.width) = 2 columns, so the kernel clip drops "cd".
        // Row 1 still starts at row 1 — nothing compresses.
        #expect(embed(tree, width: 2, height: 2) == ["ab", "e"])
    }

    @Test func vstackDropsRowsBeyondItsAllocation() {
        let tree = VStack {
            Text("a")
            Text("b")
            Text("c")
        }
        .frame(height: 2)
        // The frame's box is 2 rows tall; the stack clamps each child row to
        // the remaining allocation, so "c" gets no rect at all.
        #expect(embed(tree, width: 3, height: 3) == ["a", "b", ""])
    }

    // MARK: HStack columns (ideal-width measurement)

    @Test func hstackColumnsMeasureAtIdealWidth() {
        let tree = HStack {
            Text("aaaaaa")
            Text("bb")
        }
        // The assignment is 4 columns, but columns keep ideal widths (6 + 2):
        // no wrapping; the paint is clipped to the assignment.
        #expect(
            tree._measure(in: AvailableSize(width: 4, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(embed(tree, width: 4, height: 1) == ["aaaa"])
    }

    @Test func hstackWideCharactersAreClippedAtTheAllocation() {
        let tree = HStack {
            Text("你")
            Text("好")
        }
        // Columns keep their 2-column intrinsic widths; the second column is
        // clamped to the remaining 1 column, where the 2-wide glyph cannot
        // fit and is dropped by the clip.
        #expect(embed(tree, width: 3, height: 1) == ["你"])
    }

    @Test func hstackClampsAColumnToTheRemainingAllocation() {
        let tree = HStack {
            WidthProbe(reported: 6)
            Text("b")
        }
        // The first column reports 6 but the assignment is 3; the stack
        // allocates it 3 columns and leaves nothing for the second.
        #expect(embed(tree, width: 3, height: 1) == ["W:3"])
    }

    // MARK: Fill (decision 2: a consumer that claims its allocated rect)

    @Test func leadingFillClaimsTheRemainder() {
        let tree = HStack {
            Fill()
            Text("x")
        }
        // `Fill` claims columns 0–6; "x" moves to col 7. This is the occupied-
        // width delta pinned by the corpus (`PHASE-4 DELTA` case) and by
        // UPGRADE.md ("Phase 4 — allocation deltas").
        #expect(
            tree._measure(in: AvailableSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(embed(tree, width: 8, height: 1) == ["       x"])
    }

    @Test func trailingFillDoesNotShiftTheSibling() {
        let tree = HStack {
            Text("x")
            Fill()
        }
        #expect(embed(tree, width: 8, height: 1) == ["x"])
        // ...but the trailing `Fill` still grows the stack's OCCUPIED width
        // (1 → 8), which is visible to parent alignment math. Documented in
        // UPGRADE.md ("Phase 4 — allocation deltas") and pinned by the corpus
        // case "PHASE-4 DELTA: trailing Fill grows the stack's occupied width".
        #expect(
            tree._measure(in: AvailableSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
        )
    }

    @Test func multipleFillsSplitTheRemainderEvenly() {
        let tree = HStack {
            Fill()
            Fill()
            Text("z")
        }
        // Unassigned = 9 − 1 = 8 → 4 columns per fill; "z" at col 8.
        #expect(embed(tree, width: 9, height: 1) == ["        z"])
    }

    @Test func multipleFillsDropTheOddRemainder() {
        let tree = HStack {
            Fill()
            Fill()
            Text("z")
        }
        // Unassigned 9 → Int(9/2) = 4 per fill; the odd column is left
        // unallocated at the trailing end (the same convention as flexible
        // shares), so the occupied width is 9, not the assigned 10.
        #expect(
            tree._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 9, height: 1)
        )
        #expect(embed(tree, width: 10, height: 1) == ["        z"])
    }

    @Test func flexibleSiblingsTakePriorityOverFill() {
        let tree = HStack {
            Text("A")
            Spacer()
            Fill()
            Text("B")
        }
        // The flexible share absorbs the whole leftover (8), leaving the
        // `Fill` nothing to claim: order is flex shares first, then Fill.
        #expect(
            tree._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 10, height: 1)
        )
        #expect(embed(tree, width: 10, height: 1) == ["A        B"])
    }

    // MARK: Flex shares (A2 math, container-internal)

    @Test func flexibleSpacersShareTheAssignedLeftover() {
        let tree = HStack {
            Spacer()
            Text("mid")
            Spacer()
        }
        // Rigid 3, leftover 17 → 8 columns per spacer; "mid" at col 8.
        #expect(embed(tree, width: 20, height: 1) == ["        mid"])
    }

    @Test func trailingRemainderStaysUnallocated() {
        let tree = HStack {
            Text("A")
            Spacer()
            Text("B")
            Spacer()
            Text("C")
        }
        var buffer = CellBuffer(width: 10, height: 1)
        tree._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 10, height: 1)))
        #expect(visibleRows(buffer) == ["A   B   C"])
        #expect(buffer[8, 0].character == "C")
        #expect(buffer[9, 0] == .empty)
    }

    @Test func narrowFrameCannotShowTheMinimumTextForm() {
        let tree = Text("ab你").frame(width: 1)
        // The frame answers width 1; the hard-box contract clips the Text's
        // minimum form (2 wide) to the 1-column box. Row 0 shows "a" only;
        // the wide character cannot fit in one column and is dropped.
        #expect(tree._measure(in: .unconstrained) == ViewSize(width: 1, height: 2))
        #expect(embed(tree, width: 2, height: 2) == ["a", ""])
    }

    // MARK: Frame (fixed dims are allocations)

    @Test func fixedFrameDimsAreAllocations() {
        let tree = Text("ab")
            .frame(width: 8, height: 3, horizontalAlignment: .center, verticalAlignment: .middle)
        #expect(embed(tree, width: 8, height: 3) == ["", "   ab", ""])
    }

    @Test func flexibleFrameFillsTheAssignedRect() {
        let tree = Text("ab")
            .frame(horizontalAlignment: .center)
        #expect(
            tree._measure(in: AvailableSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(embed(tree, width: 8, height: 1) == ["   ab"])
    }

    @Test func frameWithAFlexibleChildStretchesIt() {
        let tree = VStack {
            Text("t")
            Spacer()
        }
        .frame(width: 4, height: 5)
        // The frame's fixed height reaches the height-flexible child through
        // the query context; the spacer stretches to fill rows 1–4.
        #expect(embed(tree, width: 4, height: 5) == ["t", "", "", "", ""])
    }

    @Test func frameClipsOverflow() {
        let tree = ViewOutput("abcd")
            .frame(width: 2)
        // The frame occupies 2 columns; the 4-wide raster is clipped to it.
        #expect(embed(tree, width: 4, height: 1) == ["ab"])
    }

    // MARK: Structural roots

    @Test func structuralRootEmbedsChildrenVertically() {
        let tree = TupleView(Text("a"), Text("b"))
        #expect(embed(tree, width: 4, height: 2) == ["a", "b"])
    }

    @Test func forEachRootEmbedsChildrenVertically() {
        let tree = ForEachView([Text("a"), Text("b")])
        #expect(embed(tree, width: 4, height: 2) == ["a", "b"])
    }

    @Test func optionalBranchEmbedsItsContent() {
        let tree = OptionalView(Text("only"))
        #expect(embed(tree, width: 4, height: 1) == ["only"])
    }
}
