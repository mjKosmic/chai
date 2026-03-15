import Testing
@testable import Latte

@Suite("Inline")
struct InlineTests {

    // MARK: - Basic behavior

    @Test func returnsFirstLineOfMultiLineString() {
        #expect(inline("Hello\nWorld") == "Hello")
    }

    @Test func singleLineReturnedUnchanged() {
        #expect(inline("Only one line") == "Only one line")
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(inline("") == "")
    }

    @Test func emptyFirstLineReturnsEmpty() {
        #expect(inline("\nSecond line") == "")
    }

    @Test func multipleNewlinesStillReturnsFirstLine() {
        #expect(inline("First\nSecond\nThird\nFourth") == "First")
    }

    // MARK: - ANSI preservation

    @Test func preservesAnsiCodesInFirstLine() {
        let styled = "\u{1B}[31mHello\u{1B}[0m\nWorld"
        #expect(inline(styled) == "\u{1B}[31mHello\u{1B}[0m")
    }

    // MARK: - Composition with other Latte functions

    @Test func inlineAfterBorderExtractsTopEdge() {
        let bordered = border("Hi", .rounded)
        // bordered is: "╭──╮\n│Hi│\n╰──╯"
        #expect(inline(bordered) == "╭──╮")
    }

    @Test func inlineAfterPadExtractsFirstPaddedLine() {
        let padded = pad("Hello", top: 1, left: 2)
        // First line is the blank top padding line
        let firstLine = inline(padded)
        #expect(visibleWidth(of: firstLine) == 7) // 2 + 5 = 7
    }

    @Test func inlineOfJoinedBlocksExtractsFirstRow() {
        let left = "A\nB"
        let right = "X\nY"
        let joined = joinHorizontal(.top, left, right)
        #expect(inline(joined) == "AX")
    }
}
