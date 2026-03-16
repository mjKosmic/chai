import Testing
@testable import Latte

// MARK: - Milestone 4.1: Static ListRenderer

@Suite("ListRenderer")
struct ListRendererTests {

    // MARK: - BulletEnumerator

    @Test func bulletEnumeratorThreeItems() {
        let renderer = ListRenderer(
            items: [ListEntry("A"), ListEntry("B"), ListEntry("C")],
            enumerator: BulletEnumerator())
        #expect(renderer.render() == "• A\n• B\n• C")
    }

    @Test func bulletEnumeratorSingleItem() {
        let renderer = ListRenderer(
            items: [ListEntry("Only")],
            enumerator: BulletEnumerator())
        #expect(renderer.render() == "• Only")
    }

    @Test func bulletEnumeratorEmptyList() {
        let renderer = ListRenderer(
            items: [],
            enumerator: BulletEnumerator())
        #expect(renderer.render() == "")
    }

    // MARK: - ArabicEnumerator

    @Test func arabicEnumeratorThreeItems() {
        let renderer = ListRenderer(
            items: [ListEntry("A"), ListEntry("B"), ListEntry("C")],
            enumerator: ArabicEnumerator())
        #expect(renderer.render() == "1. A\n2. B\n3. C")
    }

    @Test func arabicEnumeratorIndexesStartAtOne() {
        let renderer = ListRenderer(
            items: [ListEntry("First"), ListEntry("Second")],
            enumerator: ArabicEnumerator())
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[0].hasPrefix("1. "))
        #expect(lines[1].hasPrefix("2. "))
    }

    // MARK: - AlphabetEnumerator

    @Test func alphabetEnumeratorThreeItems() {
        let renderer = ListRenderer(
            items: [ListEntry("A"), ListEntry("B"), ListEntry("C")],
            enumerator: AlphabetEnumerator())
        #expect(renderer.render() == "a. A\nb. B\nc. C")
    }

    @Test func alphabetEnumeratorWrapsAfterZ() {
        // 26 items → last should be "z.", and the 27th should wrap to "a."
        let items = (0..<27).map { ListEntry("item\($0)") }
        let renderer = ListRenderer(items: items, enumerator: AlphabetEnumerator())
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[25].hasPrefix("z. "))
        #expect(lines[26].hasPrefix("a. "))
    }

    // MARK: - RomanEnumerator

    @Test func romanEnumeratorThreeItems() {
        let renderer = ListRenderer(
            items: [ListEntry("A"), ListEntry("B"), ListEntry("C")],
            enumerator: RomanEnumerator())
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[0].hasPrefix("i. "))
        #expect(lines[1].hasPrefix("ii. "))
        #expect(lines[2].hasPrefix("iii. "))
    }

    @Test func romanEnumeratorLargerValues() {
        let items = (0..<9).map { ListEntry("x\($0)") }
        let renderer = ListRenderer(items: items, enumerator: RomanEnumerator())
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[3].hasPrefix("iv. "))   // 4
        #expect(lines[4].hasPrefix("v. "))    // 5
        #expect(lines[8].hasPrefix("ix. "))   // 9
    }

    // MARK: - Nested lists

    @Test func nestedListRendererIndentation() {
        let child = ListRenderer(
            items: [ListEntry("A1"), ListEntry("A2")],
            enumerator: BulletEnumerator())
        let parent = ListRenderer(
            items: [ListEntry("A", children: child), ListEntry("B")],
            enumerator: BulletEnumerator())
        let result = parent.render()
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == "• A")
        #expect(lines[1] == "  • A1")
        #expect(lines[2] == "  • A2")
        #expect(lines[3] == "• B")
    }

    @Test func deeplyNestedList() {
        let grandchild = ListRenderer(
            items: [ListEntry("X")],
            enumerator: BulletEnumerator())
        let child = ListRenderer(
            items: [ListEntry("A1", children: grandchild)],
            enumerator: BulletEnumerator())
        let parent = ListRenderer(
            items: [ListEntry("A", children: child)],
            enumerator: BulletEnumerator())
        let result = parent.render()
        let lines = result.components(separatedBy: "\n")
        #expect(lines[0] == "• A")
        #expect(lines[1] == "  • A1")
        #expect(lines[2] == "    • X")
    }

    @Test func itemWithNoChildrenProducesNoExtraLines() {
        let renderer = ListRenderer(
            items: [ListEntry("A"), ListEntry("B")],
            enumerator: BulletEnumerator())
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines.count == 2)
    }

    // MARK: - Custom enumerator

    @Test func customEnumeratorWorks() {
        struct StarEnumerator: ListEnumerator {
            func prefix(for items: [ListEntry], at index: Int) -> String { "★ " }
        }
        let renderer = ListRenderer(
            items: [ListEntry("X"), ListEntry("Y")],
            enumerator: StarEnumerator())
        #expect(renderer.render() == "★ X\n★ Y")
    }

    // MARK: - Styling

    @Test func enumeratorStyleAppliedToPrefix() {
        let boldStyle = Style().bold()
        let renderer = ListRenderer(
            items: [ListEntry("A")],
            enumerator: BulletEnumerator(),
            enumeratorStyle: boldStyle)
        let result = renderer.render()
        // The prefix "• " should be bold-wrapped
        #expect(result.contains("\u{1B}[1m• \u{1B}[0m"))
        #expect(result.contains("A"))
    }

    @Test func itemStyleAppliedToValue() {
        let italicStyle = Style().italic()
        let renderer = ListRenderer(
            items: [ListEntry("hello")],
            enumerator: BulletEnumerator(),
            itemStyle: italicStyle)
        let result = renderer.render()
        #expect(result.contains("\u{1B}[3mhello\u{1B}[0m"))
    }

    @Test func noColorProfileStripsAllStyling() {
        let renderer = ListRenderer(
            items: [ListEntry("A"), ListEntry("B")],
            enumerator: BulletEnumerator(),
            itemStyle: Style().bold(),
            enumeratorStyle: Style().foreground(.ansi(.red)))
        let result = renderer.render(profile: .noColor)
        #expect(!result.contains("\u{1B}["))
        #expect(result == "• A\n• B")
    }
}
