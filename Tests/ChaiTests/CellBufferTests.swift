import Testing
@testable import Chai

@Suite("CellBuffer")
struct CellBufferTests {

    // MARK: - Initialization

    @Test func emptyBuffer() {
        let buf = CellBuffer(width: 0, height: 0)
        #expect(buf.width == 0)
        #expect(buf.height == 0)
    }

    @Test func filledBuffer() {
        let buf = CellBuffer(width: 5, height: 3)
        #expect(buf.width == 5)
        #expect(buf.height == 3)
        #expect(buf[0, 0] == .empty)
        #expect(buf[4, 2] == .empty)
    }

    // MARK: - Subscript

    @Test func subscriptOutOfBounds() {
        let buf = CellBuffer(width: 5, height: 3)
        #expect(buf[-1, 0] == .empty)
        #expect(buf[0, -1] == .empty)
        #expect(buf[5, 0] == .empty)
        #expect(buf[0, 3] == .empty)
    }

    @Test func subscriptInBounds() {
        var buf = CellBuffer(width: 5, height: 3)
        let cell = Cell(character: "A")
        buf.set(col: 2, row: 1, cell)
        #expect(buf[2, 1].character == "A")
    }

    // MARK: - Wide character invariants

    @Test func setWideCharCreatesContination() {
        var buf = CellBuffer(width: 10, height: 1)
        let cell = Cell(character: "你", width: 2, foreground: .red)
        buf.set(col: 0, row: 0, cell)
        #expect(buf[0, 0].character == "你")
        #expect(buf[0, 0].width == 2)
        #expect(buf[1, 0].width == 0)  // continuation
    }

