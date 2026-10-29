import Testing
import Chai

@Suite("Stacks")
struct StackTests {

    // MARK: - Test views

    /// A minimal custom view whose body is a `ViewOutput` leaf.
    private struct Label: View {
        let text: String
        var body: ViewOutput { ViewOutput(text) }
    }

    /// A minimal model — models are views, so they compose as children.
    private struct Ticker: Model {
        var body: ViewOutput { ViewOutput("tick") }

        mutating func initialize() -> Command? { nil }

        mutating func update(_ msg: any Message) -> Command? { nil }
    }

    /// Renders a stack through the allocation engine and returns its visible
    /// rows (parity convention: trailing spaces stripped).
    private func lines(_ stack: some View) -> [String] {
        visibleRows(embedBuffer(stack, width: 40))
    }

    // MARK: - VStack

    @Test func vstackStacksChildrenVertically() {
        let stack = VStack {
            Text("a")
            Text("b")
        }
        #expect(lines(stack) == ["a", "b"])
    }

    @Test func vstackSingleChildPassesThrough() {
        let stack = VStack {
            Text("only")
        }
        #expect(lines(stack) == ["only"])
    }

    @Test func vstackSkipsEmptyChildren() {
        let stack = VStack {
            Text("a")
            Empty()
            Text("b")
        }
        #expect(lines(stack) == ["a", "b"])
    }

    @Test func vstackLeftAlignmentLeavesLinesUnpadded() {
        let stack = VStack(alignment: .left) {
            Text("ab")
            Text("cdef")
        }
        #expect(lines(stack) == ["ab", "cdef"])
    }

    @Test func vstackCenterAlignmentPadsLines() {
        let stack = VStack(alignment: .center) {
            Text("ab")
            Text("cdef")
        }
        #expect(lines(stack) == [" ab", "cdef"])
    }

    @Test func vstackRightAlignmentPadsLines() {
        let stack = VStack(alignment: .right) {
            Text("ab")
            Text("cdef")
        }
        #expect(lines(stack) == ["  ab", "cdef"])
    }

    @Test func vstackLaysOutForLoopVertically() {
        let stack = VStack {
            for item in ["a", "b", "c"] {
                Text(item)
            }
        }
        #expect(lines(stack) == ["a", "b", "c"])
    }

    @Test func vstackRendersActiveConditionalBranch() {
        let stack = VStack {
            if true {
                Text("on")
            } else {
                Text("off")
            }
        }
        #expect(lines(stack) == ["on"])
    }

    @Test func vstackAcceptsStringLiteralExpressions() {
        let stack = VStack {
            Text("header")
            "a literal row"
        }
        #expect(lines(stack) == ["header", "a literal row"])
    }

    @Test func hstackToleratesLeadingEmptyChild() {
        let stack = HStack {
            Empty()
            Text("a")
        }
        #expect(lines(stack) == ["a"])
    }

    @Test func hstackToleratesEmptyForLoop() {
        let stack = HStack {
            Text("x")
            for item in [String]() {
                Text(item)
            }
            Text("y")
        }
        #expect(lines(stack) == ["xy"])
    }

    @Test func styledContentSurvivesVStackAlignment() {
        let stack = VStack(alignment: .center) {
            Text("err".fg(.red))
            Text("ok")
        }
        let buffer = embedBuffer(stack, width: 8)
        // The stack is 3 wide ("err"); "ok" is 2 wide, so the center shortage
        // is 1 and `Int(1 × 0.5)` = 0 — the block stays at col 0. The style
        // survives.
        #expect(visibleRows(buffer) == ["err", "ok"])
        #expect(buffer[0, 0].foreground == .red)
    }

    @Test func styledContentSurvivesHStack() {
        let stack = HStack {
            Text("a".fg(.red))
            Text("b")
        }
        let buffer = embedBuffer(stack, width: 8)
        #expect(visibleRows(buffer) == ["ab"])
        #expect(buffer[0, 0].foreground == .red)
    }

    @Test func threeLevelNesting() {
        let stack = VStack {
            HStack {
                Text("a")
                Text("b")
            }
            HStack {
                Text("c")
                for item in ["d", "e"] {
                    Text(item)
                }
            }
        }
        #expect(lines(stack) == ["ab", "cde"])
    }

    // MARK: - HStack

    @Test func hstackPlacesChildrenSideBySide() {
        let stack = HStack {
            Text("a")
            Text("b")
        }
        #expect(lines(stack) == ["ab"])
    }

    @Test func hstackPadsShorterChildren() {
        let stack = HStack {
            Text("a\nb")
            Text("1")
        }
        #expect(lines(stack) == ["a1", "b"])
    }

    @Test func hstackWithBottomAlignment() {
        let stack = HStack(alignment: .bottom) {
            Text("a\nb")
            Text("1")
        }
        #expect(lines(stack) == ["a", "b1"])
    }

    @Test func hstackSkipsEmptyChildren() {
        let stack = HStack {
            Text("a")
            Empty()
            Text("b")
        }
        #expect(lines(stack) == ["ab"])
    }

    @Test func hstackLaysOutForLoopHorizontally() {
        // `ForEachView` is transparent to containers: the loop's elements
        // participate in the horizontal layout, not the loop as a whole.
        let stack = HStack {
            for item in ["a", "b", "c"] {
                Text(item)
            }
        }
        #expect(lines(stack) == ["abc"])
    }

    @Test func hstackFlattensMultiExpressionLoopBodies() {
        let stack = HStack {
            for item in ["a", "b"] {
                Text(item)
                Text(item)
            }
        }
        #expect(lines(stack) == ["aabb"])
    }

    @Test func hstackMixesChildrenAndForLoop() {
        let stack = HStack {
            Text("x")
            for item in ["a", "b"] {
                Text(item)
            }
            Text("y")
        }
        #expect(lines(stack) == ["xaby"])
    }

    @Test func hstackOmitsOptionalChildWhenConditionFalse() {
        let show = false
        let stack = HStack {
            Text("a")
            if show {
                Text("b")
            }
        }
        #expect(lines(stack) == ["a"])
    }

    @Test func hstackIncludesSpacerColumns() {
        let stack = HStack {
            Text("a")
            Spacer(columns: 3)
            Text("b")
        }
        #expect(lines(stack) == ["a   b"])
    }

    @Test func hstackAcceptsCustomViewsAsChildren() {
        let stack = HStack {
            Label(text: "left")
            Label(text: "right")
        }
        #expect(lines(stack) == ["leftright"])
    }

    @Test func hstackAcceptsModelsAsChildren() {
        let stack = HStack {
            Ticker()
            Text("!")
        }
        #expect(lines(stack) == ["tick!"])
    }

    // MARK: - Nesting

    @Test func hstackNestsInsideVStack() {
        let stack = VStack {
            HStack {
                Text("a")
                Text("b")
            }
            Text("c")
        }
        #expect(lines(stack) == ["ab", "c"])
    }

    @Test func vstackNestsInsideHStack() {
        let stack = HStack(alignment: .bottom) {
            Text("top\nmid")
            VStack {
                Text("a")
                Text("b")
            }
        }
        #expect(lines(stack) == ["topa", "midb"])
    }
}
