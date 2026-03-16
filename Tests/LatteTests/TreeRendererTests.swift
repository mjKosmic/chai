import Testing
@testable import Latte

// MARK: - Milestone 4.2: Static TreeRenderer

@Suite("TreeRenderer")
struct TreeRendererTests {

    // MARK: - Basic structure

    @Test func rootOnlyProducesOneLineWithRootValue() {
        let root = TreeNode("root")
        let renderer = TreeRenderer(root: root)
        #expect(renderer.render() == "root")
    }

    @Test func threeChildrenWithIntermediateAndLastConnectors() {
        let root = TreeNode(".", children: [
            TreeNode("A"),
            TreeNode("B"),
            TreeNode("C"),
        ])
        let renderer = TreeRenderer(root: root)
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines.count == 4)
        #expect(lines[0] == ".")
        #expect(lines[1] == "├── A")
        #expect(lines[2] == "├── B")
        #expect(lines[3] == "└── C")
    }

    @Test func lastChildUsesLastConnector() {
        let root = TreeNode("root", children: [TreeNode("only")])
        let renderer = TreeRenderer(root: root)
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[1] == "└── only")
    }

    // MARK: - Nested children and indentation

    @Test func nestedChildrenUnderNonLastParent() {
        let root = TreeNode(".", children: [
            TreeNode("A", children: [TreeNode("A1")]),
            TreeNode("B"),
        ])
        let renderer = TreeRenderer(root: root)
        let lines = renderer.render().components(separatedBy: "\n")
        // A is not last → continuation prefix is "│   "
        #expect(lines[2] == "│   └── A1")
    }

    @Test func nestedChildrenUnderLastParent() {
        let root = TreeNode(".", children: [
            TreeNode("A"),
            TreeNode("C", children: [TreeNode("C1"), TreeNode("C2")]),
        ])
        let renderer = TreeRenderer(root: root)
        let lines = renderer.render().components(separatedBy: "\n")
        // C is the last child → continuation prefix is "    " (4 spaces)
        #expect(lines[3] == "    ├── C1")
        #expect(lines[4] == "    └── C2")
    }

    @Test func fullThreeLevelExampleMatchesRoadmap() {
        // Reproduces the exact example from ROADMAP.md:
        // .
        // ├── A
        // │   └── A1
        // ├── B
        // └── C
        //     ├── C1
        //     └── C2
        let root = TreeNode(".", children: [
            TreeNode("A", children: [TreeNode("A1")]),
            TreeNode("B"),
            TreeNode("C", children: [TreeNode("C1"), TreeNode("C2")]),
        ])
        let renderer = TreeRenderer(root: root)
        let expected = """
        .
        ├── A
        │   └── A1
        ├── B
        └── C
            ├── C1
            └── C2
        """
        #expect(renderer.render() == expected)
    }

    // MARK: - Rounded enumerator

    @Test func roundedEnumeratorUsesArcForLastChild() {
        let root = TreeNode("root", children: [
            TreeNode("first"),
            TreeNode("last"),
        ])
        let renderer = TreeRenderer(root: root, enumerator: .rounded)
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[1] == "├── first")
        #expect(lines[2] == "╰── last")
    }

    @Test func roundedEnumeratorContinuationIndentSameAsDefault() {
        let root = TreeNode(".", children: [
            TreeNode("A", children: [TreeNode("A1")]),
            TreeNode("B"),
        ])
        let renderer = TreeRenderer(root: root, enumerator: .rounded)
        let lines = renderer.render().components(separatedBy: "\n")
        // A is non-last → continuation indent is "│   " (same for both default and rounded)
        // A1 is the last (only) child of A → uses rounded last-connector "╰── "
        #expect(lines[2] == "│   ╰── A1")
    }

    // MARK: - Custom enumerator

    @Test func customEnumeratorRendersCorrectly() {
        let custom = TreeEnumerator.custom(
            intermediate: "+-- ",
            last:         "`-- ",
            indent:       "|   ")
        let root = TreeNode("root", children: [
            TreeNode("A", children: [TreeNode("A1")]),
            TreeNode("B"),
        ])
        let renderer = TreeRenderer(root: root, enumerator: custom)
        let lines = renderer.render().components(separatedBy: "\n")
        #expect(lines[1] == "+-- A")
        #expect(lines[2] == "|   `-- A1")
        #expect(lines[3] == "`-- B")
    }

    @Test func customEnumeratorEmptyIndentIsSameWidthAsIndent() {
        // indent = "|   " (4 visible chars)  → empty indent = "    " (4 spaces)
        let custom = TreeEnumerator.custom(
            intermediate: "+-- ",
            last:         "`-- ",
            indent:       "|   ")
        let root = TreeNode(".", children: [
            TreeNode("A"),
            TreeNode("B", children: [TreeNode("B1")]),
        ])
        let renderer = TreeRenderer(root: root, enumerator: custom)
        let lines = renderer.render().components(separatedBy: "\n")
        // B is last → empty indent "    " (4 spaces)
        #expect(lines[3] == "    `-- B1")
    }

    // MARK: - ANSI codes in node values

    @Test func ansiInNodeValueDoesNotAffectConnectorAlignment() {
        let styledValue = "\u{1B}[1mBold Node\u{1B}[0m"
        let root = TreeNode("root", children: [
            TreeNode(styledValue),
            TreeNode("Plain"),
        ])
        let renderer = TreeRenderer(root: root)
        let lines = renderer.render().components(separatedBy: "\n")
        // The connector prefix must be exactly "├── " or "└── " regardless of ANSI in the value
        #expect(lines[1] == "├── \(styledValue)")
        #expect(lines[2] == "└── Plain")
    }

    // MARK: - Default enumerator via init default parameter

    @Test func defaultEnumeratorIsUsedWhenNotSpecified() {
        let root = TreeNode("r", children: [TreeNode("only")])
        let renderer = TreeRenderer(root: root)
        // Default uses "└── " (straight corner)
        #expect(renderer.render().contains("└── only"))
    }
}
