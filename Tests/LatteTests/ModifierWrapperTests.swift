import Testing
import Chai
import Latte

// MARK: - Modifier wrappers
//
// Modifiers stay in the view tree as wrappers rather than resolving to a
// raster. These tests pin the wrapper contract:
//
// - report = child report + insets (shrink-wrap),
// - the assignment bounds the child query (padding/border compose with
//   wrapping), while the child's report decides the painted extent,
// - flexibility is forwarded (a flexible child inside a wrapper still
//   absorbs a stack's leftover).

@Suite("Modifier wrappers")
struct ModifierWrapperTests {

    // MARK: Padding

    @Test func paddingReportsChildPlusInsets() {
        let view = Text("ab").padded(1)
        #expect(view._measure(in: .unconstrained) == ViewSize(width: 4, height: 3))
    }

    @Test func paddingSupportsAsymmetricInsets() {
        let view = Text("ab").padded(top: 1, right: 2, bottom: 3, left: 4)
        #expect(view._measure(in: .unconstrained) == ViewSize(width: 8, height: 5))
    }

    @Test func paddingBoundsTheChildQuery() {
        // The assignment (6) minus the horizontal insets (2) is the text's
        // wrap width: "abcdef" hard-wraps into two 4-column lines.
        let view = Text("abcdef").padded(1)
        #expect(
            view._measure(in: AvailableSize(width: 6, height: nil))
                == ViewSize(width: 6, height: 4)
        )
    }

    @Test func paddingPlacesTheChildAtTheInsetOrigin() {
        let rows = visibleRows(embedBuffer(Text("ab").padded(1), width: 10))
        #expect(rows == ["", " ab", ""])
    }

    @Test func paddingWrapsAtTheAllocatedWidth() {
        // The root rect is 6 wide, so the text is queried/embedded at 4 and
        // hard-wraps there — the assignment bounds the allocation too, not
        // just the query.
        let rows = visibleRows(embedBuffer(Text("abcdef").padded(1), width: 6))
        #expect(rows == ["", " abcd", " ef", ""])
    }

    @Test func paddingWrapsAStackChild() {
        let view = VStack {
            Text("a")
            Text("bb")
        }
        .padded(1)
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == ["", " a", " bb", ""])
    }

    @Test func paddingParticipatesInAnHStack() {
        let view = HStack {
            Text("a").padded(1)
            Text("b")
        }
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == ["   b", " a", ""])
    }

    @Test func paddingDoesNotStretchToTheRootRect() {
        // The root assignment is the terminal width; the wrapper still reports
        // and paints its content-sized box (shrink-wrap).
        let view = Text("x").padded(1)
        let measured = view._measure(in: AvailableSize(width: 40, height: nil))
        #expect(measured == ViewSize(width: 3, height: 3))
        #expect(visibleRows(embedBuffer(view, width: 40)) == ["", " x", ""])
    }

    @Test func marginIsPaddingAtTheRasterLevel() {
        #expect(
            visibleRows(embedBuffer(Text("ab").margined(1), width: 10))
                == visibleRows(embedBuffer(Text("ab").padded(1), width: 10))
        )
        #expect(
            Text("ab").margined(1)._measure(in: .unconstrained)
                == Text("ab").padded(1)._measure(in: .unconstrained)
        )
    }

    // MARK: Border

    @Test func borderReportsChildPlusOneCellOnEachSide() {
        let view = Text("ab").bordered(.ascii)
        #expect(view._measure(in: .unconstrained) == ViewSize(width: 4, height: 3))
    }

    @Test func borderBoundsTheChildQuery() {
        let view = Text("abcdef").bordered(.ascii)
        #expect(
            view._measure(in: AvailableSize(width: 6, height: nil))
                == ViewSize(width: 6, height: 4)
        )
    }

    @Test func borderDrawsAroundTheChild() {
        let rows = visibleRows(embedBuffer(Text("ab").bordered(.ascii), width: 10))
        #expect(rows == ["+--+", "|ab|", "+--+"])
    }

    @Test func borderWrapsAtTheAllocatedWidth() {
        let rows = visibleRows(embedBuffer(Text("abcdef").bordered(.ascii), width: 6))
        #expect(rows == ["+----+", "|abcd|", "|ef  |", "+----+"])
    }

    @Test func borderClosesWhenClippedToAShorterAllocation() {
        // The motivating status-panel composition: a bordered child inside a
        // frame too short for it. The box is drawn at the allocation's size,
        // so the bottom edge stays visible instead of being clipped away.
        let view = Text("a\nb\nc\nd").bordered(.ascii).frame(width: 6, height: 3)
        #expect(visibleRows(embedBuffer(view, width: 10)) == ["+-+", "|a|", "+-+"])
    }

    @Test func borderDrawsAroundAMultiLineChild() {
        let view = VStack {
            Text("a")
            Text("bb")
        }
        .bordered(.ascii)
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == ["+--+", "|a |", "|bb|", "+--+"])
    }

    @Test func nestedWrappersCompose() {
        let view = Text("x").padded(1).bordered(.ascii)
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == ["+---+", "|   |", "| x |", "|   |", "+---+"])
    }

    @Test func wrappersSurviveADegenerateAssignment() {
        // A 1×1 frame around a bordered view: the border box is clipped to the
        // frame, leaving only its top-left corner — no negative sizes, no
        // trap.
        let view = Text("ab").bordered(.ascii).frame(width: 1, height: 1)
        #expect(visibleRows(embedBuffer(view, width: 10)) == ["+"])
    }

    // MARK: Composition

    @Test func besideComposesHorizontally() {
        let rows = visibleRows(embedBuffer(Text("a").beside(Text("b")), width: 10))
        #expect(rows == ["ab"])
    }

    @Test func besideHonorsVerticalAlignment() {
        let view = Text("a").beside(Text("b").padded(1), align: .bottom)
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == ["", "  b", "a"])
    }

    @Test func aboveComposesVertically() {
        let view = Text("a").above(Text("bb"), align: .right)
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == [" a", "bb"])
    }

    // MARK: Flexibility forwarding

    @Test func wrappersForwardFlexibility() {
        #expect(Text("a").padded(1)._flexibility() == .rigid)
        #expect(Text("a").bordered(.ascii)._flexibility() == .rigid)
        #expect(
            Spacer().padded(1)._flexibility()
                == LayoutFlexibility(width: 1, height: 1)
        )
        #expect(
            Spacer().bordered(.ascii)._flexibility()
                == LayoutFlexibility(width: 1, height: 1)
        )
    }

    @Test func aFlexibleChildInsidePaddingStillAbsorbsLeftover() {
        // The padded spacer reports 4 (0 + 2 + 2) rigidly and forwards width
        // flexibility 1, so the HStack hands it the leftover. Its sibling
        // lands at the far edge. Without forwarding, "y" would sit at column 5.
        let view = HStack {
            Text("x")
            Spacer().padded(2)
            Text("y")
        }
        #expect(visibleRows(embedBuffer(view, width: 12)) == ["x          y", "", "", ""])
    }

    @Test func aFlexibleChildInsideABorderStillAbsorbsLeftover() {
        let view = HStack {
            Text("x")
            Spacer().bordered(.ascii)
            Text("y")
        }
        // Spacer report 0 → border report 2; rigid total 1 + 2 + 1 = 4;
        // the flexible share absorbs the remaining 8 → "y" at column 11.
        // The border draws its content-sized box (two glyph columns) at its
        // allocated origin, so the top row reads "x++        y".
        #expect(visibleRows(embedBuffer(view, width: 12)) == ["x++        y", " ++"])
    }
}
