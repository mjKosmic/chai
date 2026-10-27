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
    var menu: Menu
    var height: Int
    var width: Int

    // MARK: Init

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
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
        menu = Menu(items: items) 

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
    }

    // MARK: ELM interface

    mutating func initialize() -> Command? {
        picker.initialize()
    }

    mutating func update(_ msg: any Message) -> Command? {
        // `q` — show a summary then quit.
        if let key = msg as? KeyMsg,
           case .runes = key.type, key.runes.first == "q" {
            return .quit
        }

        if let sizeMsg = msg as? WindowSizeMsg {
            self.height = sizeMsg.height
            self.width = sizeMsg.width
        }

        if let menuMsg = msg as? MenuSelectionMsg {
            if menuMsg.menuID == self.menu.id {
                return .quit
            }
        }

        // Let the list handle navigation, toggling, and ctrl+c.
        if let cmd = picker.update(msg) { return cmd }
        if let cmd = menu.update(msg) { return cmd }

        return nil
    }

    var body: some View {
        // The header consumes the query context, so it WRAPS to the
        // frame's width (the char-level fallback guarantees it fits any
        // positive width) instead of overflowing. The HStack below is centered
        // with the header as one block via `.frame(...)`.
        VStack {
            Text("Grocery list — ↑/↓ move · space tick · ctrl+a all · esc none · q quit")
            HStack {
                picker
                menu
            }
        }
        .frame(
            width: width,
            height: height,
            horizontalAlignment: .center,
            verticalAlignment: .middle
        )
    }
}

// MARK: - Entry point

@main
struct App {
    static func main() async {
        let finalModel: GroceryList
        do {
            finalModel = try await Program(GroceryList(width: 10, height: 20), options: .withAltScreen).run()
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
