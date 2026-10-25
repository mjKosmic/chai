import Testing
import Chai

// MARK: - Hard-box kernel clip (Chai)
//
// `CellBuffer.embed(_:at:)` installs the hard-box scissor: the active clip
// becomes the intersection of the previous clip and the child's rect, every
// write in the subtree is bounded by it, and the previous clip is restored on
// exit. These tests pin the kernel directly; Latte's `HardBoxTests` pins the
// container-level contract built on it.
//
// Expectations were derived by running the code, never hand-computed.

/// Visible-row extraction (same convention as the parity harness: zero-width
/// cells skipped, trailing spaces stripped).
private func clipRows(_ buffer: CellBuffer) -> [String] {
    (0..<buffer.height).map { row in
        var line = ""
        for col in 0..<buffer.width {
            let cell = buffer[col, row]
            if cell.width == 0 { continue }
            line.append(cell.character)
        }
        while line.hasSuffix(" ") { line.removeLast() }
        return line
    }
}

/// A view whose paint step is supplied by the test, so each test can exercise
/// a different `CellBuffer` mutation under the kernel clip.
private struct Probe: View {
    var report = ViewSize(width: 1, height: 1)
    let paint: @Sendable (inout CellBuffer, ViewRect) -> Void

    func _measure(in available: AvailableSize) -> ViewSize { report }

    func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        paint(&buffer, rect)
    }
}

@Suite("CellBuffer hard-box clip")
struct CellBufferClipTests {

    @Test func embedClipsWritesToItsRect() {
        var buffer = CellBuffer(width: 5, height: 2)
        buffer.embed(
            ViewOutput("XXXXX"),
            at: ViewRect(
                origin: ViewOrigin(col: 1, row: 0),
                size: ViewSize(width: 2, height: 1)
            )
        )
        // The raster starts at col 1; the 2×1 clip drops the rest.
        #expect(clipRows(buffer) == [" XX", ""])
    }

    @Test func multiLineWriteIsClippedOnBothAxes() {
        var buffer = CellBuffer(width: 4, height: 3)
        buffer.embed(
            ViewOutput("abcd\nefgh"),
            at: ViewRect(size: ViewSize(width: 2, height: 1))
        )
        #expect(clipRows(buffer) == ["ab", "", ""])
    }

    @Test func nestedEmbedsIntersectTheirClips() {
        let inner = ViewOutput("XXXXX")
        let outer = Probe(report: ViewSize(width: 4, height: 1)) { buffer, rect in
            buffer.embed(
                inner,
                at: ViewRect(
                    origin: ViewOrigin(col: rect.origin.col + 2, row: rect.origin.row),
                    size: ViewSize(width: 4, height: 1)
                )
            )
        }
        var buffer = CellBuffer(width: 6, height: 1)
        buffer.embed(outer, at: ViewRect(size: ViewSize(width: 4, height: 1)))
        // The inner rect (2..6) intersected with the outer clip (0..4) is
        // columns 2–3, not the inner rect's full 4 columns.
        #expect(clipRows(buffer) == ["  XX"])
    }

    @Test func clipRestoresForSiblings() {
        let kids = Probe(report: ViewSize(width: 5, height: 1)) { buffer, rect in
            buffer.embed(
                ViewOutput("XXXXX"),
                at: ViewRect(origin: rect.origin, size: ViewSize(width: 2, height: 1))
            )
            buffer.embed(
                ViewOutput("YYY"),
                at: ViewRect(
                    origin: ViewOrigin(col: rect.origin.col + 2, row: rect.origin.row),
                    size: ViewSize(width: 3, height: 1)
                )
            )
        }
        var buffer = CellBuffer(width: 5, height: 1)
        buffer.embed(kids, at: ViewRect(size: ViewSize(width: 5, height: 1)))
        // The first child's 2-column clip must not poison the second child.
        #expect(clipRows(buffer) == ["XXYYY"])
    }

    @Test func wideCharacterStraddlingTheClipEdgeIsDropped() {
        var buffer = CellBuffer(width: 4, height: 1)
        buffer.embed(
            ViewOutput("你"),
            at: ViewRect(size: ViewSize(width: 1, height: 1))
        )
        // A 2-column glyph cannot fit a 1-column clip; it is dropped whole
        // rather than split into a primary without its continuation.
        #expect(buffer[0, 0] == .empty)
        #expect(clipRows(buffer) == [""])
    }

    @Test func clipOutsideTheBufferPaintsNothing() {
        var buffer = CellBuffer(width: 3, height: 1)
        buffer.embed(
            ViewOutput("X"),
            at: ViewRect(
                origin: ViewOrigin(col: 5, row: 0),
                size: ViewSize(width: 2, height: 1)
            )
        )
        #expect(clipRows(buffer) == [""])
    }

    // MARK: Geometry mutation cannot escape the clip

    @Test func resizeInsideAnEmbedPreservesTheActiveClip() {
        let resizer = Probe(report: ViewSize(width: 2, height: 1)) { buffer, _ in
            buffer.resize(width: 10, height: 2)
            buffer.write(StyledText("XXXXXXXX"), at: 0, row: 0)
        }
        var buffer = CellBuffer(width: 5, height: 1)
        buffer.embed(resizer, at: ViewRect(size: ViewSize(width: 2, height: 1)))
        #expect(buffer.width == 10)
        #expect(clipRows(buffer) == ["XX", ""])
    }

    @Test func clearInsideAnEmbedPreservesTheActiveClip() {
        let clearer = Probe(report: ViewSize(width: 2, height: 1)) { buffer, _ in
            buffer.clear()
            buffer.write(StyledText("XXXX"), at: 0, row: 0)
        }
        var buffer = CellBuffer(width: 4, height: 1)
        buffer.embed(clearer, at: ViewRect(size: ViewSize(width: 2, height: 1)))
        #expect(clipRows(buffer) == ["XX"])
    }
}
