import Testing
@testable import Latte

@Suite("Alignment")
struct AlignmentTests {

    // MARK: - Left alignment (default)

    @Test func leftAlignPadsRight() {
        #expect(align("Hi", width: 6) == "Hi    ")
    }

    @Test func leftAlignExactWidthIsUnchanged() {
        #expect(align("Hello", width: 5) == "Hello")
    }

    @Test func leftAlignWiderThanWidthIsUnchanged() {
        #expect(align("Hello!", width: 3) == "Hello!")
    }

    // MARK: - Right alignment

    @Test func rightAlignPadsLeft() {
        #expect(align("Hi", width: 6, .right) == "    Hi")
    }

    @Test func rightAlignExactWidthIsUnchanged() {
        #expect(align("Hello", width: 5, .right) == "Hello")
    }

    // MARK: - Center alignment

    @Test func centerAlignEvenPadding() {
        // 6 - 2 = 4 shortage → 2 left, 2 right
        #expect(align("Hi", width: 6, .center) == "  Hi  ")
    }

    @Test func centerAlignOddPaddingGoesRight() {
        // 7 - 2 = 5 shortage → leftPad = 5/2 = 2, rightPad = 3
        #expect(align("Hi", width: 7, .center) == "  Hi   ")
    }

    @Test func centerAlignExactWidthIsUnchanged() {
        #expect(align("Hello", width: 5, .center) == "Hello")
    }

    // MARK: - Multi-line

    @Test func alignMultiLinePadsEachLine() {
        let result = align("Hi\nHello!", width: 8)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hi      ")
        #expect(lines[1] == "Hello!  ")
    }

    @Test func alignMultiLineCenterEachLine() {
        let result = align("Hi\nHello!", width: 8, .center)
        let lines = result.components(separatedBy: "\n")
        // "Hi" in 8 → shortage 6 → 3 left, 3 right
        #expect(lines[0] == "   Hi   ")
        // "Hello!" in 8 → shortage 2 → 1 left, 1 right
        #expect(lines[1] == " Hello! ")
    }

    @Test func alignMultiLineRightEachLine() {
        let result = align("Hi\nHello!", width: 8, .right)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "      Hi")
        #expect(lines[1] == "  Hello!")
    }

    // MARK: - ANSI-aware alignment

    @Test func alignIgnoresAnsiCodesInWidthCalculation() {
        // "\e[31mHi\e[0m" has visible width 2, so shortage = 6 - 2 = 4
        let styled = "\u{1B}[31mHi\u{1B}[0m"
        let result = align(styled, width: 6)
        // Should have 4 trailing spaces beyond the visible content
        #expect(visibleWidth(of: result) == 6)
        #expect(result.contains("\u{1B}[31m"))
        #expect(result.hasSuffix("    "))
    }

    @Test func alignCenterWithAnsiCodes() {
        // "\e[31mHi\e[0m" visible width 2; width 6 → shortage 4 → 2 left, 2 right
        let styled = "\u{1B}[31mHi\u{1B}[0m"
        let result = align(styled, width: 6, .center)
        #expect(visibleWidth(of: result) == 6)
        #expect(result.hasPrefix("  "))
        #expect(result.hasSuffix("  "))
    }

    // MARK: - Edge cases

    @Test func alignEmptyStringCreatesSpaces() {
        #expect(align("", width: 4) == "    ")
    }

    @Test func alignZeroWidthIsNoop() {
        #expect(align("Hi", width: 0) == "Hi")
    }

    // MARK: - Fractional alignment

    @Test func fractionalQuarterPlacesContentAtTwentyFivePercent() {
        // "Hi" in 10 → shortage 8 → leftPad = Int(8 * 0.25) = 2, rightPad = 6
        let result = align("Hi", width: 10, HorizontalAlignment(fraction: 0.25))
        #expect(result == "  Hi      ")
        #expect(visibleWidth(of: result) == 10)
    }

    @Test func fractionalThreeQuarterPlacesContentAtSeventyFivePercent() {
        // "Hi" in 10 → shortage 8 → leftPad = Int(8 * 0.75) = 6, rightPad = 2
        let result = align("Hi", width: 10, HorizontalAlignment(fraction: 0.75))
        #expect(result == "      Hi  ")
        #expect(visibleWidth(of: result) == 10)
    }

    @Test func fractionalZeroIsSameAsLeft() {
        let left = align("Hi", width: 8, .left)
        let frac = align("Hi", width: 8, HorizontalAlignment(fraction: 0.0))
        #expect(left == frac)
    }

    @Test func fractionalOneIsSameAsRight() {
        let right = align("Hi", width: 8, .right)
        let frac = align("Hi", width: 8, HorizontalAlignment(fraction: 1.0))
        #expect(right == frac)
    }

    @Test func fractionalHalfIsSameAsCenter() {
        let center = align("Hi", width: 8, .center)
        let frac = align("Hi", width: 8, HorizontalAlignment(fraction: 0.5))
        #expect(center == frac)
    }

    @Test func fractionalAlignmentClampsBelowZero() {
        let alignment = HorizontalAlignment(fraction: -0.5)
        #expect(alignment.fraction == 0.0)
    }

    @Test func fractionalAlignmentClampsAboveOne() {
        let alignment = HorizontalAlignment(fraction: 1.5)
        #expect(alignment.fraction == 1.0)
    }

    @Test func fractionalVerticalAlignmentPlacesContent() {
        // 1 line into 5 → shortage 4 → topPad = Int(4 * 0.75) = 3, bottomPad = 1
        let result = enforceHeight("Hi", 5, alignment: VerticalAlignment(fraction: 0.75))
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 5)
        #expect(lines[0] == "  ")
        #expect(lines[1] == "  ")
        #expect(lines[2] == "  ")
        #expect(lines[3] == "Hi")
        #expect(lines[4] == "  ")
    }

    @Test func fractionalVerticalZeroIsSameAsTop() {
        let top = enforceHeight("Hi", 4, alignment: .top)
        let frac = enforceHeight("Hi", 4, alignment: VerticalAlignment(fraction: 0.0))
        #expect(top == frac)
    }

    @Test func fractionalVerticalOneIsSameAsBottom() {
        let bottom = enforceHeight("Hi", 4, alignment: .bottom)
        let frac = enforceHeight("Hi", 4, alignment: VerticalAlignment(fraction: 1.0))
        #expect(bottom == frac)
    }

    @Test func expressibleByFloatLiteralHorizontal() {
        let alignment: HorizontalAlignment = 0.75
        #expect(alignment.fraction == 0.75)
    }

    @Test func expressibleByFloatLiteralVertical() {
        let alignment: VerticalAlignment = 0.25
        #expect(alignment.fraction == 0.25)
    }

    @Test func fractionalAlignmentMultiLine() {
        // Each line aligned independently at 0.75
        let result = align("Hi\nHello!", width: 10, HorizontalAlignment(fraction: 0.75))
        let lines = result.components(separatedBy: "\n")
        // "Hi" shortage 8 → leftPad = Int(8*0.75) = 6
        #expect(lines[0] == "      Hi  ")
        // "Hello!" shortage 4 → leftPad = Int(4*0.75) = 3
        #expect(lines[1] == "   Hello! ")
    }
}
