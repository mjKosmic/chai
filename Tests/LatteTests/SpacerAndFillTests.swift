import Testing
import Chai
import Latte

// MARK: - Phase-3 A2: Spacer in stacks + Fill in the engine
//
// Milestone A2 of the phase-3 Stage A plan (docs/history/VIEW-LAYER-MIGRATION-LOG.md): a stack whose main
// axis has at least one positively-flexible child fills a non-`nil` main-axis
// assignment and splits the leftover between the flexible children. The pinned
// formula (the query and allocation share one `StackAllocation` shape):
//
//     stackSize = assignment ?? rigidTotal
//     leftover  = max(0, stackSize - rigidTotal)
//     totalFlex = Σ positive fractions
//     child[i]  = rigid[i] + Int(Double(leftover) * (fraction[i] / totalFlex))
//
// `Int()` truncates, so the division remainder is left unallocated at the
// trailing end of the stack. With no flexible child the code path is
// unchanged (rigid stacks do not fill — pinned below and by the corpus).
//
// Expectations were derived by running the code — never hand-computed.
// `visibleRows` (from `LayoutParity/ParityHarness.swift`) is the parity
// convention: zero-width cells skipped, wide cells counted once, trailing
// spaces stripped — so an unallocated trailing remainder is invisible there
// and is pinned on the raw cells instead.

// MARK: - HStack

@Suite("Spacer in HStack")
struct SpacerHStackTests {

    @Test func singleSpacerAbsorbsTheLeftover() {
        let stack = HStack {
            Text("L")
            Spacer()
            Text("R")
        }
        // Rigid total 2; the flexing stack fills the 10-column assignment; the
        // spacer takes all 8 leftover columns.
        #expect(
            stack._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 10, height: 1)
        )
        #expect(visibleRows(embedBuffer(stack, width: 10)) == ["L        R"])
    }

    @Test func twoEqualSpacersSplitEvenlyAndLeaveTheOddRemainderUnallocated() {
        let stack = HStack {
            Text("A")
            Spacer()
            Text("B")
            Spacer()
            Text("C")
        }
        // Rigid total 3, leftover 7, totalFlex 2 → Int(7 × 0.5) = 3 each.
        // 3 + 3 = 6 of the 7 leftover columns are allocated; the remaining
        // column is left unallocated at the TRAILING end of the stack (after
        // "C"), which the visible-row convention strips.
        #expect(
            stack._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 10, height: 1)
        )
        let buffer = embedBuffer(stack, width: 10)
        #expect(visibleRows(buffer) == ["A   B   C"])
        // "C" sits at col 8 (1 + 3 + 1 + 3); col 9 is the unallocated
        // remainder — empty, not part of any child.
        #expect(buffer[8, 0].character == "C")
        #expect(buffer[9, 0] == .empty)
    }

    @Test func oddLeftoverRemainderIsUnallocatedAtTheTrailingEnd() {
        let stack = HStack {
            Text("A")
            Spacer()
            Text("B")
            Spacer()
            Text("C")
        }
        // Rigid total 3, leftover 5, totalFlex 2 → Int(5 × 0.5) = 2 each.
        // 4 of 5 columns allocated; 1 left unallocated after "C".
        let buffer = embedBuffer(stack, width: 8)
        #expect(visibleRows(buffer) == ["A  B  C"])
        #expect(buffer[6, 0].character == "C")
        #expect(buffer[7, 0] == .empty)
    }

    @Test func normalizedFractionsShareProportionally() {
        let stack = HStack {
            Text("A")
            Spacer(fraction: 1)
            Text("B")
            Spacer(fraction: 2)
            Text("C")
        }
        // Rigid total 3, leftover 7, totalFlex 3 → Int(7 × 1/3) = 2 and
        // Int(7 × 2/3) = 4 (1 column left unallocated).
        #expect(visibleRows(embedBuffer(stack, width: 10)) == ["A  B    C"])
    }

    @Test func zeroFractionBehavesRigidly() {
        // A non-positive fraction is `.rigid`: the stack is not flexing, so
        // it does not fill and the spacer occupies nothing.
        let stack = HStack {
            Text("A")
            Spacer(fraction: 0)
            Text("B")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 2, height: 1)
        )
        #expect(visibleRows(embedBuffer(stack, width: 10)) == ["AB"])
    }

    @Test func unconstrainedWidthStaysContentSized() {
        // No assignment → no leftover to distribute: the spacer contributes 0.
        let stack = HStack {
            Text("L")
            Spacer()
            Text("R")
        }
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 2, height: 1))
        #expect(
            stack._measure(in: AvailableSize(width: nil, height: 4)) == ViewSize(width: 2, height: 1)
        )
    }

    @Test func flexStackNeverReportsBelowItsRigidContent() {
        // PR #21 review: a 0-wide spacer must not hide overflow from the
        // parent (a query, not a bound) — a flexing stack floors its answer
        // at the rigid total even when the assignment is smaller.
        let stack = HStack {
            Text("aaaa")
            Spacer()
            Text("bbbb")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 3, height: nil)) == ViewSize(width: 8, height: 1)
        )
    }

    @Test func negativeMainAxisAssignmentFloorsAtRigidTotal() {
        // PR #21 review: a negative query used to produce a negative ViewSize
        // (no other view does that — Text clamps negatives to the minimum).
        let stack = HStack {
            Text("aaaa")
            Spacer()
            Text("bbbb")
        }
        #expect(
            stack._measure(in: AvailableSize(width: -4, height: nil)) == ViewSize(width: 8, height: 1)
        )
    }

    @Test func rigidStackDoesNotFillAWideAssignment() {
        // The pre-A2 path, unchanged: without a flexible child the stack is
        // content-sized no matter how wide the assignment is.
        let stack = HStack {
            Text("a")
            Spacer(columns: 3)
            Text("b")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 5, height: 1)
        )
    }

    @Test func flexibleSpacerNestedInAFlexingHStackIsPlacedAtItsFinalSize() {
        // A nested stack is one child of the outer HStack, so the outer
        // stack's own leftover goes to the outer spacer; the inner HStack is
        // queried at the outer VStack's width and flexes within it.
        let nested = VStack {
            Text("hi")
            HStack {
                Text("a")
                Spacer()
                Text("b")
            }
        }
        #expect(
            nested._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 10, height: 2)
        )
        #expect(visibleRows(embedBuffer(nested, width: 10)) == ["hi", "a        b"])
    }
}

