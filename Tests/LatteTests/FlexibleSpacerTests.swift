import Testing
import Chai
import Latte

// MARK: - Phase-3 A2: FlexibleSpacer in stacks + Fill in the engine
//
// Milestone A2 of the phase-3 Stage A plan (UPGRADE.md): a stack whose main
// axis has at least one positively-flexible child fills a non-`nil` main-axis
// proposal and splits the leftover between the flexible children. The pinned
// formula (fit and render both recompute it from the same proposal):
//
//     stackSize = proposal ?? rigidTotal
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

@Suite("FlexibleSpacer in HStack")
struct FlexibleSpacerHStackTests {

    @Test func singleSpacerAbsorbsTheLeftover() {
        let stack = HStack {
            Text("L")
            FlexibleSpacer()
            Text("R")
        }
        // Rigid total 2; the flexing stack fills the 10-column offer; the
        // spacer takes all 8 leftover columns.
        #expect(
            stack._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 10, height: 1)
        )
        #expect(visibleRows(engineBuffer(stack, width: 10)) == ["L        R"])
    }

    @Test func twoEqualSpacersSplitEvenlyAndLeaveTheOddRemainderUnallocated() {
        let stack = HStack {
            Text("A")
            FlexibleSpacer()
            Text("B")
            FlexibleSpacer()
            Text("C")
        }
        // Rigid total 3, leftover 7, totalFlex 2 → Int(7 × 0.5) = 3 each.
        // 3 + 3 = 6 of the 7 leftover columns are allocated; the remaining
        // column is left unallocated at the TRAILING end of the stack (after
        // "C"), which the visible-row convention strips.
        #expect(
            stack._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 10, height: 1)
        )
        let buffer = engineBuffer(stack, width: 10)
        #expect(visibleRows(buffer) == ["A   B   C"])
        // "C" sits at col 8 (1 + 3 + 1 + 3); col 9 is the unallocated
        // remainder — empty, not part of any child.
        #expect(buffer[8, 0].character == "C")
        #expect(buffer[9, 0] == .empty)
    }

    @Test func oddLeftoverRemainderIsUnallocatedAtTheTrailingEnd() {
        let stack = HStack {
            Text("A")
            FlexibleSpacer()
            Text("B")
            FlexibleSpacer()
            Text("C")
        }
        // Rigid total 3, leftover 5, totalFlex 2 → Int(5 × 0.5) = 2 each.
        // 4 of 5 columns allocated; 1 left unallocated after "C".
        let buffer = engineBuffer(stack, width: 8)
        #expect(visibleRows(buffer) == ["A  B  C"])
        #expect(buffer[6, 0].character == "C")
        #expect(buffer[7, 0] == .empty)
    }

    @Test func normalizedFractionsShareProportionally() {
        let stack = HStack {
            Text("A")
            FlexibleSpacer(fraction: 1)
            Text("B")
            FlexibleSpacer(fraction: 2)
            Text("C")
        }
        // Rigid total 3, leftover 7, totalFlex 3 → Int(7 × 1/3) = 2 and
        // Int(7 × 2/3) = 4 (1 column left unallocated).
        #expect(visibleRows(engineBuffer(stack, width: 10)) == ["A  B    C"])
    }

    @Test func zeroFractionBehavesRigidly() {
        // A non-positive fraction is `.rigid`: the stack is not flexing, so
        // it does not fill and the spacer occupies nothing.
        let stack = HStack {
            Text("A")
            FlexibleSpacer(fraction: 0)
            Text("B")
        }
        #expect(
            stack._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 2, height: 1)
        )
        #expect(visibleRows(engineBuffer(stack, width: 10)) == ["AB"])
    }

    @Test func nilWidthProposalStaysContentSized() {
        // No offer → no leftover to distribute: the spacer contributes 0.
        let stack = HStack {
            Text("L")
            FlexibleSpacer()
            Text("R")
        }
        #expect(stack._sizeThatFits(.unspecified) == ViewSize(width: 2, height: 1))
        #expect(
            stack._sizeThatFits(ProposedSize(width: nil, height: 4)) == ViewSize(width: 2, height: 1)
        )
    }

    @Test func flexStackNeverReportsBelowItsRigidContent() {
        // PR #21 review: a 0-wide spacer must not hide overflow from the
        // parent (an offer, not a bound) — a flexing stack floors its answer
        // at the rigid total even when the offer is smaller.
        let stack = HStack {
            Text("aaaa")
            FlexibleSpacer()
            Text("bbbb")
        }
        #expect(
            stack._sizeThatFits(ProposedSize(width: 3, height: nil)) == ViewSize(width: 8, height: 1)
        )
    }

    @Test func negativeMainAxisProposalFloorsAtRigidTotal() {
        // PR #21 review: a negative offer used to produce a negative ViewSize
        // (no other view does that — Text clamps negatives to the minimum).
        let stack = HStack {
            Text("aaaa")
            FlexibleSpacer()
            Text("bbbb")
        }
        #expect(
            stack._sizeThatFits(ProposedSize(width: -4, height: nil)) == ViewSize(width: 8, height: 1)
        )
    }

    @Test func rigidStackDoesNotFillAWideProposal() {
        // The pre-A2 path, unchanged: without a flexible child the stack is
        // content-sized no matter how wide the offer is.
        let stack = HStack {
            Text("a")
            Spacer(columns: 3)
            Text("b")
        }
        #expect(
            stack._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 5, height: 1)
        )
    }

    @Test func flexibleSpacerNestedInAFlexingHStackIsPlacedAtItsFinalSize() {
        // A nested stack is one child of the outer HStack, so the outer
        // stack's own leftover goes to the outer spacer; the inner HStack is
        // offered the outer VStack's width proposal and flexes within it.
        let nested = VStack {
            Text("hi")
            HStack {
                Text("a")
                FlexibleSpacer()
                Text("b")
            }
        }
        #expect(
            nested._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 10, height: 2)
        )
        #expect(visibleRows(engineBuffer(nested, width: 10)) == ["hi", "a        b"])
    }
}

