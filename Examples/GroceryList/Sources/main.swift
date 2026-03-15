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

    var indicator: Int = 0
    var selected: Set<Int> = []

    // MARK: - Model

    func initialize() -> Command? {
        // Perform initial terminal I/O by setting the window title.
        .setWindowTitle("Grocery List")
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
            moveIndicatorUp()
        case .runes where key.runes == ["k"]:
            moveIndicatorUp()

        case .down:
            moveIndicatorDown()
        case .runes where key.runes == ["j"]:
            moveIndicatorDown()

        // ── Selection ─────────────────────────────────────────────────────
        case .enter, .space:
            selected.formSymmetricDifference([indicator])

        default:
            break
        }

        return nil
    }

    func view() -> ViewOutput {
        var lines: [String] = []

        lines.append("What should we buy at the market? \(self.selected.count)\n")

        for (i, choice) in choices.enumerated() {
            let cursorMark = indicator == i ? ">" : " "
            let checkMark  = selected.contains(i) ? "x" : " "
            lines.append("\(cursorMark) [\(checkMark)] \(choice)")
        }

        lines.append("")
        lines.append("↑/↓ or j/k to move  •  Enter/Space to select  •  q to quit")

        // Render without using the alternate screen buffer so output remains in scrollback.
        return ViewOutput(
            lines.joined(separator: "\n"),
            altScreen: false
        )
    }

    // MARK: - Private helpers

    private mutating func moveIndicatorUp() {
        if indicator > 0 { indicator -= 1 }
    }

    private mutating func moveIndicatorDown() {
        if indicator < choices.count - 1 { indicator += 1 }
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
