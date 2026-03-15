import Testing
@testable import Latte

@Suite("Padding")
struct PaddingTests {

    // MARK: - Individual sides

    @Test func topPaddingAddsBlankLinesAbove() {
        let result = pad("Hello", top: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "     ")
        #expect(lines[1] == "     ")
        #expect(lines[2] == "Hello")
    }

    @Test func bottomPaddingAddsBlankLinesBelow() {
        let result = pad("Hello", bottom: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "Hello")
        #expect(lines[1] == "     ")
        #expect(lines[2] == "     ")
    }

    @Test func leftPaddingPrependsSpaces() {
        let result = pad("Hello", left: 3)
        #expect(result == "   Hello")
    }

    @Test func rightPaddingAppendsSpaces() {
        let result = pad("Hello", right: 3)
        #expect(result == "Hello   ")
    }

    // MARK: - All four sides

    @Test func allSidesPaddingProducesRectangularBlock() {
        let result = pad("Hi", top: 1, right: 2, bottom: 1, left: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        // Blank lines span left + content + right = 2 + 2 + 2 = 6 cols
        #expect(lines[0] == "      ")
        #expect(lines[1] == "  Hi  ")
        #expect(lines[2] == "      ")
    }

    // MARK: - Multi-line content

    @Test func multiLineContentPaddedToMaxWidth() {
        // "Hi" (2 cols) and "Hello" (5 cols) → contentWidth = 5
        let result = pad("Hi\nHello", right: 1, left: 1)
        let lines = result.components(separatedBy: "\n")
        // Each line: 1 left + content padded to 5 + 1 right = 7 cols total
        #expect(lines[0] == " Hi    ")
        #expect(lines[1] == " Hello ")
    }

    @Test func topAndBottomBlankLinesMatchFullWidth() {
        let result = pad("Hi\nHello", top: 1, right: 2, left: 2)
        let lines = result.components(separatedBy: "\n")
        // Blank line: 2 + 5 + 2 = 9 cols
        #expect(lines[0] == "         ")
        #expect(lines.count == 3)
    }

    // MARK: - CSS-style shorthand

    @Test func shorthandAllSidesEqual() {
        let result = pad("Hi", 1)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "    ")  // 1 + 2 + 1 = 4
        #expect(lines[1] == " Hi ")
        #expect(lines[2] == "    ")
    }

    @Test func shorthandVerticalHorizontal() {
        let result = pad("Hi", 1, 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "      ")  // 2 + 2 + 2 = 6
        #expect(lines[1] == "  Hi  ")
        #expect(lines[2] == "      ")
    }

    @Test func shorthandTopSidesBottom() {
        let result = pad("Hi", 1, 2, 0)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)      // top=1, bottom=0
        #expect(lines[0] == "      ")  // blank line: 2+2+2=6
        #expect(lines[1] == "  Hi  ")
    }

    // MARK: - Zero padding is a no-op

    @Test func zeroPaddingIsNoop() {
        #expect(pad("Hello") == "Hello")
        #expect(pad("Hello", 0) == "Hello")
    }

    // MARK: - ANSI codes preserved

    @Test func ansiCodesPreservedThroughPadding() {
        let styled = "\u{1B}[31mHi\u{1B}[0m"
        let result = pad(styled, right: 2, left: 2)
        #expect(result.contains("\u{1B}[31m"))
        #expect(result.contains("\u{1B}[0m"))
        #expect(visibleWidth(of: result) == 6)  // 2 + 2 + 2
    }

    // MARK: - Custom fill character

    @Test func padWithCustomFillCharacter() {
        let result = pad("Hi", right: 3, left: 3, fill: ".")
        #expect(result == "...Hi...")
    }

    @Test func padAllSidesWithCustomFill() {
        let result = pad("Hi", top: 1, right: 2, bottom: 1, left: 2, fill: "·")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "······")
        #expect(lines[1] == "··Hi··")
        #expect(lines[2] == "······")
    }

    @Test func padShorthandWithCustomFill() {
        let result = pad("Hi", 1, fill: "·")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "····")
        #expect(lines[1] == "·Hi·")
        #expect(lines[2] == "····")
    }

    @Test func padTwoValueShorthandWithCustomFill() {
        let result = pad("Hi", 0, 2, fill: ".")
        #expect(result == "..Hi..")
    }

    @Test func padThreeValueShorthandWithCustomFill() {
        let result = pad("Hi", 1, 2, 0, fill: ".")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "......")
        #expect(lines[1] == "..Hi..")
    }

    @Test func padMultiLineWithCustomFillPadsToMaxWidth() {
        let result = pad("Hi\nHello", right: 1, left: 1, fill: ".")
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == ".Hi....")
        #expect(lines[1] == ".Hello.")
    }
}

