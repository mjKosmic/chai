import Testing
import Chai

// MARK: - Phase-4 allocation kernel (Chai leaves)
//
// P1 of the phase-4 plan (docs/history/VIEW-LAYER-MIGRATION-LOG.md): the `_embed(into:at:)` allocation
// entrance, the `ViewRect` assignment value, and the leaf rules.
//
// Pinned decisions exercised here:
// - The rect is an ASSIGNMENT: leaves render at intrinsic size,
//   anchored top-left in their rect (decision 2 — no leaf stretching).
// - `Text` wraps at the width it was ALLOCATED and applies the compression
//   floor (decision 4): a wide/CJK character is never squeezed into a narrower
//   rect; the glyph is written whole and the kernel clips it when it does not
//   fit.
// - The default `_embed` resolves through `body`, so `body: ViewOutput` models
//   need zero engine code (the simple-path contract).
//
// Most tests call `_embed` directly to pin leaf behavior; the kernel clip is
// installed by `CellBuffer.embed`, so tests that assert containment go through
// it (`CellBufferClipTests` pins the clip itself).
//
// Expectations were derived by running the code, never hand-computed.

/// Visible-row extraction for Chai-only tests (the Latte parity harness has its
/// own copy in a different test target).
private func embedRows(_ buffer: CellBuffer) -> [String] {
    var rows: [String] = []
    for row in 0..<buffer.height {
        var line = ""
        for col in 0..<buffer.width {
            let cell = buffer[col, row]
            if cell.width == 0 { continue }
            line.append(cell.character)
        }
        while line.hasSuffix(" ") { line.removeLast() }
        rows.append(line)
    }
    return rows
}

// MARK: - Types

@Suite("Allocation types")
struct AllocationTypesTests {

    @Test func viewRectMembers() {
        let rect = ViewRect(origin: ViewOrigin(col: 3, row: 2), size: ViewSize(width: 5, height: 4))
        #expect(rect.origin == ViewOrigin(col: 3, row: 2))
        #expect(rect.size == ViewSize(width: 5, height: 4))
    }

    @Test func viewRectDefaultsToZeroOrigin() {
        let rect = ViewRect(size: ViewSize(width: 2, height: 1))
        #expect(rect.origin == .zero)
    }

    @Test func viewRectEquatableAndZero() {
        let a = ViewRect(origin: .zero, size: ViewSize(width: 1, height: 1))
        let b = ViewRect(size: ViewSize(width: 1, height: 1))
        let c = ViewRect(size: ViewSize(width: 1, height: 2))
        #expect(a == b)
        #expect(a != c)
        #expect(ViewRect.zero == ViewRect(origin: .zero, size: .zero))
    }
}

// MARK: - Leaves

@Suite("Allocation kernel — leaves")
struct LeafAllocationTests {

    /// A custom view whose body is a leaf: exercises the body-resolving default.
    private struct Label: View {
        let text: String
        var body: ViewOutput { ViewOutput(text) }
    }

