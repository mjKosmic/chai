import Testing
import Chai

@Suite("Border")
struct BorderTests {

    // MARK: - Preset values

    @Test func normalBorderCharacters() {
        let b = Border.normal
        #expect(b.top == "─")
        #expect(b.bottom == "─")
        #expect(b.left == "│")
        #expect(b.right == "│")
        #expect(b.topLeft == "┌")
        #expect(b.topRight == "┐")
        #expect(b.bottomLeft == "└")
        #expect(b.bottomRight == "┘")
    }

    @Test func roundedBorderCharacters() {
        let b = Border.rounded
        #expect(b.topLeft == "╭")
        #expect(b.topRight == "╮")
        #expect(b.bottomLeft == "╰")
        #expect(b.bottomRight == "╯")
        #expect(b.top == "─")
    }

    @Test func thickBorderCharacters() {
        let b = Border.thick
        #expect(b.top == "━")
        #expect(b.left == "┃")
        #expect(b.topLeft == "┏")
        #expect(b.bottomRight == "┛")
    }

    @Test func doubleBorderCharacters() {
        let b = Border.double
        #expect(b.top == "═")
        #expect(b.left == "║")
        #expect(b.topLeft == "╔")
        #expect(b.bottomRight == "╝")
    }

    @Test func asciiBorderCharacters() {
        let b = Border.ascii
        #expect(b.top == "-")
        #expect(b.left == "|")
        #expect(b.topLeft == "+")
        #expect(b.bottomRight == "+")
    }

    @Test func hiddenBorderAllSpaces() {
        let b = Border.hidden
        #expect(b.top == " ")
        #expect(b.bottom == " ")
        #expect(b.left == " ")
        #expect(b.right == " ")
        #expect(b.topLeft == " ")
        #expect(b.topRight == " ")
        #expect(b.bottomLeft == " ")
        #expect(b.bottomRight == " ")
    }

    // MARK: - Box rendering

    @Test func borderProducesCorrectStructure() {
        let rows = visibleRows(embedBuffer(Text("Hi").bordered(.normal), width: 10))
        #expect(rows == ["┌──┐", "│Hi│", "└──┘"])
    }

    @Test func borderRectangularForMultilineContent() {
        let view = VStack {
            Text("Hi")
            Text("Hello")
        }
        .bordered(.normal)
        let rows = visibleRows(embedBuffer(view, width: 10))
        #expect(rows == ["┌─────┐", "│Hi   │", "│Hello│", "└─────┘"])
    }

    @Test func customBorderUsesProvidedCharacters() {
        let custom = Border(
            top: "~", bottom: "~", left: "!", right: "!",
            topLeft: "*", topRight: "*", bottomLeft: "*", bottomRight: "*"
        )
        let rows = visibleRows(embedBuffer(Text("Hi").bordered(custom), width: 10))
        #expect(rows == ["*~~*", "!Hi!", "*~~*"])
    }

    @Test func hiddenBorderPreservesSpacing() {
        let visible = Text("Hi").bordered(.normal)
        let hidden = Text("Hi").bordered(.hidden)
        #expect(
            visible._measure(in: .unconstrained)
                == hidden._measure(in: .unconstrained)
        )
    }

    // MARK: - Styling

    @Test func borderStyleAppliedToAllEdges() {
        let red = Style().foreground(.ansi(.red))
        let buffer = embedBuffer(Text("Hi").bordered(.normal, borderStyle: red), width: 10)

        // Top edge, bottom edge, and side glyphs carry the foreground.
        for col in 0...3 {
            #expect(buffer[col, 0].foreground == .red)
            #expect(buffer[col, 2].foreground == .red)
        }
        #expect(buffer[0, 1].foreground == .red)
        #expect(buffer[3, 1].foreground == .red)

        // The content is not styled by the border style.
        #expect(buffer[1, 1].foreground == nil)
        #expect(buffer[2, 1].foreground == nil)
    }

    @Test func borderStyleNilLeavesGlyphsUnstyled() {
        let buffer = embedBuffer(Text("Hi").bordered(.normal), width: 10)
        #expect(buffer[0, 0].foreground == nil)
        #expect(buffer[0, 0].background == nil)
        #expect(buffer[0, 0].attributes.isEmpty)
        #expect(buffer[1, 1].foreground == nil)
    }

    @Test func perSideStyleOverridesBorderStyle() {
        let bold = Style().bold()
        let italic = Style().italic()
        let underline = Style().underline()

        let view = Text("X").bordered(
            .normal,
            borderStyle: underline,
            topStyle: bold,
            bottomStyle: italic
        )
        let buffer = embedBuffer(view, width: 10)

        // Top edge is bold.
        #expect(buffer[0, 0].attributes.contains(.bold))
        #expect(buffer[1, 0].attributes.contains(.bold))
        // Bottom edge is italic.
        #expect(buffer[0, 2].attributes.contains(.italic))
        #expect(buffer[1, 2].attributes.contains(.italic))
        // Sides fall back to the shared border style.
        #expect(buffer[0, 1].resolvedUnderlineStyle == .single)
        #expect(buffer[2, 1].resolvedUnderlineStyle == .single)
        #expect(!buffer[0, 1].attributes.contains(.bold))
    }

    @Test func cornersInheritHorizontalEdgeStyle() {
        let bold = Style().bold()
        let italic = Style().italic()

        let view = Text("X").bordered(.normal, topStyle: bold, bottomStyle: italic)
        let buffer = embedBuffer(view, width: 10)

        // Top corners inherit the top edge style.
        #expect(buffer[0, 0].attributes.contains(.bold))
        #expect(buffer[2, 0].attributes.contains(.bold))
        // Bottom corners inherit the bottom edge style.
        #expect(buffer[0, 2].attributes.contains(.italic))
        #expect(buffer[2, 2].attributes.contains(.italic))
        // Sides have no shared fallback, so they stay unstyled.
        #expect(buffer[0, 1].attributes.isEmpty)
        #expect(buffer[2, 1].attributes.isEmpty)
    }

    @Test func contentInsideBorderKeepsItsOwnStyle() {
        let green = Style().foreground(.ansi(.green))
        let red = Style().foreground(.ansi(.red))
        let content = green.styledText("Hi")

        let view = Text(content).bordered(.normal, borderStyle: red)
        let buffer = embedBuffer(view, width: 10)

        #expect(buffer[0, 0].foreground == .red)
        #expect(buffer[1, 1].foreground == .green)
        #expect(buffer[2, 1].foreground == .green)
    }

    @Test func styledBorderVisibleWidthUnchanged() {
        let cyan = Style().foreground(.ansi(.cyan))
        let plain = visibleRows(embedBuffer(Text("Hello").bordered(.rounded), width: 10))
        let styled = visibleRows(
            embedBuffer(Text("Hello").bordered(.rounded, borderStyle: cyan), width: 10)
        )
        #expect(plain == styled)
    }

    @Test func styledBorderCarriesHyperlink() {
        let link = Style().hyperlink("https://example.com")
        let buffer = embedBuffer(Text("X").bordered(.normal, topStyle: link), width: 10)
        #expect(buffer[0, 0].hyperlink == "https://example.com")
    }

    // MARK: - Equatable

    @Test func borderEquatable() {
        #expect(Border.normal == Border.normal)
        #expect(Border.normal != Border.rounded)
        #expect(Border.ascii != Border.thick)
    }
}
