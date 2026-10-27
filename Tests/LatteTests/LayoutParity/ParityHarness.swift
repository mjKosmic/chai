import Chai
import Latte

// MARK: - Parity harness utilities
//
// The harness has one renderer: the allocation walk. These helpers define the
// comparison convention used by the corpus and the engine suites.
//
// Comparison semantics:
// - Buffers are compared as *visible row text*, not raw cells. Raw cell
//   equality is intentionally too strict: alignment writes space cells where
//   a leaf leaves cells `.empty` — both render identically under
//   `eraseLineRight`.
// - Zero-width cells (wide-character continuation cells, and any zero-width
//   cell such as a combining mark) contribute nothing to the extracted row;
//   a wide character (width 2) contributes exactly one character.
// - Trailing spaces are right-stripped from every row, and all-space rows
//   normalize to `""`.

/// Rasterize a view through the allocation engine (one allocation walk).
///
/// The root rect is `width` wide with the tree's reported height (`nil`
/// height = inline mode's content-sized buffer, matching the renderer's query
/// `(width, nil)`). The buffer height is `height ?? measured height`; an
/// explicit height only pads/limits the buffer, it does not change the root
/// assignment. Leaves anchor at their rect origin (no stretching), containers
/// clamp child rects to their own allocation, and the kernel clips every
/// `_embed` to its rect (hard-box contract).
///
/// The buffer's width is only a truncation bound — each view's **allocated**
/// rect drives placement (leaf writes use `wrapping: false` and clip at the
/// buffer width). This is why a VStack's content sits at the left of a wide
/// terminal rather than centering in it: the stack shrinks to its own max
/// width. `frame()` is the view that opts into terminal-width placement.
func embedBuffer(_ view: some View, width: Int, height: Int? = nil) -> CellBuffer {
    let measured = view._measure(in: AvailableSize(width: width, height: nil))
    var buffer = CellBuffer(width: width, height: height ?? measured.height)
    buffer.embed(
        view,
        at: ViewRect(origin: .zero, size: ViewSize(width: width, height: measured.height))
    )
    return buffer
}

/// Extract per-row visible text from a buffer using the comparison semantics
/// described above.
///
/// - Zero-width cells are skipped: wide-character continuation cells
///   (`Cell.width == 0` placed by ``CellBuffer/set(col:row:_:)`` after a
///   width-2 primary) and any hand-built zero-width cell (e.g. a combining
///   mark) do not contribute. A width-2 primary contributes its character
///   exactly once — the wide character is never doubled.
/// - Trailing ASCII spaces are right-stripped; all-space rows become `""`.
///   `.empty` cells are space cells (``Cell.empty`` is `Cell(character: " ")`),
///   so alignment padding is invisible here.
func visibleRows(_ buffer: CellBuffer) -> [String] {
    var rows: [String] = []
    for row in 0..<buffer.height {
        var line = ""
        for col in 0..<buffer.width {
            let cell = buffer[col, row]
            // Skip zero-width cells: wide-char continuations and combining
            // marks. Wide cells (width 2) contribute their character once.
            if cell.width == 0 { continue }
            line.append(cell.character)
        }
        rows.append(rstripSpaces(line))
    }
    return rows
}

/// Right-strip ASCII space characters. An all-space row becomes `""`.
private func rstripSpaces(_ string: String) -> String {
    var end = string.endIndex
    while end > string.startIndex {
        let prev = string.index(before: end)
        if string[prev] != " " { break }
        end = prev
    }
    return String(string[..<end])
}
