import Testing
import Chai

// MARK: - Styling modifiers

@Suite("View styling")
struct StyledViewTests {

    // MARK: Leaf

    @Test func leafBold() {
        let buffer = embedBuffer(Text("x").bold(), width: 4)
        #expect(visibleRows(buffer) == ["x"])
        #expect(buffer[0, 0].attributes.contains(.bold))
    }

    @Test func leafForeground() {
        let buffer = embedBuffer(Text("x").fg(.green), width: 4)
        #expect(buffer[0, 0].foreground == .green)
    }

    @Test func leafBackground() {
        let buffer = embedBuffer(Text("x").bg(.blue), width: 4)
        #expect(buffer[0, 0].background == .blue)
    }

    // MARK: Container

    @Test func containerForegroundReachesEveryChild() {
        let view = HStack {
            Text("a")
            Text("b")
        }
        .fg(.red)

        let buffer = embedBuffer(view, width: 8)
        #expect(visibleRows(buffer) == ["ab"])
        #expect(buffer[0, 0].foreground == .red)
        #expect(buffer[1, 0].foreground == .red)
    }

    // MARK: Wrappers

    @Test func paddingWrapperForegroundCoversInsetsAndContent() {
        let buffer = embedBuffer(Text("a").padded(1).fg(.red), width: 8)
        #expect(visibleRows(buffer) == ["", " a", ""])
        for row in 0..<3 {
            for col in 0..<3 {
                #expect(buffer[col, row].foreground == .red)
            }
        }
    }

    @Test func borderWrapperForegroundCoversFrameAndContent() {
        let buffer = embedBuffer(Text("a").bordered(.ascii).fg(.red), width: 8)
        #expect(visibleRows(buffer) == ["+-+", "|a|", "+-+"])
        for row in 0..<3 {
            for col in 0..<3 {
                #expect(buffer[col, row].foreground == .red)
            }
        }
    }

    // MARK: Composition

    @Test func innerColorWins() {
        let buffer = embedBuffer(Text("x").fg(.blue).fg(.red), width: 4)
        #expect(buffer[0, 0].foreground == .blue)
    }

    @Test func outerFillsUnsetProperties() {
        let buffer = embedBuffer(Text("x").bold().fg(.red), width: 4)
        #expect(buffer[0, 0].foreground == .red)
        #expect(buffer[0, 0].attributes.contains(.bold))
    }

    @Test func attributesAccumulateAcrossNesting() {
        let buffer = embedBuffer(Text("x").underline().bold(), width: 4)
        #expect(buffer[0, 0].attributes.contains(.bold))
        #expect(buffer[0, 0].attributes.contains(.underline))
    }

    @Test func innerAttributeSurvivesOuterColor() {
        let buffer = embedBuffer(Text("x").underline().fg(.red), width: 4)
        #expect(buffer[0, 0].foreground == .red)
        #expect(buffer[0, 0].attributes.contains(.underline))
    }

    // MARK: Background coverage

    @Test func backgroundCoversInternalSpaces() {
        let buffer = embedBuffer(Text("a b").bg(.blue), width: 6)
        #expect(visibleRows(buffer) == ["a b"])
        for col in 0..<3 {
            #expect(buffer[col, 0].background == .blue)
        }
    }

    @Test func containerBackgroundCoversInterChildGaps() {
        let view = VStack {
            Text("abc")
            Text("de")
        }
        .bg(.blue)

        let buffer = embedBuffer(view, width: 8)
        #expect(visibleRows(buffer) == ["abc", "de"])
        // Occupied width is the widest child (3), so the cell right of "de"
        // inside the occupied rect is a gap cell and carries the background.
        for row in 0..<2 {
            for col in 0..<3 {
                #expect(buffer[col, row].background == .blue)
            }
        }
        #expect(buffer[3, 0].background == nil)
        #expect(buffer[3, 1].background == nil)
    }

    @Test func backgroundStaysInsideOccupiedRect() {
        var buffer = CellBuffer(width: 10, height: 1)
        buffer.embed(
            Text("ab").bg(.blue),
            at: ViewRect(origin: .zero, size: ViewSize(width: 10, height: 1))
        )
        #expect(buffer[0, 0].background == .blue)
        #expect(buffer[1, 0].background == .blue)
        #expect(buffer[2, 0].background == nil)
        #expect(buffer[9, 0].background == nil)
    }

    @Test func backgroundFillsAFillView() {
        // `Fill` reports the assignment, so a background on it covers the box.
        var buffer = CellBuffer(width: 5, height: 2)
        buffer.embed(
            Fill().bg(.blue),
            at: ViewRect(origin: .zero, size: ViewSize(width: 5, height: 2))
        )
        for row in 0..<2 {
            for col in 0..<5 {
                #expect(buffer[col, row].background == .blue)
            }
        }
    }
}

// MARK: - Layout invariance

@Suite("View styling — layout invariance")
struct StyledViewLayoutTests {

    private let content = "The quick brown fox jumps"

    @Test func measurementIsUnchanged() {
        let plain = Text(content)
        let styled = Text(content).fg(.red).bold().underline()
        let queries: [AvailableSize] = [
            .unconstrained,
            .zero,
            AvailableSize(width: 5, height: nil),
            AvailableSize(width: 12, height: nil),
            AvailableSize(width: nil, height: 3),
        ]
        for query in queries {
            #expect(plain._measure(in: query) == styled._measure(in: query))
        }
    }

    @Test func narrowWrappingIsUnchanged() {
        var plain = CellBuffer(width: 6, height: 20)
        plain.embed(
            Text(content),
            at: ViewRect(origin: .zero, size: ViewSize(width: 6, height: 20))
        )

        var styled = CellBuffer(width: 6, height: 20)
        styled.embed(
            Text(content).fg(.red).italic().bg(.blue),
            at: ViewRect(origin: .zero, size: ViewSize(width: 6, height: 20))
        )

        #expect(visibleRows(plain) == visibleRows(styled))
        let paintedRows = visibleRows(plain).filter { !$0.isEmpty }.count
        #expect(paintedRows == Text(content)._measure(in: AvailableSize(width: 6, height: nil)).height)
    }

    @Test func backgroundAddsNoRowsOrColumns() {
        let plain = Text("abc")
        let styled = Text("abc").bg(.blue)
        #expect(plain._measure(in: .unconstrained) == styled._measure(in: .unconstrained))
        #expect(
            plain._measure(in: AvailableSize(width: 2, height: nil))
                == styled._measure(in: AvailableSize(width: 2, height: nil))
        )
    }

    @Test func stylingPreservesFlexibility() {
        let plain = HStack {
            Text("a")
            Spacer()
            Text("b")
        }
        let styled = HStack {
            Text("a")
            Spacer()
            Text("b")
        }
        .fg(.red)

        #expect(plain._measure(in: AvailableSize(width: 10, height: nil))
            == styled._measure(in: AvailableSize(width: 10, height: nil)))
        #expect(visibleRows(embedBuffer(plain, width: 10)) == ["a        b"])
        #expect(visibleRows(embedBuffer(styled, width: 10)) == ["a        b"])
    }
}
