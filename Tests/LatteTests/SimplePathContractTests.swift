import Testing
import Chai
import Latte

// MARK: - Simple-path contract (phase 4, P1; rebuilt on the wrappers in P4b)
//
// The tested guarantee behind the phase-4 positioning decision (UPGRADE.md,
// "Phase 4 — positioning"): a complete app can be built **without engine
// concepts** — no `_measure`, no `_embed`, no custom `View` conformer.
//
// P4b retired the eager `ViewOutput` modifier family, so the contract now has
// two equally supported shapes, both pinned here:
//
// 1. **Tree path** — `body: some View` composed from `ViewOutput` leaves and
//    Latte's tree modifiers (`.padded`, `.bordered`, `.frame`, ...).
// 2. **String path** — `body: ViewOutput` built from strings and Latte's
//    String helpers (`String.padded`, `String.bordered`, ...), which are
//    raster helpers and never touch the layout engine.
//
// This suite is a phase gate: nothing may regress either simple path.

@Suite("Simple-path contract")
struct SimplePathContractTests {

    /// The tree path: state, `update`, and a `body` built from a `ViewOutput`
    /// leaf with Latte's tree modifiers.
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

    /// The string path: `body: ViewOutput`, plain strings, and Latte's
    /// String-level helpers only.
    private struct StringPathApp: Model {
        var items: [String] = ["milk", "eggs"]

        mutating func initialize() -> Command? { nil }

        mutating func update(_ msg: any Message) -> Command? { nil }

        var body: ViewOutput {
            let list = items.map { "- \($0)" }.joined(separator: "\n")
            let content = "Todo (ready)\n\n\(list)"
            return ViewOutput(content.padded(1).bordered(.rounded))
        }
    }

    @Test func treePathRendersTheApp() {
        let rows = visibleRows(embedBuffer(TodoApp(), width: 24))
        #expect(rows.contains { $0.contains("Todo (ready)") })
        #expect(rows.contains { $0.contains("- milk") })
        #expect(rows.contains { $0.contains("- eggs") })
    }

    @Test func stringPathRendersWithoutEngineConcepts() {
        // `StringPathApp.body` is a `ViewOutput` built entirely from strings
        // and String helpers — no `View` conformer, no engine members.
        let rows = visibleRows(embedBuffer(StringPathApp(), width: 24))
        #expect(rows.contains { $0.contains("Todo (ready)") })
        #expect(rows.contains { $0.contains("- milk") })
    }

    @Test func bothSimplePathsRenderTheSameRows() {
        #expect(
            visibleRows(embedBuffer(StringPathApp(), width: 24))
                == visibleRows(embedBuffer(TodoApp(), width: 24))
        )
    }

    @Test func treePathAfterAnUpdateStaysOnTheSimplePath() {
        var app = TodoApp()
        #expect(app.update(KeyMsg(type: .up)) == nil)
        let rows = visibleRows(embedBuffer(app, width: 24))
        #expect(rows.contains { $0.contains("item 3") })
    }

    @Test func stringPathBodyIsAViewOutput() {
        // Structural proof: the model's body type is `ViewOutput`, the
        // terminal leaf, so its app code never mentions the engine.
        let body: ViewOutput = StringPathApp().body
        #expect(body.content.plainText.contains("Todo (ready)"))
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
        // required members and composes with Latte helpers. Rendering it
        // through the allocation engine is the body-resolving default path,
        // with no engine code in the app.
        #expect(visibleRows(embedBuffer(TodoApp(), width: 24)).count > 1)
    }
}
