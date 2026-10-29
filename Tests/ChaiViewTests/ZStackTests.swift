import Testing
import Chai

// MARK: - ZStack public behavior
//
// Public-surface scenarios: styling, modifier composition, background
// ordering, custom children, and use as a model body. Exact measurement,
// alignment, and rect assertions live in `ZStackEngineTests`.

@Suite("ZStack")
struct ZStackTests {

    @Test func stylingCoversTheOccupiedBox() {
        let buffer = embedBuffer(
            ZStack {
                Text("a")
                Text("bb")
            }.bg(.red),
            width: 6
        )
        // The style covers the stack's 2×1 occupied box, not the 6-column
        // root assignment.
        #expect(buffer[0, 0].background == .red)
        #expect(buffer[1, 0].background == .red)
        #expect(buffer[2, 0].background == nil)
        #expect(visibleRows(buffer) == ["bb"])
    }

    @Test func backgroundPaintedBeforeContentLeavesHoles() {
        let buffer = embedBuffer(
            ZStack(alignment: .topLeft) {
                Fill().bg(.red)
                Text("a b")
            },
            width: 4
        )
        // A later leaf replaces earlier cells entirely, including their
        // background: the glyph and space cells have no background, and only
        // the cell the text does not cover stays red.
        #expect(buffer[0, 0].background == nil)
        #expect(buffer[1, 0].background == nil)
        #expect(buffer[2, 0].background == nil)
        #expect(buffer[3, 0].background == .red)
        #expect(visibleRows(buffer) == ["a b"])
    }

    @Test func backgroundPaintedAfterContentCoversCells() {
        let buffer = embedBuffer(
            ZStack(alignment: .topLeft) {
                Text("a b")
                Fill().bg(.red)
            },
            width: 4
        )
        // A styled background painted last merges into the cells the content
        // already painted, so the whole occupied box is covered.
        #expect(buffer[0, 0].background == .red)
        #expect(buffer[1, 0].background == .red)
        #expect(buffer[2, 0].background == .red)
        #expect(buffer[3, 0].background == .red)
        #expect(visibleRows(buffer) == ["a b"])
    }

    @Test func borderedComposition() {
        let buffer = embedBuffer(
            ZStack {
                Text("a")
                Text("bb")
            }.bordered(.ascii),
            width: 8
        )
        #expect(visibleRows(buffer) == ["+--+", "|bb|", "+--+"])
    }

    @Test func paddedComposition() {
        let buffer = embedBuffer(
            ZStack {
                Text("a")
                Text("bb")
            }.padded(1),
            width: 8
        )
        #expect(visibleRows(buffer) == ["", " bb", ""])
    }

    @Test func frameCompositionCentersTheStack() {
        let buffer = embedBuffer(
            ZStack {
                Text("a")
                Text("bb")
            }.frame(
                width: 6,
                height: 3,
                horizontalAlignment: .center,
                verticalAlignment: .middle
            ),
            width: 6
        )
        #expect(visibleRows(buffer) == ["", "  bb", ""])
    }

    @Test func customChildCannotPaintOutsideItsRect() {
        let buffer = embedBuffer(
            ZStack { RoguePainter() },
            width: 4
        )
        // The child reports 1×1 and tries to write four columns; the hard-box
        // clip keeps only the first cell.
        #expect(visibleRows(buffer) == ["X"])
    }

    @Test func worksAsAModelBody() {
        let buffer = embedBuffer(ZStackModel(), width: 4)
        #expect(visibleRows(buffer) == ["bbaa"])
    }
}

// MARK: - Test helpers

/// A test-local child that ignores its rect when painting.
private struct RoguePainter: View {
    func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: 1, height: 1)
    }

    func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        buffer.write(
            StyledText("XXXX"),
            at: rect.origin.col,
            row: rect.origin.row
        )
    }
}

/// A model whose whole body is an overlay stack.
private struct ZStackModel: Model {
    func initialize() -> Command? { nil }

    mutating func update(_ msg: any Message) -> Command? { nil }

    var body: some View {
        ZStack(alignment: .topLeft) {
            Text("aaaa")
            Text("bb")
        }
    }
}
