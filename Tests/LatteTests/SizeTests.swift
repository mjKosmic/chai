import Testing
@testable import Latte

@Suite("Size")
struct SizeTests {

    // MARK: - enforceWidth

    @Test func enforceWidthPadsShortLine() {
        let result = enforceWidth("Hi", 8)
        #expect(result == "Hi      ")
        #expect(visibleWidth(of: result) == 8)
    }

    @Test func enforceWidthExactWidthIsUnchanged() {
        #expect(enforceWidth("Hello", 5) == "Hello")
    }

    @Test func enforceWidthDoesNotTruncateWiderLines() {
        // Width enforcement is minimum-only; wider lines pass through.
        #expect(enforceWidth("Hello!", 3) == "Hello!")
    }

    @Test func enforceWidthRightAlignment() {
        #expect(enforceWidth("Hi", 6, alignment: .right) == "    Hi")
    }

    @Test func enforceWidthCenterAlignment() {
        // "Hi" in 6 → shortage 4 → 2 left, 2 right
        #expect(enforceWidth("Hi", 6, alignment: .center) == "  Hi  ")
    }

    @Test func enforceWidthMultiLine() {
        let result = enforceWidth("Hi\nHello!", 8)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hi      ")
        #expect(lines[1] == "Hello!  ")
    }

    @Test func enforceWidthAnsiAware() {
        let styled = "\u{1B}[31mHi\u{1B}[0m"
        let result = enforceWidth(styled, 6)
        #expect(visibleWidth(of: result) == 6)
        #expect(result.contains("\u{1B}[31m"))
    }

    // MARK: - enforceHeight

    @Test func enforceHeightPadsBottomByDefault() {
        let result = enforceHeight("A\nB", 4)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == "A")
        #expect(lines[1] == "B")
        // Blank lines have width of the widest content line (1 col each)
        #expect(lines[2] == " ")
        #expect(lines[3] == " ")
    }

    @Test func enforceHeightPadsTopWhenAlignedBottom() {
        let result = enforceHeight("A\nB", 4, alignment: .bottom)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == " ")
        #expect(lines[1] == " ")
        #expect(lines[2] == "A")
        #expect(lines[3] == "B")
    }

    @Test func enforceHeightCenterAlignmentEvenShortage() {
        // 2 lines into 4 → shortage 2 → 1 top, 1 bottom
        let result = enforceHeight("A\nB", 4, alignment: .middle)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == " ")
        #expect(lines[1] == "A")
        #expect(lines[2] == "B")
        #expect(lines[3] == " ")
    }

    @Test func enforceHeightCenterAlignmentOddShortage() {
        // 1 line into 4 → shortage 3 → topPad = 3/2 = 1, bottomPad = 2
        let result = enforceHeight("A", 4, alignment: .middle)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == " ")
        #expect(lines[1] == "A")
        #expect(lines[2] == " ")
        #expect(lines[3] == " ")
    }

    @Test func enforceHeightNoopWhenAlreadyTallEnough() {
        let text = "A\nB\nC"
        #expect(enforceHeight(text, 3) == text)
        #expect(enforceHeight(text, 2) == text)
        #expect(enforceHeight(text, 1) == text)
    }

    @Test func enforceHeightBlankLinesMatchContentWidth() {
        // Widest line is "Hello" (5 cols) → blank lines are "     " (5 spaces)
        let result = enforceHeight("Hi\nHello", 4)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[2] == "     ")
        #expect(lines[3] == "     ")
    }

    @Test func enforceHeightSingleLine() {
        let result = enforceHeight("Hi", 3)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "Hi")
        #expect(lines[1] == "  ")
        #expect(lines[2] == "  ")
    }

    // MARK: - clampWidth

    @Test func clampWidthTruncatesLongLine() {
        let result = clampWidth("Hello, World!", 5)
        #expect(result == "Hello")
        #expect(visibleWidth(of: result) == 5)
    }

    @Test func clampWidthExactWidthIsUnchanged() {
        #expect(clampWidth("Hello", 5) == "Hello")
    }

    @Test func clampWidthShorterLineIsUnchanged() {
        #expect(clampWidth("Hi", 10) == "Hi")
    }

    @Test func clampWidthMultiLine() {
        let result = clampWidth("Hello, World!\nHi\nLonger line here", 8)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hello, W")
        #expect(lines[1] == "Hi")
        #expect(lines[2] == "Longer l")
    }

    @Test func clampWidthAnsiAware() {
        // ANSI codes should be preserved and not count toward width.
        let styled = "\u{1B}[31mHello, World!\u{1B}[0m"
        let result = clampWidth(styled, 5)
        #expect(visibleWidth(of: result) == 5)
        #expect(result.contains("\u{1B}[31m"))
    }

    @Test func clampWidthZeroReturnsEmpty() {
        let result = clampWidth("Hello", 0)
        #expect(result == "")
    }

    @Test func clampWidthWideCharacters() {
        // CJK character "你" is 2 columns wide.
        // "你好世界" = 8 columns. Clamp to 5 → "你好" (4 cols, next char would exceed).
        let result = clampWidth("你好世界", 5)
        #expect(visibleWidth(of: result) <= 5)
        #expect(result == "你好")
    }

    // MARK: - clampHeight

    @Test func clampHeightDropsExcessLines() {
        let result = clampHeight("A\nB\nC\nD", 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "A")
        #expect(lines[1] == "B")
    }

    @Test func clampHeightExactHeightIsUnchanged() {
        let text = "A\nB\nC"
        #expect(clampHeight(text, 3) == text)
    }

    @Test func clampHeightShorterIsUnchanged() {
        let text = "A\nB"
        #expect(clampHeight(text, 5) == text)
    }

    @Test func clampHeightSingleLineKept() {
        #expect(clampHeight("Hello", 1) == "Hello")
    }

    @Test func clampHeightZeroReturnsEmpty() {
        #expect(clampHeight("A\nB\nC", 0) == "")
    }

    // MARK: - clamp

    @Test func clampBothDimensions() {
        let result = clamp("Hello, World!\nSecond line\nThird line", maxWidth: 8, maxHeight: 2)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "Hello, W")
        #expect(lines[1] == "Second l")
    }

    @Test func clampNoopWhenWithinBounds() {
        let text = "Hi\nOk"
        #expect(clamp(text, maxWidth: 10, maxHeight: 5) == text)
    }

    @Test func clampWidthOnlyWhenHeightFits() {
        let result = clamp("Hello, World!", maxWidth: 5, maxHeight: 10)
        #expect(result == "Hello")
    }

    @Test func clampHeightOnlyWhenWidthFits() {
        let result = clamp("A\nB\nC\nD", maxWidth: 100, maxHeight: 2)
        #expect(result == "A\nB")
    }
}
