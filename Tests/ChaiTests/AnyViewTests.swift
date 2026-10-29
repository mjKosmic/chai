import Testing
import Chai

// MARK: - AnyView on the allocation kernel
//
// `AnyView` is a transparent eraser: it forwards all four engine SPI methods.
// The two subtle forwardings are `_childViews()` (structural transparency) and
// `_flexibility()` (leftover distribution) — losing either produces silently
// wrong layout with no crash.

@Suite("AnyView")
struct AnyViewTests {

    // MARK: Measurement + allocation

    @Test func forwardsMeasurement() {
        #expect(AnyView(Text("abc"))._measure(in: .unconstrained) == ViewSize(width: 3, height: 1))
        // The erased Text still wraps at the queried width.
        #expect(
            AnyView(Text("abcdef"))._measure(in: AvailableSize(width: 3, height: nil))
                == ViewSize(width: 3, height: 2)
        )
    }

    @Test func forwardsAllocation() {
        let view = AnyView(VStack {
            Text("a")
            Text("b")
        })
        #expect(engineRows(view, width: 8) == ["a", "b"])
    }

    @Test func nestedErasureForwards() {
        #expect(AnyView(AnyView(Text("x")))._measure(in: .unconstrained) == ViewSize(width: 1, height: 1))
    }

    // MARK: Child transparency

    @Test func forwardsChildViews() {
        let tuple = TupleView(Text("a"), Text("b"))
        #expect(AnyView(tuple)._childViews().count == 2)
    }

    @Test func erasedStructuralViewStaysTransparentToAContainer() {
        let stack = HStack {
            AnyView(TupleView(Text("a"), Text("b")))
            Text("c")
        }
        // With forwarding the tuple's two children are HStack columns → "abc".
        // An opaque wrapper would report one 1-wide child and produce
        // ["ac", "b"].
        #expect(engineRows(stack, width: 8) == ["abc"])
    }

    // MARK: Flexibility

    @Test func forwardsFlexibility() {
        #expect(AnyView(Spacer())._flexibility() == LayoutFlexibility(width: 1, height: 1))
        #expect(AnyView(Text("x"))._flexibility() == .rigid)
    }

    @Test func erasedFlexibleSpacerStillAbsorbsLeftover() {
        // The silent-failure case: without `_flexibility` forwarding the
        // wrapper is rigid, the HStack does not fill, and "R" sits at col 1.
        let stack = HStack {
            Text("L")
            AnyView(Spacer())
            Text("R")
        }
        #expect(engineRows(stack, width: 10) == ["L        R"])
    }

    // MARK: Heterogeneous builders

    @Test func heterogeneousLoopInVStack() {
        let rows: [any View] = [
            Text("a"),
            Text("bb"),
            ViewOutput("ccc"),
            AnyView(Text("d")),
        ]
        let stack = VStack {
            for row in rows {
                row
            }
        }
        #expect(engineRows(stack, width: 8) == ["a", "bb", "ccc", "d"])
    }

    @Test func heterogeneousLoopInHStackStaysTransparent() {
        let parts: [any View] = [Text("a"), Text("b"), Text("c")]
        let stack = HStack {
            for part in parts {
                part
            }
        }
        #expect(engineRows(stack, width: 8) == ["abc"])
    }

    @Test func buildArrayAcceptsHeterogeneousViews() {
        let erased: [any View] = [Text("a"), ViewOutput("b")]
        let view = ViewBuilder.buildArray(erased)
        #expect(engineRows(view, width: 8) == ["a", "b"])
    }

    @Test func homogeneousLoopsKeepForEachView() {
        // The homogeneous overload must stay the default so structural
        // transparency is unchanged for ordinary loops.
        let built = ViewBuilder.buildArray([Text("a"), Text("b")])
        #expect(built._childViews().count == 2)
    }
}
