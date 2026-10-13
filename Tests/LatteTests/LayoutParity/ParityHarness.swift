import Chai
import Latte

// MARK: - M0 parity harness utilities
//
// These utilities implement the *today* (eager) rendering path as a mechanical
// spec, so that Milestone M2's layout engine can be verified against it.
//
// Parity comparison semantics (UPGRADE.md, "Spec & parity strategy"):
// - Buffers are compared as *visible row text*, not raw cells. Raw cell
//   equality is intentionally too strict: eager line alignment writes space
//   cells where the engine leaves cells `.empty` — both render identically
//   under `eraseLineRight` (allowed divergence #2).
// - Zero-width cells (wide-character continuation cells, and any zero-width
//   cell such as a combining mark) contribute nothing to the extracted row;
//   a wide character (width 2) contributes exactly one character.
// - Trailing spaces are right-stripped from every row, and all-space rows
//   normalize to `""`.

/// Rasterize a view through the *today* eager path: resolve the tree to a
/// ``ViewOutput`` via `_resolveToViewOutput()` and rasterize the resulting
/// styled text with the public ``layout(_:width:height:wrapping:)`` function.
///
/// The buffer height is derived from `content.lineCount()` (matching inline
/// mode rendering, where wrapping is disabled so wide lines truncate instead
/// of stealing rows) unless an explicit height is passed.
func eagerBuffer(
    _ view: some View,
    width: Int,
    wrapping: Bool = false,
    height: Int? = nil
) -> CellBuffer {
    let output = view._resolveToViewOutput()
    let h = height ?? output.content.lineCount()
    return layout(output.content, width: width, height: h, wrapping: wrapping)
}

/// Rasterize a view through the *engine* path: measure with the proposal
/// `(width, nil)`, render into a buffer at the measured size with the SAME
/// fit proposal (A0) — the fit/render value-equality contract, so
/// proposal-consuming children (the test-local `ProposalEchoView`) see the
/// fit proposal at render time.
///
/// The buffer's width is only a truncation bound — the view's **measured**
/// size drives placement (leaf writes use `wrapping: false` and clip at the
/// buffer width, matching `eagerBuffer`). This is why eager VStack content
/// sits at the left of a wide terminal rather than centering in it: the stack
/// pads to its own max width. `frame()` (M4) is the view that lets users opt
/// into terminal-width placement.
func engineBuffer(_ view: some View, width: Int, height: Int? = nil) -> CellBuffer {
    let proposal = ProposedSize(width: width, height: nil)
    let size = view._sizeThatFits(proposal)
    var buffer = CellBuffer(width: width, height: height ?? size.height)
    view._render(into: &buffer, at: .zero, size: size, proposal: proposal)
    return buffer
}

/// Extract per-row visible text from a buffer using the parity comparison
/// semantics described above.
///
/// - Zero-width cells are skipped: wide-character continuation cells
///   (`Cell.width == 0` placed by ``CellBuffer/set(col:row:_:)`` after a
///   width-2 primary) and any hand-built zero-width cell (e.g. a combining
///   mark) do not contribute. A width-2 primary contributes its character
///   exactly once — the wide character is never doubled.
/// - Trailing ASCII spaces are right-stripped; all-space rows become `""`.
///   `.empty` cells are space cells (``Cell.empty`` is `Cell(character: " ")`),
///   so alignment padding written by the eager path is invisible here — this
///   is exactly what makes allowed divergence #2 moot at the visible-row level.
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