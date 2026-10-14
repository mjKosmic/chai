import Testing
import Chai
import Latte

// MARK: - Phase-3 A3: `.clipped()`
//
// `ClipView` masks its content to the rect it is assigned. Clipping is a
// **render-time mask**:
//
// - Measurement is a passthrough (a clip never changes a size; the child may
//   still overrule the offer).
// - Rendering draws into a temp `CellBuffer` of the assigned `size` (origin
//   zero, same proposal — the A0 fit/render value-equality contract), then
//   blits the whole temp — blanks included — onto the shared buffer at
//   `origin`.
// - Overflow in either axis is dropped by the temp's bounds; the temp uses the
//   default truncate policy, so horizontal overflow is masked, not reflowed.
// - The clipped view OWNS its assigned rect: blanks the child never painted
//   replace whatever was beneath (painter's-algorithm semantics).
// - A wide character straddling the clip boundary is dropped by the temp's
//   write rules.
//
// The eager path cannot clip (no assigned rect), so it resolves the content
// unchanged — allowed divergence #9 in UPGRADE.md.
//
// Every expectation below was derived by running the code — never
// hand-computed.

@Suite("ClipView")
struct ClipViewTests {

    /// Measure `view` at `proposal`, render at its measured size into a
    /// `width`×`height` buffer, and extract visible rows (parity convention).
    private func rows(
        _ view: some View,
        proposal: ProposedSize,
        width: Int,
        height: Int
    ) -> [String] {
        let size = view._sizeThatFits(proposal)
        var buffer = CellBuffer(width: width, height: height)
        view._render(into: &buffer, at: .zero, size: size, proposal: proposal)
        return visibleRows(buffer)
    }

    // MARK: Measurement is a passthrough

    @Test func clippingDoesNotChangeMeasurement() {
        let proposal = ProposedSize(width: 4, height: nil)
        let framed = ViewOutput("abcd").frame(width: 2)
        let clipped = framed.clipped()
        #expect(clipped._sizeThatFits(proposal) == framed._sizeThatFits(proposal))
        #expect(clipped._sizeThatFits(proposal) == ViewSize(width: 2, height: 1))
    }

    @Test func clippedViewPassesThroughAnOverrulingChild() {
        // A `ViewOutput` ignores the zero offer and answers 4×1; the clip
        // passes that through unchanged (an offer, not a bound).
        #expect(ViewOutput("abcd").clipped()._sizeThatFits(.zero) == ViewSize(width: 4, height: 1))
    }

    @Test func clippedTextPassesThroughTheMinimum() {
        // A compressible child's minimum is passed through verbatim: at `.zero`
        // `Text("abcd")` answers (1, 4), so the clip does too.
        #expect(Text("abcd").clipped()._sizeThatFits(.zero) == ViewSize(width: 1, height: 4))
    }

    // MARK: Overflow is clipped

