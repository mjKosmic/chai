import Testing
@testable import Latte

@Suite("Join")
struct JoinTests {

    // MARK: - joinHorizontal: basic

    @Test func joinHorizontalTwoEqualHeightBlocks() {
        let result = joinHorizontal(.top, "AB", "CD")
        #expect(result == "ABCD")
    }

    @Test func joinHorizontalThreeBlocks() {
        let result = joinHorizontal(.top, "A", "B", "C")
        #expect(result == "ABC")
    }

    @Test func joinHorizontalSingleBlockIsUnchanged() {
        #expect(joinHorizontal(.top, "Hello\nWorld") == "Hello\nWorld")
    }

    @Test func joinHorizontalEmptyArrayReturnsEmpty() {
        #expect(joinHorizontal(.top, []) == "")
    }

    // MARK: - joinHorizontal: height padding

    @Test func joinHorizontalTopAlignmentPadsShortBlockAtBottom() {
        //  Left: "Hello\nWorld" (2 lines)
        // Right: "!"            (1 line)
        let result = joinHorizontal(.top, "Hello\nWorld", "!")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "Hello!")
        #expect(lines[1] == "World ")   // right block padded with blank at bottom
    }

    @Test func joinHorizontalBottomAlignmentPadsShortBlockAtTop() {
        let result = joinHorizontal(.bottom, "Hello\nWorld", "!")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "Hello ")  // right block blank at top
        #expect(lines[1] == "World!")
    }

    @Test func joinHorizontalMiddleAlignmentEvenShortage() {
        // "AB\nCD\nEF" (3 lines) + "!" (1 line) → shortage 2 → topPad 1, bottomPad 1
        let result = joinHorizontal(.middle, "AB\nCD\nEF", "!")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "AB ")
        #expect(lines[1] == "CD!")
        #expect(lines[2] == "EF ")
    }

    @Test func joinHorizontalMiddleAlignmentOddShortage() {
        // 4-line block + 1-line block → shortage 3 → topPad = 3/2 = 1, bottomPad = 2
        let result = joinHorizontal(.middle, "A\nB\nC\nD", "!")
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == "A ")
        #expect(lines[1] == "B!")
        #expect(lines[2] == "C ")
        #expect(lines[3] == "D ")
    }

    // MARK: - joinHorizontal: width uniformity

    @Test func joinHorizontalPadsBlockLinesToMaxWidth() {
        // Left block: "Hi\nHello" — "Hi" is 2 cols, "Hello" is 5 cols
        // Right block: "!" — 1 col
        let result = joinHorizontal(.top, "Hi\nHello", "!")
        let lines = result.components(separatedBy: "\n")
        // "Hi" padded to 5, then "!" appended → "Hi   !"
        #expect(lines[0] == "Hi   !")
        #expect(lines[1] == "Hello ")   // blank right from height padding
    }

    @Test func joinHorizontalAllRowsSameWidth() {
        let result = joinHorizontal(.top, "Short\nA longer line", "Col2\nC2")
        let lines = result.components(separatedBy: "\n")
        let widths = lines.map { visibleWidth(of: $0) }
        #expect(widths.allSatisfy { $0 == widths[0] })
    }

    // MARK: - joinHorizontal: array overload

    @Test func joinHorizontalArrayOverload() {
        let blocks = ["AB", "CD", "EF"]
        #expect(joinHorizontal(.top, blocks) == "ABCDEF")
    }

    // MARK: - joinHorizontal: ANSI codes

    @Test func joinHorizontalPreservesAnsiCodes() {
        let styled = "\u{1B}[31mHi\u{1B}[0m"
        let result = joinHorizontal(.top, styled, " there")
        #expect(result.contains("\u{1B}[31m"))
        // Visible width: 2 (Hi) + 6 ( there) = 8
        #expect(visibleWidth(of: result) == 8)
    }

    // MARK: - joinVertical: basic

    @Test func joinVerticalStacksTwoBlocks() {
        let result = joinVertical(.left, "Hello", "World")
        #expect(result == "Hello\nWorld")
    }

    @Test func joinVerticalSingleBlockIsUnchanged() {
        #expect(joinVertical(.left, "Hello\nWorld") == "Hello\nWorld")
    }

    @Test func joinVerticalEmptyArrayReturnsEmpty() {
        #expect(joinVertical(.left, []) == "")
    }

    // MARK: - joinVertical: width alignment

    @Test func joinVerticalLeftAlignNarrowLinesArePaddedRight() {
        // "Hello!" (6) and "Hi" (2) → maxWidth 6
        let result = joinVertical(.left, "Hello!", "Hi")
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hello!")
        #expect(lines[1] == "Hi    ")
    }

    @Test func joinVerticalRightAlignNarrowLinesArePaddedLeft() {
        let result = joinVertical(.right, "Hello!", "Hi")
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hello!")
        #expect(lines[1] == "    Hi")
    }

    @Test func joinVerticalCenterAlignNarrowLinesArePaddedBothSides() {
        // "Hello!" (6) and "Hi" (2) → shortage 4 → 2 left, 2 right
        let result = joinVertical(.center, "Hello!", "Hi")
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hello!")
        #expect(lines[1] == "  Hi  ")
    }

    @Test func joinVerticalAllRowsSameWidth() {
        let result = joinVertical(.left, "Short", "A much longer line", "Medium")
        let lines = result.components(separatedBy: "\n")
        let widths = lines.map { visibleWidth(of: $0) }
        #expect(widths.allSatisfy { $0 == widths[0] })
    }

    // MARK: - joinVertical: multi-line blocks

    @Test func joinVerticalMultiLineBlocks() {
        let blockA = "AB\nCD"
        let blockB = "EF\nGH"
        let result = joinVertical(.left, blockA, blockB)
        let lines = result.components(separatedBy: "\n")
        #expect(lines == ["AB", "CD", "EF", "GH"])
    }

    // MARK: - joinVertical: array overload

    @Test func joinVerticalArrayOverload() {
        let blocks = ["A", "B", "C"]
        #expect(joinVertical(.left, blocks) == "A\nB\nC")
    }
}