// MARK: - VStack

@Suite("Spacer in VStack")
struct SpacerVStackTests {

    private var stack: VStack<TupleView<Text, Spacer, Text>> {
        VStack {
            Text("T")
            Spacer()
            Text("B")
        }
    }

    @Test func unconstrainedHeightStaysContentSized() {
        #expect(stack._measure(in: .unconstrained) == ViewSize(width: 1, height: 2))
    }

    @Test func heightAssignmentIsFilledAndDistributed() {
        // Rigid total 2, assigned height 6, leftover 4 → the spacer's final
        // height is 4.
        let available = AvailableSize(width: nil, height: 6)
        #expect(stack._measure(in: available) == ViewSize(width: 1, height: 6))
        var buffer = CellBuffer(width: 1, height: 6)
        stack._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 1, height: 6))
        )
        #expect(visibleRows(buffer) == ["T", "", "", "", "", "B"])
    }

    @Test func fixedFrameHeightFeedsTheFlexingStack() {
        // Through a fixed-height frame the assignment reaches the stack as
        // `AvailableSize(width: 3, height: 6)`.
        let framed = VStack {
            Text("T")
            Spacer()
            Text("B")
        }
        .frame(height: 6)
        #expect(framed._measure(in: .unconstrained) == ViewSize(width: 1, height: 6))
        #expect(visibleRows(embedBuffer(framed, width: 3)) == ["T", "", "", "", "", "B"])
    }

    @Test func twoEqualSpacersSplitEvenlyAndLeaveTheOddRemainderAtTheBottom() {
        // Rigid total 3, assignment 10, leftover 7, totalFlex 2 → 3 each; the
        // unallocated remainder is the last row (the trailing end).
        let framed = VStack {
            Text("T")
            Spacer()
            Text("M")
            Spacer()
            Text("B")
        }
        .frame(height: 10)
        let buffer = embedBuffer(framed, width: 1)
        #expect(visibleRows(buffer) == ["T", "", "", "", "M", "", "", "", "B", ""])
    }

    @Test func flexibilityIsNotTransitiveThroughACompositeChild() {
        // Only a stack's DIRECT children report flexibility, and a `VStack`
        // is an ordinary composite child (not a structural view). The outer
        // VStack is therefore rigid, and the inner stack never receives the
        // height context (a VStack queries its children with `nil` height).
        let nested = VStack {
            VStack {
                Spacer()
            }
        }
        #expect(nested._measure(in: AvailableSize(width: nil, height: 7)) == .zero)
    }

    @Test func outsideAStackTheSpacerIsZeroSized() {
        // As a root view, and inside a frame, nothing distributes leftover
        // space — the spacer measures 0×0 and the frame's fixed rect is blank.
        #expect(Spacer()._measure(in: AvailableSize(width: 20, height: 5)) == .zero)
        let framed = Spacer().frame(width: 5, height: 4)
        #expect(framed._measure(in: .unconstrained) == ViewSize(width: 5, height: 4))
        #expect(visibleRows(embedBuffer(framed, width: 5)) == ["", "", "", ""])
    }
}

