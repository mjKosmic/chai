import Testing
import Chai

// MARK: - Simple-path contract
//
// The tested guarantee that a complete app can be built **without engine
// concepts** — no `_measure`, no `_embed`, no custom `View` conformer.
//
// A `body: some View` composed from a `ViewOutput` leaf and the tree
// modifiers (`.padded`, `.bordered`, `.frame`, ...) is the simple path. This
// suite is a standing contract: nothing may regress it.

@Suite("Simple-path contract")
struct SimplePathContractTests {

    /// The tree path: state, `update`, and a `body` built from a `ViewOutput`
    /// leaf with the tree modifiers.
    private struct TodoApp: Model {
        var items: [String] = ["milk", "eggs"]
        var status: String = "ready"

        mutating func initialize() -> Command? { nil }

        mutating func update(_ msg: any Message) -> Command? {
            guard let key = msg as? KeyMsg else { return nil }
            switch key.type {
            case .ctrl("c"):
                return .quit
            case .up:
                items.append("item \(items.count + 1)")
            case .down:
                if !items.isEmpty { items.removeLast() }
            default:
                break
            }
            return nil
        }

        var body: some View {
            let header = "Todo (\(status))".bold()
            let list = items.map { "- \($0)" }.joined(separator: "\n")
            let content: StyledText = "\(header)\n\n\(list)"
            return ViewOutput(content).padded(1).bordered(.rounded)
        }
    }

    /// A body made of a single leaf, with no container at all.
    private struct LeafOnlyApp: Model {
        mutating func initialize() -> Command? { nil }

        mutating func update(_ msg: any Message) -> Command? { nil }

        var body: some View {
            Text("Just one leaf")
        }
    }

    @Test func bodyWithASingleLeafIsACompleteFrame() {
        let rows = visibleRows(embedBuffer(LeafOnlyApp(), width: 40))
        #expect(rows == ["Just one leaf"])
    }

    @Test func treePathRendersTheApp() {
        let rows = visibleRows(embedBuffer(TodoApp(), width: 24))
        #expect(rows.contains { $0.contains("Todo (ready)") })
        #expect(rows.contains { $0.contains("- milk") })
        #expect(rows.contains { $0.contains("- eggs") })
    }

    @Test func treePathAfterAnUpdateStaysOnTheSimplePath() {
        var app = TodoApp()
        #expect(app.update(KeyMsg(type: .up)) == nil)
        let rows = visibleRows(embedBuffer(app, width: 24))
        #expect(rows.contains { $0.contains("item 3") })
    }

    @Test func simplePathQuitKeyStillFlowsThroughUpdate() {
        var app = TodoApp()
        let command = app.update(KeyMsg(type: .ctrl("c")))
        if case .quit = command {} else {
            Issue.record("expected the quit key to return .quit, got \(String(describing: command))")
        }
    }

    @Test func simplePathModelImplementsNoEngineMembers() {
        // Structural proof of the contract: `TodoApp` implements only Model's
        // required members and composes with the tree modifiers. Rendering it
        // through the allocation engine is the body-resolving default path,
        // with no engine code in the app.
        #expect(visibleRows(embedBuffer(TodoApp(), width: 24)).count > 1)
    }
}
