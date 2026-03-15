import Testing
@testable import Latte

@Suite("DisplayWidth")
struct DisplayWidthTests {

    // MARK: - displayWidth(of: Character)

    @Test func asciiLetterIsWidth1() {
        #expect(displayWidth(of: Character("A")) == 1)
        #expect(displayWidth(of: Character("z")) == 1)
    }

    @Test func asciiDigitIsWidth1() {
        #expect(displayWidth(of: Character("0")) == 1)
        #expect(displayWidth(of: Character("9")) == 1)
    }

    @Test func asciiPunctuationIsWidth1() {
        #expect(displayWidth(of: Character("!")) == 1)
        #expect(displayWidth(of: Character(" ")) == 1)
    }

    @Test func cjkIdeographIsWidth2() {
        #expect(displayWidth(of: Character("你")) == 2)  // U+4F60
        #expect(displayWidth(of: Character("好")) == 2)  // U+597D
        #expect(displayWidth(of: Character("漢")) == 2)  // U+6F22
    }

    @Test func hangulSyllableIsWidth2() {
        #expect(displayWidth(of: Character("한")) == 2)  // U+D55C
        #expect(displayWidth(of: Character("글")) == 2)  // U+AE00
    }

    @Test func fullwidthLatinIsWidth2() {
        #expect(displayWidth(of: Character("Ａ")) == 2)  // U+FF21
        #expect(displayWidth(of: Character("ａ")) == 2)  // U+FF41
    }

    @Test func controlCharacterIsWidth0() {
        #expect(displayWidth(of: Character("\u{00}")) == 0)   // NUL
        #expect(displayWidth(of: Character("\u{1B}")) == 0)   // ESC
        #expect(displayWidth(of: Character("\u{7F}")) == 0)   // DEL
    }

    // MARK: - visibleWidth(of: String)

    @Test func plainASCIIWidth() {
        #expect(visibleWidth(of: "Hello") == 5)
        #expect(visibleWidth(of: "Hi") == 2)
        #expect(visibleWidth(of: "") == 0)
    }

    @Test func ansiCodesExcludedFromWidth() {
        // "\e[31mHello\e[0m" — 5 visible characters
        let styled = "\u{1B}[31mHello\u{1B}[0m"
        #expect(visibleWidth(of: styled) == 5)
    }

    @Test func boldAnsiExcludedFromWidth() {
        let bold = "\u{1B}[1mBold text\u{1B}[0m"
        #expect(visibleWidth(of: bold) == 9)
    }

    @Test func cjkCountsAsDouble() {
        #expect(visibleWidth(of: "你好") == 4)
    }

    @Test func mixedASCIIAndCJK() {
        #expect(visibleWidth(of: "Hi你好") == 6)  // 2 + 4
    }

    @Test func oscSequenceExcluded() {
        // OSC terminated by BEL
        let osc = "\u{1B}]0;Title\u{07}Hello"
        #expect(visibleWidth(of: osc) == 5)
    }

    @Test func oscWithSTTerminatorExcluded() {
        // OSC terminated by ST (ESC \)
        let osc = "\u{1B}]0;Title\u{1B}\\Hello"
        #expect(visibleWidth(of: osc) == 5)
    }

    @Test func ss3SequenceExcluded() {
        // SS3 Up arrow: ESC O A
        let ss3 = "\u{1B}OAHello"
        #expect(visibleWidth(of: ss3) == 5)
    }

    @Test func ss2SequenceExcluded() {
        let ss2 = "\u{1B}NxHello"
        #expect(visibleWidth(of: ss2) == 5)
    }

    @Test func twoByteEscapeExcluded() {
        // Application keypad: ESC =
        let esc = "\u{1B}=Hello"
        #expect(visibleWidth(of: esc) == 5)
    }

    // MARK: - height(of: String)

    @Test func emptyStringHeightIsZero() {
        #expect(height(of: "") == 0)
    }

    @Test func singleLineHeightIsOne() {
        #expect(height(of: "Hello") == 1)
    }

    @Test func multiLineHeight() {
        #expect(height(of: "A\nB\nC") == 3)
    }

    @Test func trailingNewlineCountsAsExtraLine() {
        // "A\n" splits into ["A", ""] → 2 lines
        #expect(height(of: "A\n") == 2)
    }

    // MARK: - size(of: String)

    @Test func singleLineSizeMatchesWidthAndOne() {
        let (w, h) = size(of: "Hello")
        #expect(w == 5)
        #expect(h == 1)
    }

    @Test func multiLineSizeUsesMaxWidth() {
        let (w, h) = size(of: "Hi\nHello\nBye")
        #expect(w == 5)
        #expect(h == 3)
    }

    @Test func sizeWithAnsiCodes() {
        let (w, h) = size(of: "\u{1B}[1mBold\u{1B}[0m")
        #expect(w == 4)
        #expect(h == 1)
    }

    // MARK: - truncateToVisibleWidth

    @Test func truncatePlainASCII() {
        #expect(truncateToVisibleWidth("ABCDEFGH", maxWidth: 5) == "ABCDE")
    }

    @Test func truncatePreservesAnsiCodes() {
        let styled = "\u{1B}[31mRed text\u{1B}[0m"
        let result = truncateToVisibleWidth(styled, maxWidth: 3)
        #expect(result.contains("\u{1B}[31m"))
        #expect(result.contains("Red"))
        #expect(!result.contains("text"))
    }

    @Test func truncateWideCharacterBoundary() {
        // "AB你" is 4 columns (1+1+2). Truncating to 3 drops 你.
        #expect(truncateToVisibleWidth("AB你", maxWidth: 3) == "AB")
    }

    @Test func truncateFitsExactly() {
        #expect(truncateToVisibleWidth("AB你", maxWidth: 4) == "AB你")
    }

    @Test func truncateZeroWidthReturnsEmpty() {
        #expect(truncateToVisibleWidth("Hello", maxWidth: 0) == "")
    }

    @Test func truncateCJKString() {
        // "你好世界" = 8 cols. Truncate to 5 → "你好" (4 cols, 世 would push to 6).
        #expect(truncateToVisibleWidth("你好世界", maxWidth: 5) == "你好")
    }

    @Test func truncateNoopWhenWidthSufficient() {
        let styled = "\u{1B}[1mBold\u{1B}[0m"
        #expect(truncateToVisibleWidth(styled, maxWidth: 10) == styled)
    }

    @Test func truncateSkipsSS3Sequence() {
        let ss3 = "\u{1B}OAHello"
        let result = truncateToVisibleWidth(ss3, maxWidth: 3)
        #expect(result.contains("\u{1B}OA"))
        #expect(result.contains("Hel"))
        #expect(!result.contains("Hello"))
    }

    @Test func truncateSkipsOSCWithSTTerminator() {
        let osc = "\u{1B}]0;Title\u{1B}\\Hello"
        let result = truncateToVisibleWidth(osc, maxWidth: 3)
        #expect(result.contains("Hel"))
        #expect(!result.contains("Hello"))
        #expect(result.contains("\u{1B}]0;"))
    }
}
