import Testing
import Chai

@Suite("Structural Views")
struct StructuralViewTests {

    // MARK: - Test views

    /// A minimal custom view whose body is a `ViewOutput` leaf.
    private struct Label: View {
        let text: String
        var body: ViewOutput { ViewOutput(text) }
    }

    /// A view whose `@ViewBuilder` body produces a two-child `TupleView`.
    private struct Pair: View {
        let first: String
        let second: String

        @ViewBuilder var body: some View {
            Text(first)
            Text(second)
        }
    }

    /// A view that resolves through another custom view (two levels deep).
    private struct Wrapper: View {
        let pair: Pair
        var body: some View { pair }
    }

    /// A view with `if` but no `else` (builds an `OptionalView`).
    private struct OptionalTree: View {
        let showDetail: Bool

        @ViewBuilder var body: some View {
            Text("header")
            if showDetail {
                Text("detail")
            }
        }
    }

    /// A view with `if/else` (builds a `ConditionalContent`).
    private struct ConditionalTree: View {
        let enabled: Bool

        @ViewBuilder var body: some View {
            if enabled {
                Text("on")
            } else {
                Text("off")
            }
        }
    }

    /// A view with a `for` loop (builds a `ForEachView`).
    private struct LoopTree: View {
        let items: [String]

        @ViewBuilder var body: some View {
            for item in items {
                Text(item)
            }
        }
    }

    /// Resolves a view tree to its plain-text output for comparison.
    private func resolve(_ view: some View) -> String {
        view._resolveToViewOutput().content.plainText
    }

    // MARK: - TupleView

    @Test func tupleViewStacksChildrenVertically() {
        #expect(resolve(Pair(first: "a", second: "b")) == "a\nb")
    }

    @Test func tupleViewSingleChildPassesThrough() {
        struct Single: View {
            @ViewBuilder var body: some View {
                Text("only")
            }
        }
        #expect(resolve(Single()) == "only")
    }

    @Test func tupleViewSkipsEmptyChildren() {
        struct WithEmpty: View {
            @ViewBuilder var body: some View {
                Text("a")
                Empty()
                Text("b")
            }
        }
        #expect(resolve(WithEmpty()) == "a\nb")
    }

    @Test func tupleViewAcceptsViewOutputDirectly() {
        struct Mixed: View {
            @ViewBuilder var body: some View {
                ViewOutput("raw")
                Text("styled")
            }
        }
        #expect(resolve(Mixed()) == "raw\nstyled")
    }

    @Test func viewBuilderAcceptsStringLiteral() {
        struct Literal: View {
            let count: Int

            @ViewBuilder var body: some View {
                "Count: \(count)"
            }
        }
        #expect(resolve(Literal(count: 3)) == "Count: 3")
    }

    @Test func viewBuilderMixesLiteralAndView() {
        struct Mixed: View {
            @ViewBuilder var body: some View {
                Text("header")
                "a literal row"
                Text("footer")
            }
        }
        #expect(resolve(Mixed()) == "header\na literal row\nfooter")
    }

    @Test func tupleViewCollectsOneViewPerChild() {
        let tuple = TupleView(Text("a"), Text("b"))
        #expect(tuple._childViews().map { $0._resolveToViewOutput().content.plainText } == ["a", "b"])
    }

    @Test func tupleViewFlattensStructuralChildren() {
        // A `ForEachView` nested inside a `TupleView` is transparent: the
        // tuple enumerates the loop's elements, not the loop itself.
        let tuple = TupleView(Text("x"), ForEachView([Text("a"), Text("b")]))
        #expect(tuple._childViews().map { $0._resolveToViewOutput().content.plainText } == ["x", "a", "b"])
    }

    // MARK: - View resolution

    @Test func viewOutputResolvesToItself() {
        let output = ViewOutput("leaf")
        #expect(output._resolveToViewOutput().content.plainText == "leaf")
    }

    @Test func defaultChildViewsReturnsSelf() {
        #expect(Label(text: "z")._childViews().map { $0._resolveToViewOutput().content.plainText } == ["z"])
    }

    @Test func resolutionRecursesThroughCustomViews() {
        #expect(resolve(Wrapper(pair: Pair(first: "a", second: "b"))) == "a\nb")
    }

    // MARK: - OptionalView

    @Test func optionalViewShowsContentWhenConditionTrue() {
        #expect(resolve(OptionalTree(showDetail: true)) == "header\ndetail")
    }

    @Test func optionalViewOmitsContentWhenConditionFalse() {
        #expect(resolve(OptionalTree(showDetail: false)) == "header")
    }

    // MARK: - ConditionalContent

    @Test func conditionalContentRendersActiveBranch() {
        #expect(resolve(ConditionalTree(enabled: true)) == "on")
        #expect(resolve(ConditionalTree(enabled: false)) == "off")
    }

    // MARK: - ForEachView

    @Test func forEachViewStacksChildrenVertically() {
        #expect(resolve(LoopTree(items: ["a", "b", "c"])) == "a\nb\nc")
    }

    @Test func forEachViewWithNoItemsIsEmpty() {
        #expect(resolve(LoopTree(items: [])) == "")
    }

    @Test func forEachViewCollectsOneViewPerElement() {
        let forEach = ForEachView([Text("a"), Text("b")])
        #expect(forEach._childViews().map { $0._resolveToViewOutput().content.plainText } == ["a", "b"])
    }

    // MARK: - Primitives

    @Test func textResolvesToItsContent() {
        #expect(Text("hello")._resolveToViewOutput().content.plainText == "hello")
    }

    @Test func textPassesStyledContentThrough() {
        let styled = StyledText("a") + StyledText("b")
        #expect(Text(styled).body.content == styled)
    }

    @Test func horizontalSpacerProducesSpaces() {
        #expect(Spacer(columns: 3).body.content.plainText == "   ")
    }

    @Test func verticalSpacerProducesNewlines() {
        #expect(Spacer(lines: 2).body.content.plainText == "\n\n")
    }

    @Test func emptyViewProducesNoContent() {
        #expect(Empty().body.content.plainText == "")
    }
}