// MARK: - VStack

@Suite("FlexibleSpacer in VStack")
struct FlexibleSpacerVStackTests {

    private var stack: VStack<TupleView<Text, FlexibleSpacer, Text>> {
        VStack {
            Text("T")
            FlexibleSpacer()
            Text("B")
        }
    }

    @Test func nilHeightProposalStaysContentSized() {
        #expect(stack._sizeThatFits(.unspecified) == ViewSize(width: 1, height: 2))
    }

    @Test func heightProposalIsFilledAndDistributed() {
        // Rigid total 2, offer 6, leftover 4 → the spacer's final height is 4.
        let proposal = ProposedSize(width: nil, height: 6)
        #expect(stack._sizeThatFits(proposal) == ViewSize(width: 1, height: 6))
        var buffer = CellBuffer(width: 1, height: 6)
        stack._render(
            into: &buffer,
            at: .zero,
            size: ViewSize(width: 1, height: 6),
            proposal: proposal
        )
        #expect(visibleRows(buffer) == ["T", "", "", "", "", "B"])
    }

    @Test func fixedFrameHeightFeedsTheFlexingStack() {
        // Through a fixed-height frame the offer reaches the stack as
        // `ProposedSize(width: 3, height: 6)`.
        let framed = VStack {
            Text("T")
            FlexibleSpacer()
            Text("B")
        }
        .frame(height: 6)
        #expect(framed._sizeThatFits(.unspecified) == ViewSize(width: 1, height: 6))
        #expect(visibleRows(engineBuffer(framed, width: 3)) == ["T", "", "", "", "", "B"])
    }

    @Test func twoEqualSpacersSplitEvenlyAndLeaveTheOddRemainderAtTheBottom() {
        // Rigid total 3, offer 10, leftover 7, totalFlex 2 → 3 each; the
        // unallocated remainder is the last row (the trailing end).
        let framed = VStack {
            Text("T")
            FlexibleSpacer()
            Text("M")
            FlexibleSpacer()
            Text("B")
        }
        .frame(height: 10)
        let buffer = engineBuffer(framed, width: 1)
        #expect(visibleRows(buffer) == ["T", "", "", "", "M", "", "", "", "B", ""])
    }

    @Test func flexibilityIsNotTransitiveThroughACompositeChild() {
        // Only a stack's DIRECT children report flexibility, and a `VStack`
        // is an ordinary composite child (not a structural view). The outer
        // VStack is therefore rigid, and the inner stack never receives the
        // height offer (a VStack proposes `nil` height to its children).
        let nested = VStack {
            VStack {
                FlexibleSpacer()
            }
        }
        #expect(nested._sizeThatFits(ProposedSize(width: nil, height: 7)) == .zero)
    }

