import Foundation
import Chai
import Latte
import Spices

// MARK: - Model

/// A grocery checklist built on ``SelectableList``.
///
/// - `↑`/`↓` or `j`/`k`  — move the cursor
/// - `space`              — tick / untick an item
/// - `ctrl+a`             — tick every item
/// - `esc`                — untick every item
/// - `q` / `ctrl+c`       — quit
struct GroceryList: Model {

    // MARK: Item type

    struct Item: ListItem, ExpressibleByStringLiteral {
        typealias StringLiteralType = String
        let name: String
        init(stringLiteral value: String) { self.name = value }
        func filterValue() -> String { name }
    }

    // MARK: State

    var picker: SelectableList
    var help: Help

    // MARK: Init

    init() {
        let items: [any ListItem] = [
            Item(stringLiteral: "Carrots"),
            Item(stringLiteral: "Celery"),
            Item(stringLiteral: "Kohlrabi"),
            Item(stringLiteral: "Oat milk"),
            Item(stringLiteral: "Sourdough"),
            Item(stringLiteral: "Garlic"),
            Item(stringLiteral: "Lemons"),
            Item(stringLiteral: "Onions"),
        ]

        picker = SelectableList(items: items, width: 36, height: items.count)

        // Style the selected state in green so ticked items stand out.
        picker.styles.selectedRune           = "●"
        picker.styles.unselectedRune         = "○"
        picker.styles.selectedRuneStyle      = Style().foreground(.ansi(.green))
        picker.styles.unselectedRuneStyle    = Style(isDim: true)
        picker.styles.selectedStyle          = Style().foreground(.ansi(.green))
        picker.styles.focusedSelectedStyle   = Style(isBold: true).foreground(.ansi(.green))
        picker.styles.focusedStyle           = Style(isBold: true)
        picker.styles.normalStyle            = Style(isDim: true)

        // Disable the built-in quit bindings so we can handle exit ourselves
        // and print a farewell summary. Re-enable forceQuit to keep ctrl+c.
        picker.keyMap.quit.isEnabled = false

        help = Help(width: 36)
    }

    // MARK: ELM interface

    mutating func initialize() -> Command? {
        picker.initialize()
    }

    mutating func update(_ msg: any Message) -> Command? {
        // Let the list handle navigation, toggling, and ctrl+c.
        if let cmd = picker.update(msg) { return cmd }

        // `q` — show a summary then quit.
        if let key = msg as? KeyMsg,
           case .runes = key.type, key.runes.first == "q" {
            return .quit
        }

        return nil
    }

    func view() -> ViewOutput {
        // ── Title ──────────────────────────────────────────────────────────
        let titleStyle  = Style(isBold: true).foreground(.ansi(.cyan))
        let title       = titleStyle.render("  Grocery List")

        // ── Divider ────────────────────────────────────────────────────────
        let divider     = Style(isDim: true).render(String(repeating: "─", count: 36))

        // ── Items ──────────────────────────────────────────────────────────
        let listView    = picker.view().content

        // ── Status bar ─────────────────────────────────────────────────────
        let inCart      = picker.selectedIndices.count
        let total       = picker.items.count
        let statusText: String
        if inCart == 0 {
            statusText = Style(isDim: true).render("  Nothing in cart yet")
        } else if inCart == total {
            statusText = Style().foreground(.ansi(.green)).render(
                "  All \(total) items in cart ✓"
            )
        } else {
            statusText = Style().foreground(.ansi(.yellow)).render(
                "  \(inCart) of \(total) items in cart"
            )
        }

        // ── Help bar ───────────────────────────────────────────────────────
        let helpText    = Style(isDim: true).render(
            "  " + help.view(keyMap: picker.keyMap)
        )

        // ── Compose ────────────────────────────────────────────────────────
        let content = [
            "",
            title,
            divider,
            listView,
            divider,
            statusText,
            helpText,
            "",
        ].joined(separator: "\n")

        var out = ViewOutput(content)
        out.altScreen = true
        return out
    }
}

// MARK: - Entry point

@main
struct App {
    static func main() async {
        let finalModel: GroceryList
        do {
            finalModel = try await Program(GroceryList()).run()
        } catch {
            print("Error: \(error)")
            return
        }

        // Print a plain-text summary of what ended up in the cart.
        let selected = finalModel.picker.selectedItems
        if selected.isEmpty {
            print("Cart is empty — nothing to buy!")
        } else {
            print("Shopping list:")
            for item in selected {
                print("  • \(item.filterValue())")
            }
        }
    }
}