    @Test func horizontalOverflowIsClipped() {
        // Frame answers width 2; the 4-wide raster overflows and is masked.
        #expect(
            rows(ViewOutput("abcd").frame(width: 2).clipped(), proposal: ProposedSize(width: 4, height: nil), width: 4, height: 1)
                == ["ab"]
        )
    }

    @Test func verticalOverflowIsClipped() {
        // The frame is 2 rows tall; the 4-row child is masked to its top 2.
        let view = VStack { ViewOutput("a\nb\nc\nd") }.frame(width: 3, height: 2).clipped()
        #expect(view._sizeThatFits(.unspecified) == ViewSize(width: 3, height: 2))
        #expect(rows(view, proposal: .unspecified, width: 3, height: 2) == ["a", "b"])
    }

    @Test func bothAxesOverflowAreClipped() {
        let view = VStack { ViewOutput("abcdef") }.frame(width: 3, height: 1).clipped()
        #expect(view._sizeThatFits(ProposedSize(width: 10, height: nil)) == ViewSize(width: 3, height: 1))
        #expect(rows(view, proposal: ProposedSize(width: 10, height: nil), width: 10, height: 1) == ["abc"])
    }

    // MARK: The clipped view owns its assigned rect

    @Test func blanksReplaceContentBeneathTheRect() {
        // A buffer pre-filled with "x". The clip's 3-wide rect at col 1 has
        // "ab" plus one blank column the child never painted — that blank
        // column replaces the "x" that was there (painter's-algorithm
        // semantics: the clip owns its rect).
        var buffer = CellBuffer(width: 6, height: 1, fill: Cell(character: "x"))
        let view = VStack { ViewOutput("ab") }.frame(width: 3, height: 1).clipped()
        let size = view._sizeThatFits(.unspecified)
        view._render(into: &buffer, at: ViewOrigin(col: 1, row: 0), size: size, proposal: .unspecified)
        #expect(visibleRows(buffer) == ["xab xx"])
    }

    @Test func childSmallerThanRectLeavesBlankRowsInTheRect() {
        // The rect is 6×3 but the child is 2×1: the remaining cells (rows 1–2,
        // and the blank columns) are part of the clip's rect.
        let view = VStack { ViewOutput("ab") }.frame(width: 6, height: 3).clipped()
        #expect(view._sizeThatFits(.unspecified) == ViewSize(width: 6, height: 3))
        #expect(rows(view, proposal: .unspecified, width: 6, height: 3) == ["ab", "", ""])
    }

    // MARK: Nesting and composition

    @Test func nestedClipsAreIdempotentHere() {
        let view = ViewOutput("abcdef").frame(width: 5).clipped().clipped()
        #expect(view._sizeThatFits(ProposedSize(width: 5, height: nil)) == ViewSize(width: 5, height: 1))
        #expect(rows(view, proposal: ProposedSize(width: 5, height: nil), width: 5, height: 1) == ["abcde"])
    }

    @Test func clippedChildInsideHStack() {
        let stack = HStack {
            ViewOutput("abcd").frame(width: 2).clipped()
            Text("Z")
        }
        #expect(stack._sizeThatFits(ProposedSize(width: 8, height: nil)) == ViewSize(width: 3, height: 1))
        #expect(rows(stack, proposal: ProposedSize(width: 8, height: nil), width: 8, height: 1) == ["abZ"])
    }

    @Test func clippedChildInsideVStack() {
        let stack = VStack {
            ViewOutput("abcd").frame(width: 2).clipped()
            Text("Z")
        }
        #expect(rows(stack, proposal: ProposedSize(width: 8, height: nil), width: 8, height: 2) == ["ab", "Z"])
    }

    // MARK: Wide characters at the boundary

    @Test func wideCharStraddlingTheClipBoundaryIsDropped() {
        // "a你b" in a 2-wide rect: "a" at col 0; 你 (width 2) cannot fit at
        // col 1, so the temp buffer drops it; "b" then fills the freed column.
        var buffer = CellBuffer(width: 4, height: 1)
        let view = ViewOutput("a你b").frame(width: 2).clipped()
        let size = view._sizeThatFits(ProposedSize(width: 4, height: nil))
        view._render(into: &buffer, at: .zero, size: size, proposal: ProposedSize(width: 4, height: nil))
        #expect(buffer[0, 0].character == "a")
        #expect(buffer[1, 0].character == "b")
        #expect(buffer[2, 0] == .empty)
        #expect(visibleRows(buffer) == ["ab"])
    }

    @Test func wideCharFullyInsideTheRectIsPreserved() {
        // "你好" in a 4-wide rect: both wide characters fit, each with its
        // continuation cell.
        var buffer = CellBuffer(width: 4, height: 1)
        let view = ViewOutput("你好").frame(width: 4).clipped()
        let size = view._sizeThatFits(ProposedSize(width: 4, height: nil))
        view._render(into: &buffer, at: .zero, size: size, proposal: ProposedSize(width: 4, height: nil))
        #expect(buffer[0, 0].width == 2)
        #expect(buffer[1, 0].width == 0)
        #expect(visibleRows(buffer) == ["你好"])
    }

    // MARK: Fit/render consistency (A0)

    @Test func fitAndRenderUseTheSameProposal() {
        // The clip is measured at (10, nil) → (3, 1); rendering at that
        // assigned size with the SAME proposal produces the measured rows.
        let view = ViewOutput("abcdef").frame(width: 3).clipped()
        let proposal = ProposedSize(width: 10, height: nil)
        let size = view._sizeThatFits(proposal)
        #expect(size == ViewSize(width: 3, height: 1))
        var buffer = CellBuffer(width: 10, height: 1)
        view._render(into: &buffer, at: .zero, size: size, proposal: proposal)
        #expect(visibleRows(buffer) == ["abc"])
    }

    // MARK: Legacy body (eager path)

    @Test func legacyBodyResolvesTheContentUnchanged() {
        // The eager path has no assigned rect, so it cannot clip: `.clipped()`
        // is a no-op there (allowed divergence #9).
        let resolved = ViewOutput("abcd").frame(width: 2).clipped()._resolveToViewOutput()
        #expect(resolved.content.plainText == "abcd")
    }
}