// MARK: - The SPI from a custom view

@Suite("Flexibility SPI (custom views)")
struct FlexibilitySPITests {

    /// A test-local flexible view that participates in distribution purely by
    /// overriding the `_flexibility()` SPI — the "advanced view/container
    /// author" path the SPI is documented for.
    private struct HalfFlex: View {
        var body: ViewOutput { ViewOutput("") }
        func _measure(in available: AvailableSize) -> ViewSize { .zero }
        func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {}
        func _flexibility() -> LayoutFlexibility {
            LayoutFlexibility(width: 0.5, height: 0.5)
        }
    }

    @Test func customFlexibleViewSharesWithSpacer() {
        let stack = HStack {
            Text("A")
            HalfFlex()
            Spacer(fraction: 1)
            Text("B")
        }
        // Rigid total 2, leftover 8, totalFlex 1.5 → Int(8 × 0.5/1.5) = 2 for
        // the custom view and Int(8 × 1/1.5) = 5 for the spacer (1 column
        // unallocated).
        let buffer = embedBuffer(stack, width: 10)
        #expect(visibleRows(buffer) == ["A       B"])
        #expect(buffer[8, 0].character == "B")
        #expect(buffer[9, 0] == .empty)
    }

    @Test func nonFiniteFractionIsTreatedAsRigid() {
        // `_flexibility()` is public SPI, so a fraction can be anything a
        // conformer returns. A non-finite share is normalized to rigid rather
        // than letting `NaN` reach `Int(_:)` (which would trap).
        let stack = HStack {
            Text("A")
            Spacer(fraction: .infinity)
            Text("B")
        }
        #expect(
            stack._measure(in: AvailableSize(width: 10, height: nil)) == ViewSize(width: 2, height: 1)
        )
        #expect(visibleRows(embedBuffer(stack, width: 10)) == ["AB"])
    }
}

// MARK: - Fill

@Suite("Fill in stacks and frames")
struct FillInStacksTests {

    @Test func hstackChildClaimsTheQueriedHeight() {
        // `Fill` is a consumer: in an HStack it is queried with `(nil, height)` and
        // answers the height, making the HStack that tall.
        let withFill = HStack {
            Fill()
            Text("x")
        }
        #expect(
            withFill._measure(in: AvailableSize(width: nil, height: 3)) == ViewSize(width: 1, height: 3)
        )
        let withoutFill = HStack {
            Text("x")
        }
        #expect(
            withoutFill._measure(in: AvailableSize(width: nil, height: 3)) == ViewSize(width: 1, height: 1)
        )
    }

    @Test func fillDisplacesSiblingsInABottomAlignedFrame() {
        // The frame assigns `(4, 3)`; `Fill` makes the HStack fill the assigned
        // width, so the bottom-aligned frame has no vertical shortage and "x"
        // lands on row 0. Phase-4 allocation delta (docs/history/VIEW-LAYER-MIGRATION-LOG.md, "Phase 4 —
        // allocation deltas"): the leading `Fill` also claims the horizontal
        // remainder (columns 0–2), so "x" shifts to col 3. The phase-3 engine
        // (which never offered width to HStack children) placed it at col 0.
        let withFill = HStack {
            Fill()
            Text("x")
        }
        .frame(width: 4, height: 3, verticalAlignment: .bottom)
        #expect(visibleRows(embedBuffer(withFill, width: 4)) == ["   x", "", ""])

        let withoutFill = HStack {
            Text("x")
        }
        .frame(width: 4, height: 3, verticalAlignment: .bottom)
        #expect(visibleRows(embedBuffer(withoutFill, width: 4)) == ["", "", "x"])
    }

    @Test func fillInsideAFixedFrameOccupiesTheFrame() {
        #expect(Fill().frame(width: 5, height: 3)._measure(in: .unconstrained) == ViewSize(width: 5, height: 3))
    }

    @Test func fillInAVStackClaimsTheAssignedWidth() {
        // Consequence of `Fill`'s consumer semantics: a VStack
        // queries its children at its width, so `Fill` claims that
        // width — visible through a non-left alignment.
        // empty, so it stays content-sized.
        let stack = VStack(alignment: .right) {
            Text("ab")
            Fill()
        }
        #expect(
            stack._measure(in: AvailableSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(visibleRows(embedBuffer(stack, width: 8)) == ["      ab"])
    }
}
