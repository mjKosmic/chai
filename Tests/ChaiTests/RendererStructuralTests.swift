import Testing
@testable import Chai

/// Tests that structural view trees render correctly through
/// `Renderer.write(_:)` — the generic `View` overload added by the
/// declarative migration. The event loop feeds `model.body` here, so
/// these tests cover the seam a `var body: some View` model uses.
@Suite("Renderer Structural Views")
struct RendererStructuralTests {

    @Test func structuralTreeRenders() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(TupleView(Text("Alpha"), Text("Beta")))
        await renderer.flush()
        #expect(mock.output.contains("Alpha"))
        #expect(mock.output.contains("Beta"))
    }

    @Test func forLoopViewRenders() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ForEachView([Text("One"), Text("Two"), Text("Three")]))
        await renderer.flush()
        #expect(mock.output.contains("One"))
        #expect(mock.output.contains("Two"))
        #expect(mock.output.contains("Three"))
    }

    @Test func conditionalRendersActiveBranch() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        let conditional: ConditionalContent<Text, Empty> = .first(Text("on"))
        await renderer.write(conditional)
        await renderer.flush()
        #expect(mock.output.contains("on"))
        #expect(!mock.output.contains("off"))
    }

    @Test func literalExpressionRendersThroughWrite() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(ViewOutput("Count: 3"))
        await renderer.flush()
        #expect(mock.output.contains("Count: 3"))
    }

    @Test func unchangedTreeIsNotRewritten() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(TupleView(Text("Same"), Text("Content")))
        await renderer.flush()
        mock.reset()
        await renderer.flush()
        #expect(mock.output.isEmpty)
    }

    @Test func modifiedTreeIsRewritten() async {
        let mock = MockTerminal()
        let renderer = Renderer(terminal: mock)
        await renderer.write(TupleView(Text("First"), Text("row")))
        await renderer.flush()
        mock.reset()
        await renderer.write(TupleView(Text("First"), Text("CHANGED")))
        await renderer.flush()
        #expect(mock.output.contains("CHANGED"))
    }
}
