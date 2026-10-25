import Testing
@testable import Chai

// MARK: - Phase-3 A2: flexibility SPI + Spacer / Fill primitives
//
// Milestone A2 of the phase-3 Stage A plan (UPGRADE.md): the `_flexibility()`
// SPI plus two minimal new primitives. Leftover *distribution* is a stack
// behavior and lives in `LatteTests/SpacerAndFillTests.swift`; this suite
// pins the value type, the default rigidity, and the primitives' rigid
// measurement/render in isolation. (Stage C unified `FlexibleSpacer` into
// `Spacer`: `Spacer()` / `Spacer(fraction:)` are the flexible forms.)
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
        // The protocol-extension default is `.rigid` — only flexible
        // `Spacer(fraction:)` overrides it.
        #expect(Text("x")._flexibility() == .rigid)
        #expect(ViewOutput("x")._flexibility() == .rigid)
        #expect(Spacer(lines: 1)._flexibility() == .rigid)
        #expect(Spacer(columns: 1)._flexibility() == .rigid)
        #expect(Empty()._flexibility() == .rigid)
        #expect(Fill()._flexibility() == .rigid)
        #expect(Label()._flexibility() == .rigid)
    }

    @Test func zeroArgSpacerIsFlexible() {
        // SwiftUI-style unification (UPGRADE.md, Stage C): `Spacer()` is the
        // flexible spacer, not a one-line fixed spacer.
        #expect(Spacer()._flexibility() == LayoutFlexibility(width: 1, height: 1))
    }
}

// MARK: - Spacer

@Suite("Spacer primitive")
struct SpacerPrimitiveTests {

    @Test func flexibilityReportsTheFractionOnBothAxes() {
        #expect(Spacer()._flexibility() == LayoutFlexibility(width: 1, height: 1))
        #expect(Spacer(fraction: 2)._flexibility() == LayoutFlexibility(width: 2, height: 2))
        #expect(Spacer(fraction: 0.5)._flexibility() == LayoutFlexibility(width: 0.5, height: 0.5))
    }

    @Test func nonPositiveFractionIsRigid() {
        #expect(Spacer(fraction: 0)._flexibility() == .rigid)
        #expect(Spacer(fraction: -1)._flexibility() == .rigid)
    }

    @Test func rigidMeasurementIsZeroAtEveryQuery() {
        // A stack measures flexible children rigidly (0 on the flexible axis);
        // outside a stack nothing distributes leftover, so it stays 0×0.
        #expect(Spacer()._measure(in: .unconstrained) == .zero)
        #expect(Spacer()._measure(in: AvailableSize(width: 8, height: 4)) == .zero)
        #expect(Spacer(fraction: 3)._measure(in: AvailableSize(width: 8, height: nil)) == .zero)
    }

    @Test func renderIsNoOp() {
        // Blank cells are the buffer default — a flexible spacer draws
        // nothing, and pre-existing cells are left untouched.
        var buffer = CellBuffer(width: 4, height: 1, fill: Cell(character: "x"))
        Spacer()._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 4, height: 1))
        )
        #expect(buffer[0, 0].character == "x")
        #expect(buffer[3, 0].character == "x")
    }

    @Test func asRootItIsZeroSized() {
        // A root view has no enclosing stack: nothing distributes leftover.
        #expect(Spacer()._measure(in: AvailableSize(width: 20, height: 5)) == .zero)
    }
}

// MARK: - Fill

@Suite("Fill primitive")
struct FillPrimitiveTests {

    @Test func answersTheQueryOnBothAxes() {
        #expect(Fill()._measure(in: AvailableSize(width: 4, height: 2)) == ViewSize(width: 4, height: 2))
    }

    @Test func nilDimensionIsUnconstrained() {
        // A `nil` dimension is unconstrained → 0 on that axis.
        #expect(Fill()._measure(in: AvailableSize(width: 4, height: nil)) == ViewSize(width: 4, height: 0))
        #expect(Fill()._measure(in: AvailableSize(width: nil, height: 2)) == ViewSize(width: 0, height: 2))
        #expect(Fill()._measure(in: .unconstrained) == .zero)
    }

    @Test func renderIsNoOp() {
        var buffer = CellBuffer(width: 4, height: 1, fill: Cell(character: "x"))
        Fill()._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 4, height: 1))
        )
        #expect(buffer[0, 0].character == "x")
        #expect(buffer[3, 0].character == "x")
    }
}
