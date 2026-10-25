import Chai

// MARK: - Engine rendering helpers (test-local)
//
// Phase 4 P4b retired `View._resolveToViewOutput()`, so structural/engine
// tests render through the allocation walk and inspect the resulting cells.

/// Render `view` through the allocation engine at `width` and extract its
/// visible rows, using the parity convention: zero-width cells (wide-character
/// continuations and combining marks) are skipped, and trailing spaces are
/// stripped.
///
/// The root rect is `width` wide and as tall as the view's query report
/// (inline-mode rendering); rows beyond that report are not painted.
func engineRows(_ view: some View, width: Int = 80) -> [String] {
    let size = view._measure(in: AvailableSize(width: width, height: nil))
    var buffer = CellBuffer(width: width, height: size.height)
    buffer.embed(
        view,
        at: ViewRect(origin: .zero, size: ViewSize(width: width, height: size.height))
    )

    var rows: [String] = []
    for row in 0..<buffer.height {
        var line = ""
        for col in 0..<buffer.width {
            let cell = buffer[col, row]
            if cell.width == 0 { continue }
            line.append(cell.character)
        }
        while line.last == " " { line.removeLast() }
        rows.append(line)
    }
    return rows
}

/// ``engineRows(_:width:)`` joined with newlines.
func engineText(_ view: some View, width: Int = 80) -> String {
    engineRows(view, width: width).joined(separator: "\n")
}