    @Test func defaultEmbedResolvesThroughBody() {
        var buffer = CellBuffer(width: 4, height: 2)
        Label(text: "hi")._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: 1, row: 1), size: ViewSize(width: 3, height: 1))
        )
        #expect(embedRows(buffer) == ["", " hi"])
    }

    @Test func viewOutputAnchorsAtTheRectOrigin() {
        var buffer = CellBuffer(width: 6, height: 2)
        ViewOutput("hi")._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: 2, row: 1), size: ViewSize(width: 1, height: 1))
        )
        #expect(embedRows(buffer) == ["", "  hi"])
    }

    @Test func viewOutputIsNotStretchedToItsRect() {
        // A larger rect neither reflows nor pads: the raster renders at the
        // origin and the rest of the rect stays blank (decision 2).
        var buffer = CellBuffer(width: 8, height: 4)
        ViewOutput("ab")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 6, height: 3))
        )
        #expect(embedRows(buffer) == ["ab", "", "", ""])
        #expect(buffer[2, 0] == .empty)
        #expect(buffer[0, 1] == .empty)
    }

    @Test func textWrapsAtItsAllocatedWidth() {
        var buffer = CellBuffer(width: 5, height: 2)
        Text("hello world")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 5, height: 2))
        )
        #expect(embedRows(buffer) == ["hello", "world"])
    }

    @Test func textAllocatedWiderThanItsContentIsNotPadded() {
        var buffer = CellBuffer(width: 8, height: 2)
        Text("ab")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 8, height: 2))
        )
        #expect(embedRows(buffer) == ["ab", ""])
    }

    @Test func textTallerThanItsRectIsClippedByTheKernel() {
        // The leaf writes every row it measured, but the kernel clip installed
        // by `CellBuffer.embed` contains the paint to the 2×1 allocation.
        var buffer = CellBuffer(width: 2, height: 3)
        buffer.embed(
            Text("a\nb\nc"),
            at: ViewRect(size: ViewSize(width: 2, height: 1))
        )
        #expect(embedRows(buffer) == ["a", "", ""])
    }

    // MARK: Compression floor (decision 4)

    @Test func textCompressionFloorKeepsAWideCharacterIntact() {
        // Allocated 1 column, but the narrowest producible form of "你" is 2
        // columns wide. The floor clamps the wrap width to 2, so the character
        // is written whole instead of being dropped or split. (This test calls
        // `_embed` directly; through `CellBuffer.embed` the continuation
        // column would be clipped.)
        var buffer = CellBuffer(width: 4, height: 1)
        Text("你")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 1, height: 1))
        )
        #expect(buffer[0, 0].character == "你")
        #expect(buffer[1, 0].width == 0)  // wide-character continuation
        #expect(embedRows(buffer) == ["你"])
    }

    @Test func textZeroWidthAllocationUsesTheMinimumForm() {
        // A degenerate (zero-width) assignment is the A3 minimum rule applied
        // to allocation: wrap at the narrowest producible width.
        var buffer = CellBuffer(width: 4, height: 2)
        Text("你好")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 0, height: 2))
        )
        #expect(embedRows(buffer) == ["你", "好"])
    }

    @Test func textAsciiCompressionFloorIsOneColumn() {
        var buffer = CellBuffer(width: 2, height: 3)
        Text("abc")._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 1, height: 3))
        )
        #expect(embedRows(buffer) == ["a", "b", "c"])
    }

    @Test func textQueryAndAllocationAgreeOnNarrowMixedContent() {
        // Regression (PR #22 review): a positive width below the minimum
        // producible width used to resolve differently in the query (wrap at
        // the query width) and the allocation (wrap at the floor), so the report's
        // line count disagreed with the painted rows. One resolution rule now
        // serves both: "ab你" needs width 2, so at a query/rect of 1 it
        // reports AND paints the 2-column form.
        let text = Text("ab你")
        #expect(
            text._measure(in: AvailableSize(width: 1, height: nil)) == ViewSize(width: 2, height: 2)
        )
        var buffer = CellBuffer(width: 3, height: 2)
        text._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 1, height: 2)))
        #expect(embedRows(buffer) == ["ab", "你"])
    }

    // MARK: Blank leaves

    @Test func blankLeavesPaintNothing() {
        var buffer = CellBuffer(width: 4, height: 2)
        let rect = ViewRect(size: ViewSize(width: 4, height: 2))
        Spacer(lines: 1)._embed(into: &buffer, at: rect)
        Spacer()._embed(into: &buffer, at: rect)
        Fill()._embed(into: &buffer, at: rect)
        #expect(embedRows(buffer) == ["", ""])
    }

    @Test func emptyEmbedsNothing() {
        var buffer = CellBuffer(width: 2, height: 1)
        Empty()._embed(
            into: &buffer,
            at: ViewRect(size: ViewSize(width: 2, height: 1))
        )
        #expect(embedRows(buffer) == [""])
    }
}
