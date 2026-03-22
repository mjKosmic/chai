import Testing
import Chai
@testable import Latte

@Suite("ViewOutput Layout")
struct ViewOutputLayoutTests {

    // MARK: - Width

    @Test func widthPadsShortContent() {
        let view = ViewOutput("Hi").width(6)
        #expect(view.content.plainText == "Hi    ")
    }

    @Test func widthWithRightAlignment() {
        let view = ViewOutput("Hi").width(6, align: .right)
        #expect(view.content.plainText == "    Hi")
    }

    @Test func widthWithCenterAlignment() {
        let view = ViewOutput("Hi").width(6, align: .center)
        #expect(view.content.plainText == "  Hi  ")
    }

    @Test func widthDoesNotTruncateWiderContent() {
        let view = ViewOutput("Hello!").width(3)
        #expect(view.content.plainText == "Hello!")
    }

    // MARK: - Height

    @Test func heightPadsShortContent() {
        let view = ViewOutput("A").height(3)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "A")
    }

    @Test func heightWithBottomAlignment() {
        let view = ViewOutput("A").height(3, align: .bottom)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[2] == "A")
    }

    @Test func heightDoesNotRemoveExistingLines() {
        let view = ViewOutput("A\nB\nC").height(2)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
    }

    // MARK: - Size

    @Test func sizeEnforcesBothDimensions() {
        let view = ViewOutput("Hi").size(width: 6, height: 3)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "Hi    ")
    }

    // MARK: - Frame

    @Test func frameEnforcesBothDimensions() {
        let view = ViewOutput("Hi").frame(width: 6, height: 3)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "Hi    ")
    }

    @Test func frameCentersContentWithMiddleAlignment() {
        let view = ViewOutput("Hi").frame(width: 6, height: 3, horizontalAlignment: .center, verticalAlignment: .middle)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[1] == "  Hi  ")
    }

    @Test func frameWithBottomRightAlignment() {
        let view = ViewOutput("Hi").frame(width: 6, height: 3, horizontalAlignment: .right, verticalAlignment: .bottom)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[2] == "    Hi")
    }

    @Test func frameDoesNotShrinkLargerContent() {
        let view = ViewOutput("Hello, World!\nLine 2\nLine 3\nLine 4").frame(width: 3, height: 2)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 4)
        #expect(lines[0] == "Hello, World!")
    }

    @Test func framePreservesTerminalState() {
        let view = ViewOutput("Hi", altScreen: true, windowTitle: "Test")
            .frame(width: 10, height: 5, horizontalAlignment: .center, verticalAlignment: .middle)
        #expect(view.altScreen == true)
        #expect(view.windowTitle == "Test")
    }

    // MARK: - Clamping

    @Test func clampedWidthTruncatesLongLines() {
        let view = ViewOutput("Hello, World!").clampedWidth(5)
        #expect(view.content.plainText == "Hello")
    }

    @Test func clampedWidthLeavesShortLinesAlone() {
        let view = ViewOutput("Hi").clampedWidth(10)
        #expect(view.content.plainText == "Hi")
    }

    @Test func clampedHeightDropsExtraLines() {
        let view = ViewOutput("A\nB\nC\nD").clampedHeight(2)
        #expect(view.content.plainText == "A\nB")
    }

    @Test func clampedHeightLeavesFewLinesAlone() {
        let view = ViewOutput("A\nB").clampedHeight(5)
        #expect(view.content.plainText == "A\nB")
    }

    // MARK: - Padding

    @Test func paddedAddsSpaceOnAllSides() {
        let view = ViewOutput("X").padded(1)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        // 1 top + 1 content + 1 bottom = 3 lines
        #expect(lines.count == 3)
        // Content line: 1 left space + "X" + 1 right space
        #expect(lines[1] == " X ")
    }

    @Test func paddedWithVerticalHorizontal() {
        let view = ViewOutput("X").padded(0, 2)
        #expect(view.content.plainText == "  X  ")
    }

    @Test func paddedWithExplicitSides() {
        let view = ViewOutput("X").padded(top: 0, right: 1, bottom: 0, left: 2)
        #expect(view.content.plainText == "  X ")
    }

    // MARK: - Margin

    @Test func marginedAddsSpace() {
        let view = ViewOutput("X").margined(0, 1)
        #expect(view.content.plainText == " X ")
    }

    // MARK: - Border

    @Test func borderedWrapsWithBorderChars() {
        let view = ViewOutput("Hi").bordered(.rounded)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "╭──╮")
        #expect(lines[1] == "│Hi│")
        #expect(lines[2] == "╰──╯")
    }

    @Test func borderedNormalizesMultiLineWidth() {
        let view = ViewOutput("Hi\nWorld!").bordered(.normal)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "┌──────┐")
        #expect(lines[1] == "│Hi    │")
        #expect(lines[2] == "│World!│")
        #expect(lines[3] == "└──────┘")
    }

    // MARK: - Composition

    @Test func besidePlacesViewsHorizontally() {
        let left = ViewOutput("A\nB")
        let right = ViewOutput("1\n2")
        let combined = left.beside(right)
        let lines = combined.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "A1")
        #expect(lines[1] == "B2")
    }

    @Test func besidePadsShorterView() {
        let left = ViewOutput("A\nB\nC")
        let right = ViewOutput("1")
        let combined = left.beside(right)
        let lines = combined.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "A1")
        #expect(lines[1] == "B")
        #expect(lines[2] == "C")
    }

    @Test func besideWithBottomAlignment() {
        let left = ViewOutput("A\nB\nC")
        let right = ViewOutput("1")
        let combined = left.beside(right, align: .bottom)
        let lines = combined.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "A")
        #expect(lines[1] == "B")
        #expect(lines[2] == "C1")
    }

    @Test func aboveStacksVertically() {
        let top = ViewOutput("Top")
        let bottom = ViewOutput("Bottom")
        let combined = top.above(bottom)
        let lines = combined.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 2)
        #expect(lines[0] == "Top   ")
        #expect(lines[1] == "Bottom")
    }

    @Test func aboveWithCenterAlignment() {
        let top = ViewOutput("Hi")
        let bottom = ViewOutput("World!")
        let combined = top.above(bottom, align: .center)
        let lines = combined.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "  Hi  ")
        #expect(lines[1] == "World!")
    }

    // MARK: - Terminal state preservation

    @Test func transformPreservesTerminalState() {
        let view = ViewOutput("Hi", altScreen: true, windowTitle: "Test")
            .width(10)
            .bordered(.rounded)
        #expect(view.altScreen == true)
        #expect(view.windowTitle == "Test")
    }

    // MARK: - Chaining

    @Test func chainingMultipleOperations() {
        let view = ViewOutput("Hi")
            .width(6)
            .padded(0, 1)
            .bordered(.rounded)

        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        // Inner: "Hi    " (6 wide) → padded: " Hi     " (8 wide) → bordered: 10 wide
        #expect(lines[0] == "╭────────╮")
        #expect(lines[1] == "│ Hi     │")
        #expect(lines[2] == "╰────────╯")
    }

    // MARK: - Styled content preservation

    @Test func widthPreservesSegmentStyles() {
        let styled = "Hello".fg(.red)
        let view = ViewOutput(styled).width(10)
        // The original segment should still have its style
        let segments = view.content.segments
        #expect(segments[0].style.foreground == .red)
        #expect(segments[0].text == "Hello")
    }

    @Test func borderedPreservesContentStyles() {
        let styled = "Hi".bold()
        let view = ViewOutput(styled).bordered(.rounded)
        // Find the segment containing "Hi" — it should still be bold
        let hiSegment = view.content.segments.first { $0.text == "Hi" }
        #expect(hiSegment != nil)
        #expect(hiSegment?.style.attributes.contains(.bold) == true)
    }

    // MARK: - Wide characters

    @Test func widthHandlesWideCharacters() {
        // CJK character "世" is 2 columns wide
        let view = ViewOutput("\u{4E16}").width(6)
        #expect(view.content.columnWidth == 6)
    }

    @Test func clampedWidthHandlesWideCharacters() {
        // "世界" = 4 columns; clamp to 3 should drop the second character
        let view = ViewOutput("\u{4E16}\u{754C}").clampedWidth(3)
        #expect(view.content.plainText == "\u{4E16}")
    }

    // MARK: - Empty content

    @Test func widthOnEmptyContent() {
        let view = ViewOutput("").width(5)
        #expect(view.content.columnWidth == 5)
    }

    @Test func borderedOnEmptyContent() {
        let view = ViewOutput("").bordered(.rounded)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.count == 3)
        #expect(lines[0] == "╭╮")
        #expect(lines[1] == "││")
        #expect(lines[2] == "╰╯")
    }

    @Test func besideWithEmptyContent() {
        let left = ViewOutput("")
        let right = ViewOutput("Hi")
        let combined = left.beside(right)
        #expect(combined.content.plainText == "Hi")
    }

    // MARK: - Multi-line clamping

    @Test func clampedWidthOnMultiLineContent() {
        let view = ViewOutput("Hello, World!\nHi").clampedWidth(5)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "Hello")
        #expect(lines[1] == "Hi")
    }

    // MARK: - Negative values

    @Test func negativePaddingIsClamped() {
        // Should not crash — negative values are clamped to 0
        let view = ViewOutput("Hi").padded(top: -1, right: -1, bottom: -1, left: -1)
        #expect(view.content.plainText == "Hi")
    }
}
