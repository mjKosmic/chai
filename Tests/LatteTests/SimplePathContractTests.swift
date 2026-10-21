import Testing
import Chai
import Latte

// MARK: - Simple-path contract (phase 4, P1)
//
// The tested guarantee behind the phase-4 positioning decision (UPGRADE.md,
// "Phase 4 — positioning"): a complete app can be built with `body: ViewOutput`
// + strings + Latte's eager helpers, with **zero engine concepts** — no
// `_sizeThatFits`, no `_embed`, no view tree. The runtime + string path is the
// stable core; the allocation engine must render such a model exactly like the
// eager path.
//
// This suite is a phase gate: nothing may regress the simple path.

@Suite("Simple-path contract")
struct SimplePathContractTests {

    /// A complete model: state, `update`, and a `body` that is plain
    /// `ViewOutput`, composed with strings and Latte's eager helpers.
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

        var body: ViewOutput {
            let header = "Todo (\(status))".bold()
            let list = items.map { "- \($0)" }.joined(separator: "\n")
            let content: StyledText = "\(header)\n\n\(list)"
            return ViewOutput(content).padded(1).bordered(.rounded)
        }
    }

    @Test func simplePathRendersIdenticallyOnEveryPath() {
        let app = TodoApp()
        let eager = visibleRows(eagerBuffer(app, width: 24))
        let engine = visibleRows(engineBuffer(app, width: 24))
        let embed = visibleRows(embedBuffer(app, width: 24))
        #expect(embed == eager)
        #expect(engine == eager)
        #expect(embed.contains(where: { $0.contains("Todo (ready)") }))
        #expect(embed.contains(where: { $0.contains("- milk") }))
    }

    @Test func simplePathAfterAnUpdateStaysOnTheSimplePath() {
        var app = TodoApp()
        #expect(app.update(KeyMsg(type: .up)) == nil)
        let embed = visibleRows(embedBuffer(app, width: 24))
        #expect(embed.contains(where: { $0.contains("item 3") }))
        #expect(visibleRows(engineBuffer(app, width: 24)) == embed)
        #expect(visibleRows(eagerBuffer(app, width: 24)) == embed)
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
        // required members. Rendering it through the allocation engine is the
        // body-resolving default path, with no engine code in the app.
        #expect(visibleRows(embedBuffer(TodoApp(), width: 24)).count > 1)
    }
}
