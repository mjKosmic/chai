import Testing
@testable import Chai
@testable import Latte

@Suite("Tab Expansion")
struct TabExpansionTests {

    // MARK: - Basic expansion

    @Test func tabAtStartOfLineExpandsToFullTabWidth() {
        #expect(expandTabs("\tHello") == "    Hello")
    }

    @Test func tabMidLineExpandsToNextTabStop() {
        // "ab" is at column 2; next tab stop at 4 → 2 spaces
        #expect(expandTabs("ab\tcd") == "ab  cd")
    }

    @Test func tabAtExactTabStopExpandsToFullWidth() {
        // "abcd" fills columns 0–3; tab at column 4 → next stop at 8 → 4 spaces
        #expect(expandTabs("abcd\tx") == "abcd    x")
    }

    @Test func consecutiveTabsExpandIndependently() {
        // First tab: col 0 → 4 spaces (now at col 4)
        // Second tab: col 4 → 4 spaces (now at col 8)
        #expect(expandTabs("\t\tHi") == "        Hi")
    }

    @Test func tabOnlyStringExpandsCorrectly() {
        #expect(expandTabs("\t") == "    ")
        #expect(expandTabs("\t\t") == "        ")
    }

    // MARK: - Custom tab width

    @Test func customTabWidth2() {
        #expect(expandTabs("\tHi", tabWidth: 2) == "  Hi")
        #expect(expandTabs("a\tHi", tabWidth: 2) == "a Hi")
    }

    @Test func customTabWidth8() {
        #expect(expandTabs("\tHi", tabWidth: 8) == "        Hi")
        #expect(expandTabs("ab\tcd", tabWidth: 8) == "ab      cd")
    }

    @Test func tabWidthOfOneMeansOneSpacePerTab() {
        #expect(expandTabs("a\tb\tc", tabWidth: 1) == "a b c")
    }

    @Test func invalidTabWidthTreatedAsOne() {
        #expect(expandTabs("a\tb", tabWidth: 0) == "a b")
        #expect(expandTabs("a\tb", tabWidth: -5) == "a b")
    }

    // MARK: - Multi-line text

    @Test func eachLineHasIndependentTabStops() {
        let input = "a\tX\nab\tY\nabc\tZ"
        let result = expandTabs(input)
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "a   X")   // col 1 → 3 spaces to col 4
        #expect(lines[1] == "ab  Y")   // col 2 → 2 spaces to col 4
        #expect(lines[2] == "abc Z")   // col 3 → 1 space to col 4
    }

    @Test func emptyLinesPreserved() {
        let result = expandTabs("A\n\nB")
        #expect(result == "A\n\nB")
    }

    // MARK: - No tabs

    @Test func noTabsReturnsStringUnchanged() {
        #expect(expandTabs("Hello World") == "Hello World")
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(expandTabs("") == "")
    }

    // MARK: - ANSI-aware expansion

    @Test func ansiCodesDoNotAffectColumnTracking() {
        // "\e[31m" is an ANSI color code (red) — zero visible width
        // "ab" is 2 visible columns, then tab should go to col 4 → 2 spaces
        let styled = "\u{1B}[31mab\u{1B}[0m\tcd"
        let result = expandTabs(styled)
        #expect(result == "\u{1B}[31mab\u{1B}[0m  cd")
        #expect(visibleWidth(of: result) == 6) // "ab  cd" = 6 cols
    }

    @Test func ansiCodesPreservedInOutput() {
        let styled = "\u{1B}[1;32mHello\u{1B}[0m"
        let result = expandTabs(styled)
        #expect(result == styled) // no tabs, string unchanged
    }

    @Test func tabInsideStyledText() {
        // Tab between styled segments
        let input = "\u{1B}[31mA\u{1B}[0m\t\u{1B}[32mB\u{1B}[0m"
        let result = expandTabs(input)
        // "A" at col 0, visible width 1, tab → 3 spaces to reach col 4
        #expect(result == "\u{1B}[31mA\u{1B}[0m   \u{1B}[32mB\u{1B}[0m")
        #expect(visibleWidth(of: result) == 5) // "A   B" = 5 cols
    }

    // MARK: - String extension

    @Test func tabsExpandedDefault() {
        #expect("\tHello".tabsExpanded() == expandTabs("\tHello"))
    }

    @Test func tabsExpandedCustomWidth() {
        #expect("\tHello".tabsExpanded(tabWidth: 8) == expandTabs("\tHello", tabWidth: 8))
    }
}
