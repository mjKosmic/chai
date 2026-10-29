import Testing
import Chai

// MARK: - Hard-box contract
//
// A view's allocated rect is its painting bound: containers clamp child rects
// to their own allocation, and the kernel clips every `_embed` to its rect.
// Nothing a child paints can land outside the space its parent gave it.

@Suite("Hard-box containment")
struct HardBoxTests {

    /// A custom view that reports a size and then deliberately paints beyond
    /// its rect — the kernel must contain it.
    private struct Overwriter: View {
        func _measure(in available: AvailableSize) -> ViewSize {
            ViewSize(width: 3, height: 1)
        }

        func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
            buffer.write(
                StyledText("XXXXX"),
                at: rect.origin.col,
                row: rect.origin.row
            )
            buffer.write(
                StyledText("YYYYY"),
                at: rect.origin.col,
                row: rect.origin.row + 1
            )
        }
    }

    /// A view that reports a fixed width regardless of its query, and paints
    /// the width of the rect it was actually allocated.
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

    @Test func frameClipsAWrappedStatusLineToItsHeight() {
        // The motivating case: a 1-row status box. Text wraps at 10; only the
        // first row is inside the box.
        let view = Text("abcdefghijklmnop")
            .frame(width: 10, height: 1)
        #expect(visibleRows(embedBuffer(view, width: 20)) == ["abcdefghij"])
    }

    @Test func customViewCannotPaintOutsideItsRect() {
        // The Overwriter paints 5 columns and 2 rows from a 3×1 box. The box
        // clips both axes; the sibling below is untouched.
        let view = VStack {
            Text("footer")
            Overwriter().frame(width: 3, height: 1)
        }
        .frame(width: 8, height: 3)
        #expect(visibleRows(embedBuffer(view, width: 8)) == ["footer", "XXX", ""])
    }

    @Test func childReceivesARectClampedToItsParent() {
        // The probe reports 8 wide but its frame is 3; the allocation hands it
        // 3, so it wraps/paints at the real width.
        let view = WidthProbe(reported: 8).frame(width: 3, height: 1)
        #expect(visibleRows(embedBuffer(view, width: 10)) == ["W:3"])
    }

    @Test func wideCharacterStraddlingTheClipBoundaryIsDropped() {
        // "你" is 2 columns; a 1-column box cannot show it, and the kernel
        // must not split the glyph into a primary without a continuation.
        let view = Text("你").frame(width: 1, height: 1)
        #expect(visibleRows(embedBuffer(view, width: 4)) == [""])
    }

    @Test func clippedRectRestoresForSiblings() {
        // The first child is contained; the second child's full rect is not
        // poisoned by the first child's clip.
        let view = HStack {
            WidthProbe(reported: 8).frame(width: 3, height: 1)
            Text("ok")
        }
        #expect(visibleRows(embedBuffer(view, width: 10)) == ["W:3ok"])
    }

    @Test func nestedBoxesClipAtEachLevel() {
        // Inner frame 4×1 inside an outer 6×2; padding inside the inner frame
        // reduces the content box further. Long text wraps to the content
        // width and is clipped to one row.
        let view = Text("abcdefgh")
            .padded(0, 1)
            .frame(width: 6, height: 1)
            .frame(width: 6, height: 2)
        #expect(visibleRows(embedBuffer(view, width: 10)) == [" abcd", ""])
    }
}
