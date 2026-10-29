import Testing
import Chai

// MARK: - Parity harness utility tests
//
// These pin the comparison semantics the engine spec relies on: zero-width
// cell skipping (wide-char continuations and combining marks), wide cells
// counting as one character, and trailing-space normalization.

@Suite("Layout Parity — visibleRows semantics")
struct VisibleRowsTests {

    @Test("wide char extracts once, continuation cell skipped")
    func wideCharExtractsOnce() {
        var buf = CellBuffer(width: 4, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "你", width: 2))
        buf.set(col: 2, row: 0, Cell(character: "A"))
        // Column 1 is the auto-created continuation (width 0); column 3 is
        // `.empty` (a space cell) which right-strips away.
        #expect(visibleRows(buf) == ["你A"])
    }

    @Test("adjacent wide chars extract as two characters")
    func adjacentWideChars() {
        var buf = CellBuffer(width: 4, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "你", width: 2))
        buf.set(col: 2, row: 0, Cell(character: "好", width: 2))
        #expect(visibleRows(buf) == ["你好"])
    }

    @Test("space-only row normalizes to empty string")
    func spaceOnlyRowNormalizesToEmpty() {
        // A row of `.empty` cells is a row of space characters (Cell.empty is
        // Cell(character: " ")) → normalization yields "".
        let buf = CellBuffer(width: 5, height: 2)
        #expect(visibleRows(buf) == ["", ""])
    }

    @Test("trailing spaces stripped, interior spaces preserved")
    func trailingSpacesStripped() {
        let buf = layout("a b", width: 6, height: 1)
        // "a b" occupies 3 columns; columns 3–5 are spaces (empty cells).
        #expect(visibleRows(buf) == ["a b"])
    }

    @Test("padding spaces after content stripped")
    func paddingSpacesStripped() {
        var buf = CellBuffer(width: 6, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "a"))
        buf.set(col: 1, row: 0, Cell(character: "b"))
        // Columns 2–5 are space cells (alignment padding analog).
        #expect(visibleRows(buf) == ["ab"])
    }

    @Test("hand-built zero-width combining mark is skipped")
    func combiningMarkSkipped() {
        var buf = CellBuffer(width: 3, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "e"))
        buf.set(col: 1, row: 0, Cell(character: "\u{301}", width: 0)) // combining acute
        buf.set(col: 2, row: 0, Cell(character: "x"))
        #expect(visibleRows(buf) == ["ex"])
    }

    @Test("multiline buffer extracts one row per buffer row")
    func multilineBuffer() {
        let buf = layout("a\nb\nc", width: 4, height: 3)
        #expect(visibleRows(buf) == ["a", "b", "c"])
    }

    @Test("empty buffer yields no rows")
    func emptyBufferYieldsNoRows() {
        let buf = CellBuffer(width: 0, height: 0)
        #expect(visibleRows(buf) == [])
    }
}

@Suite("Layout Parity — embedBuffer behavior")
struct EmbedBufferTests {

    @Test("height derives from the view's query report")
    func heightDerivesFromReport() {
        let buf = embedBuffer(
            VStack {
                Text("a")
                Text("b")
            },
            width: 4
        )
        #expect(buf.width == 4)
        #expect(buf.height == 2)
        #expect(visibleRows(buf) == ["a", "b"])
    }

    @Test("explicit height overrides the report")
    func explicitHeightOverridesReport() {
        let buf = embedBuffer(VStack { Text("a") }, width: 4, height: 3)
        #expect(buf.height == 3)
        #expect(visibleRows(buf) == ["a", "", ""])
    }

    @Test("viewoutput root renders as a leaf")
    func viewOutputRootRenders() {
        let buf = embedBuffer(ViewOutput("hi"), width: 4)
        #expect(visibleRows(buf) == ["hi"])
    }

    @Test("inline mode truncates at the buffer edge")
    func inlineModeTruncates() {
        let buf = embedBuffer(ViewOutput("abcdef"), width: 4)
        #expect(buf.height == 1)
        #expect(visibleRows(buf) == ["abcd"])
    }
}