// MARK: - Margin

@Suite("Margin")
struct MarginTests {

    // MARK: - Margin produces correct output independently

    @Test func marginTopAddsBlankLinesAbove() {
        let result = margin("Hello", top: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "     ")
        #expect(lines[1] == "     ")
        #expect(lines[2] == "Hello")
    }

    @Test func marginBottomAddsBlankLinesBelow() {
        let result = margin("Hello", bottom: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "Hello")
        #expect(lines[1] == "     ")
        #expect(lines[2] == "     ")
    }

    @Test func marginLeftPrependsSpaces() {
        #expect(margin("Hello", left: 3) == "   Hello")
    }

    @Test func marginRightAppendsSpaces() {
        #expect(margin("Hello", right: 3) == "Hello   ")
    }

    @Test func marginAllSidesProducesRectangularBlock() {
        let result = margin("Hi", top: 1, right: 2, bottom: 1, left: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "      ")
        #expect(lines[1] == "  Hi  ")
        #expect(lines[2] == "      ")
    }

    @Test func marginMultiLineContentPaddedToMaxWidth() {
        let result = margin("Hi\nHello", right: 1, left: 1)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == " Hi    ")
        #expect(lines[1] == " Hello ")
    }

    // MARK: - Margin output matches pad output (mechanically identical)

    @Test func marginProducesSameResultAsPad() {
        let content = "Hello\nWorld"
        let padded  = pad(content,    top: 1, right: 2, bottom: 1, left: 2)
        let margined = margin(content, top: 1, right: 2, bottom: 1, left: 2)
        #expect(padded == margined)
    }

    // MARK: - CSS-style shorthand

    @Test func marginShorthandAllSides() {
        let result = margin("Hi", 1)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "    ")
        #expect(lines[1] == " Hi ")
        #expect(lines[2] == "    ")
    }

    @Test func marginShorthandVerticalHorizontal() {
        let result = margin("Hi", 2, 4)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 5)
        #expect(lines[0] == "          ")  // 4 + 2 + 4 = 10
        #expect(lines[2] == "    Hi    ")
    }

    @Test func marginShorthandTopSidesBottom() {
        let result = margin("Hi", 1, 3, 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)  // top=1, content=1, bottom=2
        #expect(lines[0] == "        ")  // 3 + 2 + 3 = 8
        #expect(lines[1] == "   Hi   ")
    }

    @Test func marginZeroIsNoop() {
        #expect(margin("Hello") == "Hello")
    }

    // MARK: - ANSI codes preserved

    @Test func marginPreservesAnsiCodes() {
        let styled = "\u{1B}[31mHi\u{1B}[0m"
        let result = margin(styled, right: 2, left: 2)
        #expect(result.contains("\u{1B}[31m"))
        #expect(result.contains("\u{1B}[0m"))
        #expect(visibleWidth(of: result) == 6)
    }

    // MARK: - Custom fill character

    @Test func marginWithCustomFillCharacter() {
        let result = margin("Hi", right: 3, left: 3, fill: ".")
        #expect(result == "...Hi...")
    }

    @Test func marginAllSidesWithCustomFill() {
        let result = margin("Hi", top: 1, right: 2, bottom: 1, left: 2, fill: "·")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "······")
        #expect(lines[1] == "··Hi··")
        #expect(lines[2] == "······")
    }

    @Test func marginShorthandWithCustomFill() {
        let result = margin("Hi", 1, fill: "·")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "····")
        #expect(lines[1] == "·Hi·")
        #expect(lines[2] == "····")
    }

    @Test func marginTwoValueShorthandWithCustomFill() {
        let result = margin("Hi", 0, 2, fill: ".")
        #expect(result == "..Hi..")
    }

    @Test func marginThreeValueShorthandWithCustomFill() {
        let result = margin("Hi", 1, 2, 0, fill: ".")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "......")
        #expect(lines[1] == "..Hi..")
    }
}