    @Test func outsideAStackTheSpacerIsZeroSized() {
        // As a root view, and inside a frame, nothing distributes leftover
        // space — the spacer measures 0×0 and the frame's fixed rect is blank.
        #expect(FlexibleSpacer()._sizeThatFits(ProposedSize(width: 20, height: 5)) == .zero)
        let framed = FlexibleSpacer().frame(width: 5, height: 4)
        #expect(framed._sizeThatFits(.unspecified) == ViewSize(width: 5, height: 4))
        #expect(visibleRows(engineBuffer(framed, width: 5)) == ["", "", "", ""])
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
        func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize { .zero }
        func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {}
        func _flexibility() -> LayoutFlexibility {
            LayoutFlexibility(width: 0.5, height: 0.5)
        }
    }

    @Test func customFlexibleViewSharesWithFlexibleSpacer() {
        let stack = HStack {
            Text("A")
            HalfFlex()
            FlexibleSpacer(fraction: 1)
            Text("B")
        }
        // Rigid total 2, leftover 8, totalFlex 1.5 → Int(8 × 0.5/1.5) = 2 for
        // the custom view and Int(8 × 1/1.5) = 5 for the spacer (1 column
        // unallocated).
        let buffer = engineBuffer(stack, width: 10)
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
            FlexibleSpacer(fraction: .infinity)
            Text("B")
        }
        #expect(
            stack._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 2, height: 1)
        )
        #expect(visibleRows(engineBuffer(stack, width: 10)) == ["AB"])
    }
}

// MARK: - Fill

@Suite("Fill in stacks and frames")
struct FillInStacksTests {

    @Test func hstackChildClaimsTheOfferedHeight() {
        // `Fill` is a consumer: in an HStack it is offered `(nil, height)` and
        // answers the height, making the HStack that tall.
        let withFill = HStack {
            Fill()
            Text("x")
        }
        #expect(
            withFill._sizeThatFits(ProposedSize(width: nil, height: 3)) == ViewSize(width: 1, height: 3)
        )
        let withoutFill = HStack {
            Text("x")
        }
        #expect(
            withoutFill._sizeThatFits(ProposedSize(width: nil, height: 3)) == ViewSize(width: 1, height: 1)
        )
    }

    @Test func fillDisplacesSiblingsInABottomAlignedFrame() {
        // The frame offers `(4, 3)`; `Fill` makes the HStack 3 tall, so the
        // bottom-aligned frame places it at the top (no vertical shortage) —
        // "x" lands on row 0. Without `Fill` the stack is 1 tall and lands on
        // the bottom row.
        let withFill = HStack {
            Fill()
            Text("x")
        }
        .frame(width: 4, height: 3, verticalAlignment: .bottom)
        #expect(visibleRows(engineBuffer(withFill, width: 4)) == ["x", "", ""])

        let withoutFill = HStack {
            Text("x")
        }
        .frame(width: 4, height: 3, verticalAlignment: .bottom)
        #expect(visibleRows(engineBuffer(withoutFill, width: 4)) == ["", "", "x"])
    }

    @Test func fillInsideAFixedFrameOccupiesTheFrame() {
        #expect(Fill().frame(width: 5, height: 3)._sizeThatFits(.unspecified) == ViewSize(width: 5, height: 3))
    }

    @Test func fillInAVStackClaimsTheProposedWidth() {
        // Engine-only consequence of `Fill`'s consumer semantics: a VStack
        // offers its width proposal to its children, so `Fill` makes the
        // stack as wide as the offer — visible through a non-left alignment.
        // The eager path has no proposal context and resolves `Fill` to
        // empty, so it stays content-sized.
        let stack = VStack(alignment: .right) {
            Text("ab")
            Fill()
        }
        #expect(
            stack._sizeThatFits(ProposedSize(width: 8, height: nil)) == ViewSize(width: 8, height: 1)
        )
        #expect(visibleRows(engineBuffer(stack, width: 8)) == ["      ab"])
        #expect(visibleRows(eagerBuffer(stack, width: 8)) == ["ab"])
    }
}
