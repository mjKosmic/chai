import Testing
@testable import Chai

// MARK: - CellColor Tests

@Suite("CellColor")
struct CellColorTests {
    @Test func ansiColorSGRForeground() {
        #expect(CellColor.red.sgrParams(foreground: true) == "31")
        #expect(CellColor.green.sgrParams(foreground: true) == "32")
        #expect(CellColor.black.sgrParams(foreground: true) == "30")
        #expect(CellColor.white.sgrParams(foreground: true) == "37")
    }

    @Test func ansiColorSGRBackground() {
        #expect(CellColor.red.sgrParams(foreground: false) == "41")
        #expect(CellColor.blue.sgrParams(foreground: false) == "44")
    }

    @Test func brightColorSGR() {
        #expect(CellColor.brightRed.sgrParams(foreground: true) == "91")
        #expect(CellColor.brightCyan.sgrParams(foreground: false) == "106")
    }

    @Test func paletteColorSGR() {
        #expect(CellColor.palette(208).sgrParams(foreground: true) == "38;5;208")
        #expect(CellColor.palette(42).sgrParams(foreground: false) == "48;5;42")
    }

    @Test func rgbColorSGR() {
        #expect(CellColor.rgb(255, 0, 128).sgrParams(foreground: true) == "38;2;255;0;128")
        #expect(CellColor.rgb(0, 255, 0).sgrParams(foreground: false) == "48;2;0;255;0")
    }
}

// MARK: - Cell.Attributes Tests

@Suite("Cell.Attributes")
struct CellAttributesTests {
    @Test func singleAttribute() {
        #expect(Cell.Attributes.bold.sgrCodes == [1])
        #expect(Cell.Attributes.italic.sgrCodes == [3])
        #expect(Cell.Attributes.strikethrough.sgrCodes == [9])
    }

    @Test func combinedAttributes() {
        let attrs: Cell.Attributes = [.bold, .italic, .underline]
        #expect(attrs.sgrCodes == [1, 3, 4])
    }

    @Test func emptyAttributes() {
        let attrs: Cell.Attributes = []
        #expect(attrs.sgrCodes.isEmpty)
    }

    @Test func optionSetOperations() {
        var attrs: Cell.Attributes = [.bold]
        attrs.formUnion([.italic])
        #expect(attrs.contains(.bold))
        #expect(attrs.contains(.italic))
        #expect(!attrs.contains(.underline))
    }
}

// MARK: - TextAttributes Tests

@Suite("TextAttributes")
struct TextAttributesTests {
    @Test func defaultStyle() {
        let style = TextAttributes.default
        #expect(style.foreground == nil)
        #expect(style.background == nil)
        #expect(style.attributes == [])
        #expect(style.hyperlink == nil)
    }

    @Test func styleEquality() {
        let a = TextAttributes(foreground: .red, attributes: [.bold])
        let b = TextAttributes(foreground: .red, attributes: [.bold])
        #expect(a == b)
    }

    @Test func styleInequality() {
        let a = TextAttributes(foreground: .red)
        let b = TextAttributes(foreground: .blue)
        #expect(a != b)
    }
}

// MARK: - Cell Tests

@Suite("Cell")
struct CellTests {
    @Test func emptyCellDefaults() {
        let cell = Cell.empty
        #expect(cell.character == " ")
        #expect(cell.width == 1)
        #expect(cell.foreground == nil)
        #expect(cell.background == nil)
        #expect(cell.attributes == [])
        #expect(cell.hyperlink == nil)
        #expect(cell.layer == 0)
    }

    @Test func wideContinuation() {
        let cell = Cell.wideContinuation
        #expect(cell.width == 0)
    }

    @Test func renderPlainCell() {
        let cell = Cell(character: "A")
        #expect(cell.render() == "A")
    }

    @Test func renderStyledCell() {
        let cell = Cell(character: "X", foreground: .red)
        let rendered = cell.render()
        #expect(rendered.contains("31"))
        #expect(rendered.contains("X"))
        #expect(rendered.contains("\u{1B}[0m"))
    }

    @Test func renderBoldCell() {
        let cell = Cell(character: "B", attributes: [.bold])
        let rendered = cell.render()
        #expect(rendered.contains("1"))
        #expect(rendered.contains("B"))
    }

    @Test func renderMultipleAttributes() {
        let cell = Cell(character: "M", foreground: .green, attributes: [.bold, .italic])
        let rendered = cell.render()
        #expect(rendered.contains("32"))
        #expect(rendered.contains("1"))
        #expect(rendered.contains("3"))
    }

    @Test func renderContinuationCell() {
        let cell = Cell.wideContinuation
        #expect(cell.render() == "")
    }

    @Test func renderWithHyperlink() {
        let cell = Cell(character: "L", hyperlink: "https://example.com")
        let rendered = cell.render()
        #expect(rendered.contains("example.com"))
        #expect(rendered.contains("L"))
    }

    @Test func cellEquality() {
        let a = Cell(character: "A", foreground: .red)
        let b = Cell(character: "A", foreground: .red)
        #expect(a == b)
    }

    @Test func cellInequality() {
        let a = Cell(character: "A")
        let b = Cell(character: "B")
        #expect(a != b)
    }

    @Test func cellStyleInequality() {
        let a = Cell(character: "A", foreground: .red)
        let b = Cell(character: "A", foreground: .blue)
        #expect(a != b)
    }
}
