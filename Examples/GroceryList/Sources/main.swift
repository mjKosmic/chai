import Chai

// MARK: - Model

/// A simple grocery list demonstrating the core Chai Model-Update-View loop.
///
/// - Arrow keys (↑/↓) or vim keys (k/j) move the cursor.
/// - Enter or Space toggles the selected state of the current item.
/// - `q` or Ctrl+C quits.
struct GroceryList: Model {

    // MARK: - State

    var choices: [String] = [
        "Buy carrots",
        "Buy celery",
        "Buy kohlrabi",
        "Buy oat milk",
        "Buy sourdough",
    ]

    var cursor: Int = 0
    var selected: Set<Int> = []

    // MARK: - Model

    func initialize() -> Command? {
        // No initial I/O needed.
        nil
    }

    mutating func update(_ msg: any Message) -> Command? {
        guard let key = msg as? KeyMsg else { return nil }

        switch key.type {

        // ── Quit ──────────────────────────────────────────────────────────
        case .ctrl("c"):
            return .quit

        case .runes where key.runes == ["q"]:
            return .quit

        // ── Navigation ────────────────────────────────────────────────────
        case .up:
            moveCursorUp()
        case .runes where key.runes == ["k"]:
            moveCursorUp()

        case .down:
            moveCursorDown()
        case .runes where key.runes == ["j"]:
            moveCursorDown()

        // ── Selection ─────────────────────────────────────────────────────
        case .enter, .space:
            selected.formSymmetricDifference([cursor])

        default:
            break
        }

        return nil
    }

    func view() -> ViewOutput {
        var lines: [String] = []

        lines.append("What should we buy at the market?\n")

        for (i, choice) in choices.enumerated() {
            let cursorMark = cursor == i ? ">" : " "
            let checkMark  = selected.contains(i) ? "x" : " "
            lines.append("\(cursorMark) [\(checkMark)] \(choice)")
        }

        lines.append("")
        lines.append("↑/↓ or j/k to move  •  Enter/Space to select  •  q to quit")

        // Declaratively request the alternate screen buffer.
        return ViewOutput(lines.joined(separator: "\n"), altScreen: true)
    }

    // MARK: - Private helpers

    private mutating func moveCursorUp() {
        if cursor > 0 { cursor -= 1 }
    }

    private mutating func moveCursorDown() {
        if cursor < choices.count - 1 { cursor += 1 }
    }
}

// MARK: - Entry point

@main
struct App {
    static func main() async {
        do {
            try await Program(GroceryList()).run()
        } catch {
            print("Error: \(error)")
        }
    }
}
