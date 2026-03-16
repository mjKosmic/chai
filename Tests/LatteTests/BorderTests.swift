import Testing
@testable import Latte

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

    // MARK: - Full border rendering

    @Test func borderProducesCorrectStructure() {
        let result = border("Hi", .normal)
        let lines = result.components(separatedBy: "\n")
        // 1 top + 1 content + 1 bottom = 3 lines
        #expect(lines.count == 3)
        #expect(lines[0] == "┌──┐")
        #expect(lines[1] == "│Hi│")
        #expect(lines[2] == "└──┘")
    }

    @Test func borderDefaultStyleIsRounded() {
        let result = border("X")
        #expect(result.contains("╭"))
        #expect(result.contains("╯"))
    }

    @Test func borderRectangularForMultilineContent() {
        // "Hi" (2) and "Hello" (5) → contentWidth = 5; border adds 1 each side
        let result = border("Hi\nHello", .normal)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)  // top + 2 content + bottom
        // Each line should be exactly 7 visible columns (1 + 5 + 1)
        for line in lines {
            #expect(visibleWidth(of: line) == 7)
        }
        #expect(lines[1] == "│Hi   │")
        #expect(lines[2] == "│Hello│")
    }

    @Test func borderTopEdgeHasCorrectWidth() {
        let result = border("Hello", .rounded)
        let lines = result.components(separatedBy: "\n")
        // ╭─────╮ → 1 + 5 + 1 = 7 visible cols
        #expect(visibleWidth(of: lines[0]) == 7)
        #expect(lines[0] == "╭─────╮")
    }

    // MARK: - Partial borders (selective sides)

    @Test func topOnlyBorder() {
        let result = border("Hello", .normal, top: true, right: false, bottom: false, left: false)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        // No corners because left/right are off
        #expect(lines[0] == "─────")
        #expect(lines[1] == "Hello")
    }

    @Test func bottomOnlyBorder() {
        let result = border("Hello", .normal, top: false, right: false, bottom: true, left: false)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "Hello")
        #expect(lines[1] == "─────")
    }

    @Test func leftAndRightOnlyBorder() {
        let result = border("Hello", .normal, top: false, right: true, bottom: false, left: true)
        let lines = result.components(separatedBy: "\n")
        // Only 1 content line, no top or bottom bars
        #expect(lines.count == 1)
        #expect(lines[0] == "│Hello│")
    }

    @Test func topAndBottomNoCornersWhenSidesOff() {
        let result = border("Hi\nThere", .normal, top: true, right: false, bottom: true, left: false)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        // Top and bottom are plain dashes, no corner characters
        #expect(lines[0] == "─────")  // contentWidth = max("Hi", "There") = 5
        #expect(lines[3] == "─────")
        // No │ on content lines
        #expect(!lines[1].hasPrefix("│"))
        #expect(!lines[1].hasSuffix("│"))
    }

    @Test func topLeftRightNoBottom() {
        let result = border("Hello", .normal, top: true, right: true, bottom: false, left: true)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "┌─────┐")
        #expect(lines[1] == "│Hello│")
        // No bottom line
    }

    // MARK: - Hidden border

    @Test func hiddenBorderPreservesSpacing() {
        let visible = border("Hi", .normal)
        let hidden  = border("Hi", .hidden)
        let visLines = visible.components(separatedBy: "\n")
        let hidLines = hidden.components(separatedBy: "\n")
        // Both should have the same number of lines and same visible widths
        #expect(visLines.count == hidLines.count)
        for (v, h) in zip(visLines, hidLines) {
            #expect(visibleWidth(of: v) == visibleWidth(of: h))
        }
    }

    // MARK: - ANSI codes in content

    @Test func borderPreservesAnsiCodesInContent() {
        let styled = "\u{1B}[31mRed\u{1B}[0m"
        let result = border(styled, .normal)
        #expect(result.contains("\u{1B}[31m"))
        #expect(result.contains("\u{1B}[0m"))
        // Visible width of content line: 1 (│) + 3 (Red) + 1 (│) = 5
        let lines = result.components(separatedBy: "\n")
        #expect(visibleWidth(of: lines[1]) == 5)
    }

    // MARK: - Custom border

    @Test func customBorderUsesProvidedCharacters() {
        let custom = Border(
            top: "~", bottom: "~", left: "!", right: "!",
            topLeft: "*", topRight: "*", bottomLeft: "*", bottomRight: "*"
        )
        let result = border("Hi", custom)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "*~~*")
        #expect(lines[1] == "!Hi!")
        #expect(lines[2] == "*~~*")
    }

    // MARK: - Styled borders

    @Test func borderStyleAppliedToAllEdges() {
        // Cyan foreground = SGR code 36
        let cyan = Style().foreground(.ansi(.cyan))
        let result = border("Hi", .normal, borderStyle: cyan)
        let lines = result.components(separatedBy: "\n")
        // Top edge should contain the cyan SGR code (36)
        #expect(lines[0].contains("36"))
        #expect(lines[0].contains("\u{1B}[0m"))
        // Left border on content line should be styled; content "Hi" must not be
        #expect(lines[1].hasPrefix("\u{1B}[36m│\u{1B}[0m"))
        #expect(lines[1].contains("Hi"))
        // Bottom edge should be styled
        #expect(lines[2].contains("36"))
    }

    @Test func borderStyleNilIsBackwardCompatible() {
        let unstyled = border("Hi", .normal, borderStyle: nil)
        let original = border("Hi", .normal)
        #expect(unstyled == original)
    }

    @Test func perSideStyleOverridesBorderStyle() {
        // Use distinct SGR codes: bold=1, italic=3, underline=4
        let boldStyle      = Style().bold()
        let italicStyle    = Style().italic()
        let underlineStyle = Style().underline()

        let result = border("X", .normal,
                            borderStyle: underlineStyle,
                            topStyle: boldStyle,
                            bottomStyle: italicStyle)
        let lines = result.components(separatedBy: "\n")
        // Top edge: bold (SGR 1)
        #expect(lines[0].contains("\u{1B}[1m"))
        // Bottom edge: italic (SGR 3)
        #expect(lines[2].contains("\u{1B}[3m"))
        // Left/right sides: underline (SGR 4), not bold or italic
        #expect(lines[1].contains("\u{1B}[4m"))
        #expect(!lines[1].contains("\u{1B}[1m"))
    }

    @Test func cornersInheritHorizontalEdgeStyle() {
        // Bold for top, italic for bottom
        let topStyle    = Style().bold()
        let bottomStyle = Style().italic()
        let result = border("X", .normal, topStyle: topStyle, bottomStyle: bottomStyle)
        let lines = result.components(separatedBy: "\n")
        // Top row (corners + bar) contains bold SGR code
        #expect(lines[0].contains("\u{1B}[1m"))
        // Bottom row contains italic SGR code
        #expect(lines[2].contains("\u{1B}[3m"))
        // Content line (sides use fallback nil → unstyled) has no escape sequences
        #expect(!lines[1].contains("\u{1B}["))
    }

    @Test func styledBorderVisibleWidthUnchanged() {
        let cyan = Style().foreground(.ansi(.cyan))
        let unstyled = border("Hello", .rounded)
        let styled   = border("Hello", .rounded, borderStyle: cyan)
        let unstyledLines = unstyled.components(separatedBy: "\n")
        let styledLines   = styled.components(separatedBy: "\n")
        // Same number of lines
        #expect(unstyledLines.count == styledLines.count)
        // Same visible width on every line (ANSI escape codes don't count)
        for (u, s) in zip(unstyledLines, styledLines) {
            #expect(visibleWidth(of: u) == visibleWidth(of: s))
        }
    }

    @Test func borderedExtensionWithStyling() {
        let red = Style().foreground(.ansi(.red))  // SGR 31
        let result = "Hi".bordered(.normal, borderStyle: red)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0].contains("31"))
    }

    // MARK: - Equatable

    @Test func borderEquatable() {
        #expect(Border.normal == Border.normal)
        #expect(Border.normal != Border.rounded)
        #expect(Border.ascii  != Border.thick)
    }
}