    @Test func overwriteWidePrimaryWithNarrow() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "你", width: 2))
        // Now overwrite the primary with a narrow cell
        buf.set(col: 0, row: 0, Cell(character: "A"))
        #expect(buf[0, 0].character == "A")
        #expect(buf[0, 0].width == 1)
        #expect(buf[1, 0] == .empty)  // continuation cleared
    }

    @Test func overwriteContinuationWithNarrow() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "你", width: 2))
        // Now overwrite the continuation with a narrow cell
        buf.set(col: 1, row: 0, Cell(character: "X"))
        #expect(buf[0, 0] == .empty)  // primary cleared
        #expect(buf[1, 0].character == "X")
        #expect(buf[1, 0].width == 1)
    }

    @Test func wideCharAtLastColumn() {
        var buf = CellBuffer(width: 5, height: 1)
        // Try to place wide char at column 4 (last column, no room for continuation)
        buf.set(col: 4, row: 0, Cell(character: "你", width: 2))
        // Should clip to empty
        #expect(buf[4, 0] == .empty)
    }

    @Test func wideCharAtSecondToLastColumn() {
        var buf = CellBuffer(width: 5, height: 1)
        buf.set(col: 3, row: 0, Cell(character: "你", width: 2))
        #expect(buf[3, 0].character == "你")
        #expect(buf[3, 0].width == 2)
        #expect(buf[4, 0].width == 0)  // continuation fits
    }

    @Test func overwriteWideWithWide() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "你", width: 2))
        buf.set(col: 0, row: 0, Cell(character: "好", width: 2))
        #expect(buf[0, 0].character == "好")
        #expect(buf[0, 0].width == 2)
        #expect(buf[1, 0].width == 0)
    }

    @Test func overwriteContinuationWithWide() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.set(col: 0, row: 0, Cell(character: "你", width: 2))
        // Place a wide char starting at the continuation position
        buf.set(col: 1, row: 0, Cell(character: "好", width: 2))
        #expect(buf[0, 0] == .empty)  // old primary cleared
        #expect(buf[1, 0].character == "好")
        #expect(buf[1, 0].width == 2)
        #expect(buf[2, 0].width == 0)  // new continuation
    }

    // MARK: - Write (layout)

    @Test func writePlainText() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.write(StyledText("Hello"))
        #expect(buf[0, 0].character == "H")
        #expect(buf[1, 0].character == "e")
        #expect(buf[4, 0].character == "o")
        #expect(buf[5, 0] == .empty)
    }

    @Test func writeMultiline() {
        var buf = CellBuffer(width: 10, height: 3)
        buf.write(StyledText("A\nB\nC"))
        #expect(buf[0, 0].character == "A")
        #expect(buf[0, 1].character == "B")
        #expect(buf[0, 2].character == "C")
    }

    @Test func writeClipsAtHeight() {
        var buf = CellBuffer(width: 10, height: 2)
        buf.write(StyledText("A\nB\nC\nD"))
        #expect(buf[0, 0].character == "A")
        #expect(buf[0, 1].character == "B")
        // C and D clipped
    }

    @Test func writeWithWideChars() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.write(StyledText("你好"))
        #expect(buf[0, 0].character == "你")
        #expect(buf[0, 0].width == 2)
        #expect(buf[1, 0].width == 0)  // continuation
        #expect(buf[2, 0].character == "好")
        #expect(buf[2, 0].width == 2)
        #expect(buf[3, 0].width == 0)  // continuation
    }

    @Test func writeWrapsWideCharAtLineEnd() {
        var buf = CellBuffer(width: 5, height: 2)
        buf.write(StyledText("ABCD你"))
        // "ABCD" fills cols 0-3. "你" needs 2 cols, only 1 left, so wraps.
        #expect(buf[0, 0].character == "A")
        #expect(buf[3, 0].character == "D")
        #expect(buf[4, 0] == .empty)  // gap at end of line
        #expect(buf[0, 1].character == "你")
        #expect(buf[0, 1].width == 2)
    }

    @Test func writeStyledText() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.write("Hello".fg(.red))
        #expect(buf[0, 0].foreground == .red)
        #expect(buf[4, 0].foreground == .red)
        #expect(buf[5, 0].foreground == nil)
    }

    @Test func writeEmptyText() {
        var buf = CellBuffer(width: 10, height: 1)
        buf.write(StyledText())
        #expect(buf[0, 0] == .empty)
    }

    // MARK: - Resize and clear

    @Test func resize() {
        var buf = CellBuffer(width: 10, height: 5)
        buf.write(StyledText("Hello"))
        buf.resize(width: 3, height: 2)
        #expect(buf.width == 3)
        #expect(buf.height == 2)
        #expect(buf[0, 0] == .empty)  // content cleared
    }

    @Test func clear() {
        var buf = CellBuffer(width: 5, height: 1)
        buf.write(StyledText("Hello"))
        buf.clear()
        #expect(buf[0, 0] == .empty)
        #expect(buf[4, 0] == .empty)
    }

    // MARK: - Diff

    @Test func diffIdentical() {
        let a = layout("Hello", width: 10, height: 1)
        let b = layout("Hello", width: 10, height: 1)
        let diff = b.diff(against: a)
        #expect(diff.changes.isEmpty)
        #expect(!diff.eraseBelow)
    }

    @Test func diffSingleChange() {
        let old = layout("Hello", width: 10, height: 1)
        let new = layout("Hallo", width: 10, height: 1)
        let diff = new.diff(against: old)
        // Only position 1 should differ (e -> a)
        #expect(diff.changes.count == 1)
        #expect(diff.changes[0].col == 1)
        #expect(diff.changes[0].row == 0)
    }

    @Test func diffCompleteChange() {
        let old = layout("AAAAA", width: 5, height: 1)
        let new = layout("BBBBB", width: 5, height: 1)
        let diff = new.diff(against: old)
        #expect(diff.changes.count == 5)
    }

    @Test func diffStyleChange() {
        let old = layout("Hello", width: 10, height: 1)
        let new = layout("Hello".fg(.red), width: 10, height: 1)
        let diff = new.diff(against: old)
        #expect(diff.changes.count == 5)  // all cells changed (style differs)
    }

    @Test func diffOldTaller() {
        let old = layout("A\nB\nC", width: 10, height: 3)
        let new = layout("A", width: 10, height: 1)
        let diff = new.diff(against: old)
        #expect(diff.eraseBelow)
    }

    @Test func diffNewTaller() {
        let old = layout("A", width: 10, height: 1)
        let new = layout("A\nB\nC", width: 10, height: 3)
        let diff = new.diff(against: old)
        #expect(!diff.eraseBelow)
        // B and C rows should be in changes
        let rowChanges = Set(diff.changes.map(\.row))
        #expect(rowChanges.contains(1))
        #expect(rowChanges.contains(2))
    }

    @Test func diffEmptyBuffers() {
        let a = CellBuffer(width: 10, height: 5)
        let b = CellBuffer(width: 10, height: 5)
        let diff = b.diff(against: a)
        #expect(diff.changes.isEmpty)
    }

    @Test func diffAgainstZeroSizeBuffer() {
        let old = CellBuffer(width: 0, height: 0)
        let new = layout("Hi", width: 10, height: 1)
        let diff = new.diff(against: old)
        // All non-empty cells should be changes
        #expect(!diff.changes.isEmpty)
    }

    // MARK: - Layout function

    @Test func layoutFunction() {
        let buf = layout("AB", width: 10, height: 1)
        #expect(buf[0, 0].character == "A")
        #expect(buf[1, 0].character == "B")
    }

    @Test func layoutEmptyText() {
        let buf = layout(StyledText(), width: 10, height: 1)
        #expect(buf[0, 0] == .empty)
    }
}
