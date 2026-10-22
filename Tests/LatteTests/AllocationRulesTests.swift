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

@Suite("Phase-4 allocation rules")
struct AllocationRulesTests {

    private func embed(_ view: some View, width: Int, height: Int) -> [String] {
        var buffer = CellBuffer(width: width, height: height)
        view._embed(
            into: &buffer,
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
            FlexibleSpacer()
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

    @Test func vstackDoesNotCompressAnOverflowingRow() {
        let tree = VStack {
            ViewOutput("abcd")
            Text("e")
        }
        // The raster reports 4 wide; the stack allocates row 0 four columns
        // (the buffer truncates at the buffer edge) and row 1 still starts at
        // row 1 — nothing compresses.
        #expect(embed(tree, width: 2, height: 2) == ["ab", "e"])
    }

    // MARK: HStack columns (ideal-width measurement)

    @Test func hstackColumnsMeasureAtIdealWidth() {
        let tree = HStack {
            Text("aaaaaa")
            Text("bb")
        }
        // The assignment is 4 columns, but columns keep ideal widths (6 + 2):
        // no wrapping, overflow stays visual.
        #expect(
            tree._sizeThatFits(ProposedSize(width: 4, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(embed(tree, width: 4, height: 1) == ["aaaa"])
    }

    @Test func hstackWideCharactersOverflowTheBufferEdge() {
        let tree = HStack {
            Text("你")
            Text("好")
        }
        // Columns keep their 2-column intrinsic widths; the second wide
        // character does not fit the 3-column buffer and is dropped there.
        #expect(embed(tree, width: 3, height: 1) == ["你"])
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
            tree._sizeThatFits(ProposedSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
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
            tree._sizeThatFits(ProposedSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
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
            tree._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 9, height: 1)
        )
        #expect(embed(tree, width: 10, height: 1) == ["        z"])
    }

    @Test func flexibleSiblingsTakePriorityOverFill() {
        let tree = HStack {
            Text("A")
            FlexibleSpacer()
            Fill()
            Text("B")
        }
        // The flexible share absorbs the whole leftover (8), leaving the
        // `Fill` nothing to claim: order is flex shares first, then Fill.
        #expect(
            tree._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 10, height: 1)
        )
        #expect(embed(tree, width: 10, height: 1) == ["A        B"])
    }

    // MARK: Flex shares (A2 math, container-internal)

    @Test func flexibleSpacersShareTheAssignedLeftover() {
        let tree = HStack {
            FlexibleSpacer()
            Text("mid")
            FlexibleSpacer()
        }
        // Rigid 3, leftover 17 → 8 columns per spacer; "mid" at col 8.
        #expect(embed(tree, width: 20, height: 1) == ["        mid"])
    }

    @Test func trailingRemainderStaysUnallocated() {
        let tree = HStack {
            Text("A")
            FlexibleSpacer()
            Text("B")
            FlexibleSpacer()
            Text("C")
        }
        var buffer = CellBuffer(width: 10, height: 1)
        tree._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 10, height: 1)))
        #expect(visibleRows(buffer) == ["A   B   C"])
        #expect(buffer[8, 0].character == "C")
        #expect(buffer[9, 0] == .empty)
    }

    @Test func narrowFrameAllocatesTheMinimumTextForm() {
        let tree = Text("ab你").frame(width: 1)
        // The frame answers width 1, but the `Text`'s report (2 wide, 2 rows)
        // is its minimum form; the allocation paints exactly those two rows —
        // no stray blank row from a differently-measured report.
        #expect(tree._sizeThatFits(.unspecified) == ViewSize(width: 1, height: 2))
        #expect(embed(tree, width: 2, height: 2) == ["ab", "你"])
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
            tree._sizeThatFits(ProposedSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(embed(tree, width: 8, height: 1) == ["   ab"])
    }

    @Test func frameWithAFlexibleChildStretchesIt() {
        let tree = VStack {
            Text("t")
            FlexibleSpacer()
        }
        .frame(width: 4, height: 5)
        // The frame's fixed height reaches the height-flexible child through
        // the query context; the spacer stretches to fill rows 1–4.
        #expect(embed(tree, width: 4, height: 5) == ["t", "", "", "", ""])
    }

    @Test func frameDoesNotClipOverflow() {
        let tree = ViewOutput("abcd")
            .frame(width: 2)
        // The frame occupies 2 columns but its raster child overflows to the
        // right; no clip (the pinned no-clip decision).
        #expect(embed(tree, width: 4, height: 1) == ["abcd"])
    }

    // MARK: Clip (masks at the reserved rect)

    @Test func clipMasksAtTheReservedRect() {
        let tree = ViewOutput("abcd")
            .frame(width: 2)
            .clipped()
        #expect(embed(tree, width: 4, height: 1) == ["ab"])
    }

    @Test func clipBlitsBlanksOverContentBeneath() {
        var buffer = CellBuffer(width: 4, height: 1)
        ViewOutput("wxyz")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 4, height: 1))
        )
        // `Spacer(columns: 2)` reserves 2×1 and paints nothing; the clip's
        // blank cells still replace 'w' and 'x' (blank-inclusive blit,
        // painter order) — only the reserved rect is overwritten.
        Spacer(columns: 2).clipped()._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 2, height: 1))
        )
        #expect(visibleRows(buffer) == ["  yz"])
    }

    @Test func clipReplacesOnlyItsReservedRect() {
        var buffer = CellBuffer(width: 4, height: 1)
        ViewOutput("wxyz")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 4, height: 1))
        )
        ViewOutput("a").clipped()._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 2, height: 1))
        )
        // Reserved 1×1: 'a' replaces 'w'; 'x' is outside the mask and stays.
        #expect(visibleRows(buffer) == ["axyz"])
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
