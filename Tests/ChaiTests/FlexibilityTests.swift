import Testing
@testable import Chai

// MARK: - Phase-3 A2: flexibility SPI + FlexibleSpacer / Fill primitives
//
// Milestone A2 of the phase-3 Stage A plan (UPGRADE.md): the `_flexibility()`
// SPI plus two minimal new primitives. Leftover *distribution* is a stack
// behavior and lives in `LatteTests/FlexibleSpacerTests.swift`; this suite
// pins the value type, the default rigidity, and the primitives' rigid
// measurement/render in isolation.
//
// Expectations were derived by running the code — never hand-computed.

@Suite("Layout Flexibility")
struct LayoutFlexibilityTests {

    @Test func rigidIsNilOnBothAxes() {
        #expect(LayoutFlexibility.rigid == LayoutFlexibility(width: nil, height: nil))
        #expect(LayoutFlexibility.rigid.width == nil)
        #expect(LayoutFlexibility.rigid.height == nil)
    }

    @Test func initDefaultsToRigid() {
        #expect(LayoutFlexibility() == .rigid)
    }

    @Test func membersAndEquatable() {
        let one = LayoutFlexibility(width: 1, height: 2)
        #expect(one.width == 1)
        #expect(one.height == 2)
        #expect(one == LayoutFlexibility(width: 1, height: 2))
        #expect(one != LayoutFlexibility(width: 2, height: 1))
        #expect(one != .rigid)
    }
}

// MARK: - Default flexibility

@Suite("View flexibility default")
struct ViewFlexibilityDefaultTests {

    /// A minimal custom view whose body is a `ViewOutput` leaf.
    private struct Label: View {
        var body: ViewOutput { ViewOutput("x") }
    }

    @Test func everyOrdinaryViewIsRigid() {
        // The protocol-extension default is `.rigid` — only `FlexibleSpacer`
        // overrides it in A2.
        #expect(Text("x")._flexibility() == .rigid)
        #expect(ViewOutput("x")._flexibility() == .rigid)
        #expect(Spacer()._flexibility() == .rigid)
        #expect(Empty()._flexibility() == .rigid)
        #expect(Fill()._flexibility() == .rigid)
        #expect(Label()._flexibility() == .rigid)
    }
}

// MARK: - FlexibleSpacer

@Suite("FlexibleSpacer primitive")
struct FlexibleSpacerPrimitiveTests {

    @Test func flexibilityReportsTheFractionOnBothAxes() {
        #expect(FlexibleSpacer()._flexibility() == LayoutFlexibility(width: 1, height: 1))
        #expect(FlexibleSpacer(fraction: 2)._flexibility() == LayoutFlexibility(width: 2, height: 2))
        #expect(FlexibleSpacer(fraction: 0.5)._flexibility() == LayoutFlexibility(width: 0.5, height: 0.5))
    }

    @Test func nonPositiveFractionIsRigid() {
        #expect(FlexibleSpacer(fraction: 0)._flexibility() == .rigid)
        #expect(FlexibleSpacer(fraction: -1)._flexibility() == .rigid)
    }

    @Test func rigidMeasurementIsZeroAtEveryProposal() {
        // A stack measures flexible children rigidly (0 on the flexible axis);
        // outside a stack nothing distributes leftover, so it stays 0×0.
        #expect(FlexibleSpacer()._sizeThatFits(.unspecified) == .zero)
        #expect(FlexibleSpacer()._sizeThatFits(ProposedSize(width: 8, height: 4)) == .zero)
        #expect(FlexibleSpacer(fraction: 3)._sizeThatFits(ProposedSize(width: 8, height: nil)) == .zero)
    }

    @Test func renderIsNoOp() {
        // Blank cells are the buffer default — a flexible spacer draws
        // nothing, and pre-existing cells are left untouched.
        var buffer = CellBuffer(width: 4, height: 1, fill: Cell(character: "x"))
        FlexibleSpacer()._render(
            into: &buffer,
            at: .zero,
            size: ViewSize(width: 4, height: 1),
            proposal: ProposedSize(width: 4, height: nil)
        )
        #expect(buffer[0, 0].character == "x")
        #expect(buffer[3, 0].character == "x")
    }

    @Test func eagerBodyIsEmpty() {
        // The eager path has no stack to distribute leftover space into, so
        // the spacer resolves to empty content and an eager join skips it
        // (allowed divergence #7 in UPGRADE.md).
        let resolved = FlexibleSpacer()._resolveToViewOutput()
        #expect(resolved.content.lineCount() == 0)
        #expect(resolved.content.maxLineWidth == 0)
    }

    @Test func asRootItIsZeroSized() {
        // A root view has no enclosing stack: nothing distributes leftover.
        #expect(FlexibleSpacer()._sizeThatFits(ProposedSize(width: 20, height: 5)) == .zero)
    }
}

// MARK: - Fill

@Suite("Fill primitive")
struct FillPrimitiveTests {

    @Test func answersTheOfferOnBothAxes() {
        #expect(Fill()._sizeThatFits(ProposedSize(width: 4, height: 2)) == ViewSize(width: 4, height: 2))
    }

    @Test func nilDimensionIsNotAnOffer() {
        // A `nil` dimension is ideal, not an offer → 0 on that axis.
        #expect(Fill()._sizeThatFits(ProposedSize(width: 4, height: nil)) == ViewSize(width: 4, height: 0))
        #expect(Fill()._sizeThatFits(ProposedSize(width: nil, height: 2)) == ViewSize(width: 0, height: 2))
        #expect(Fill()._sizeThatFits(.unspecified) == .zero)
    }

    @Test func renderIsNoOp() {
        var buffer = CellBuffer(width: 4, height: 1, fill: Cell(character: "x"))
        Fill()._render(
            into: &buffer,
            at: .zero,
            size: ViewSize(width: 4, height: 1),
            proposal: ProposedSize(width: 4, height: 1)
        )
        #expect(buffer[0, 0].character == "x")
        #expect(buffer[3, 0].character == "x")
    }

    @Test func eagerBodyIsEmpty() {
        // No proposal context eagerly → `Fill` claims nothing.
        let resolved = Fill()._resolveToViewOutput()
        #expect(resolved.content.lineCount() == 0)
        #expect(resolved.content.maxLineWidth == 0)
    }
}
