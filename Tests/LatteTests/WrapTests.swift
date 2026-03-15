import Testing
@testable import Latte

@Suite("Wrap")
struct WrapTests {

    // MARK: - Basic wrapping

    @Test func noWrapNeededReturnsUnchanged() {
        #expect(wrap("Hello", width: 10) == "Hello")
    }

    @Test func exactWidthReturnsUnchanged() {
        #expect(wrap("Hello", width: 5) == "Hello")
    }

    @Test func wrapsAtSpace() {
        let result = wrap("Hello World", width: 6)
        #expect(result == "Hello\nWorld")
    }

    @Test func wrapsMultipleWords() {
        let result = wrap("one two three four", width: 10)
        // "one two" (7) fits, "one two three" (13) doesn't → break after "two"
        // "three four" (10) fits
        #expect(result == "one two\nthree four")
    }

    @Test func wrapsIntoThreeLines() {
        let result = wrap("Hello, World! This is a test.", width: 14)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "Hello, World!")
        #expect(lines[1] == "This is a")
        #expect(lines[2] == "test.")
    }

    @Test func zeroWidthReturnsEmpty() {
        #expect(wrap("Hello", width: 0) == "")
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(wrap("", width: 10) == "")
    }

    // MARK: - Hard wrapping (no break character found)

    @Test func hardWrapsLongWordWithoutSpaces() {
        let result = wrap("abcdefghij", width: 4)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "abcd")
        #expect(lines[1] == "efgh")
        #expect(lines[2] == "ij")
    }

    @Test func hardWrapsWhenWordExceedsWidth() {
        let result = wrap("hi superlongword bye", width: 8)
        let lines = result.components(separatedBy: "\n")
        // "hi" fits, then "superlongword" must be hard-wrapped
        #expect(lines[0] == "hi")
        #expect(lines[1] == "superlon")
        #expect(lines[2] == "gword")
        #expect(lines[3] == "bye")
    }

    // MARK: - Existing newlines preserved

    @Test func existingNewlinesPreserved() {
        let result = wrap("Hello World\nFoo Bar Baz", width: 6)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "Hello")
        #expect(lines[1] == "World")
        #expect(lines[2] == "Foo")
        #expect(lines[3] == "Bar")
        #expect(lines[4] == "Baz")
    }

    @Test func shortLinesWithNewlinesUnchanged() {
        let text = "Hi\nBye"
        #expect(wrap(text, width: 10) == text)
    }

    // MARK: - Custom break character

    @Test func wrapsAtHyphen() {
        let result = wrap("one-two-three-four", width: 10, breakCharacter: "-")
        let lines = result.components(separatedBy: "\n")
        // "one-two" (7) + "-" + "t" = 9 ≤ 10, but "one-two-three" = 13 > 10
        // → break at second "-", yielding "one-two" and "three-four" (10, fits)
        #expect(lines.count == 2)
        #expect(lines[0] == "one-two")
        #expect(lines[1] == "three-four")
    }

    @Test func wrapsAtComma() {
        let result = wrap("alpha,beta,gamma,delta", width: 12, breakCharacter: ",")
        let lines = result.components(separatedBy: "\n")
        // "alpha,beta," (11) fits, +gamma = 17 doesn't
        #expect(lines[0] == "alpha,beta")
        #expect(lines[1] == "gamma,delta")
    }

    // MARK: - ANSI-aware wrapping

    @Test func preservesAnsiCodesInWrappedOutput() {
        let styled = "\u{1B}[31mHello World\u{1B}[0m"
        let result = wrap(styled, width: 6)
        // Should wrap at space, preserving ANSI codes
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].contains("\u{1B}[31m"))
        #expect(visibleWidth(of: lines[0]) <= 6)
        #expect(visibleWidth(of: lines[1]) <= 6)
    }

    @Test func ansiDoesNotCountTowardWidth() {
        // "\e[1;31m" + "Hi" + "\e[0m" = visible width 2
        let styled = "\u{1B}[1;31mHi There\u{1B}[0m"
        let result = wrap(styled, width: 5)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(visibleWidth(of: lines[0]) <= 5)
        #expect(visibleWidth(of: lines[1]) <= 5)
    }

    @Test func styleCarriesAcrossWrappedLines() {
        // Bold red text that wraps: style should be closed and reopened
        let styled = "\u{1B}[1m\u{1B}[31mHello World\u{1B}[0m"
        let result = wrap(styled, width: 6)
        let lines = result.components(separatedBy: "\n")

        // First line should end with a reset (since styles were active)
        #expect(lines[0].hasSuffix("\u{1B}[0m"))

        // Second line should start with the re-opened styles
        #expect(lines[1].hasPrefix("\u{1B}[1m\u{1B}[31m"))
    }

    @Test func resetInMiddleClearsStyleCarryOver() {
        // Red "Hello" then reset, then unstyled "World"
        let styled = "\u{1B}[31mHello\u{1B}[0m World"
        let result = wrap(styled, width: 6)
        let lines = result.components(separatedBy: "\n")
        // "Hello" (styled) fits in 6, then break at space
        // "World" has no active styles — should NOT get style prefix
        #expect(lines.count == 2)
        #expect(!lines[1].contains("\u{1B}["))
    }

    @Test func noRedundantResetWhenNoStylesActive() {
        // Plain text wrap — no ANSI codes in output
        let result = wrap("Hello World", width: 6)
        #expect(!result.contains("\u{1B}"))
    }

    // MARK: - Wide (CJK) characters

    @Test func wrapsWithWideCharacters() {
        // Each CJK char is 2 columns wide
        // "\u{4F60}\u{597D}\u{4E16}\u{754C}" = 你好世界 = 8 columns
        let result = wrap("你好世界", width: 5)
        let lines = result.components(separatedBy: "\n")
        // "你好" = 4 cols, adding "世" would be 6 > 5 → break
        #expect(lines.count == 2)
        #expect(visibleWidth(of: lines[0]) <= 5)
        #expect(visibleWidth(of: lines[1]) <= 5)
    }

    @Test func wideCharacterAtExactBoundary() {
        // "AB你" = 2 + 2 = 4 cols in width 4 → fits exactly
        #expect(wrap("AB你", width: 4) == "AB你")
    }

    // MARK: - Edge cases

    @Test func singleCharacterPerLine() {
        let result = wrap("abcd", width: 1)
        #expect(result == "a\nb\nc\nd")
    }

    @Test func trailingSpacesHandledCorrectly() {
        let result = wrap("Hello   World", width: 8)
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
    }

    @Test func leadingSpacePreserved() {
        let result = wrap(" Hello World", width: 7)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == " Hello")
        #expect(lines[1] == "World")
    }

    @Test func multipleConsecutiveSpaces() {
        let result = wrap("A  B", width: 2)
        let lines = result.components(separatedBy: "\n")
        // "A" then space (break), then space then "B"
        // First: "A " doesn't exceed 2 (width 2), then next space: width would be 3 > 2 → break at last space
        #expect(lines[0] == "A")
    }

    @Test func wrapComposesWithOtherFunctions() {
        // Wrap then border
        let wrapped = wrap("Hello World, this is a long line.", width: 16)
        let bordered = border(wrapped, .rounded)
        let lines = bordered.components(separatedBy: "\n")
        // All lines should have the same visible width (border makes it rectangular)
        let widths = lines.map { visibleWidth(of: $0) }
        #expect(widths.allSatisfy { $0 == widths[0] })
    }
}
