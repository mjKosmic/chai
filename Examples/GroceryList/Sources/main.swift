import Foundation
import Chai
import Spices

// MARK: - Model

/// A simple grocery list demonstrating the core Chai Model-Update-View loop.
///
/// - Arrow keys (↑/↓) or vim keys (k/j) move the cursor.
/// - Enter or Space toggles the selected state of the current item.
/// - `q` or Ctrl+C quits.
struct GroceryList: Model {

    struct Item: ListItem, ExpressibleByStringLiteral {
        typealias StringLiteralType = String

        var value: String

        init(stringLiteral value: StringLiteralType) {
            self.value = value
        }

        func filterValue() -> String {
            return value
        }
    }

    // MARK: - State

    var choices: [Item] = [
        "Buy carrots",
        "Buy celery",
        "Buy kohlrabi",
        "Buy oat milk",
        "Buy sourdough",
    ]

    var indicator: Int = 0
    var selected: Set<Int> = []
    var list: List

    // MARK: - Model

    init() {
        list = List(items: choices)
        list.title = "Grocery List"
        list.showTitle = true
        
        var styles: ListStyles = .init()
        styles.titleBar = .init(foreground: .ansi(.blue), background: .ansi(.black), isBold: true, isDim: false, isItalic: true, isUnderline: true, isStrikethrough: false, isReverse: false, isBlink: false)
        list.styles = styles
    }

    mutating func initialize() -> Command? {
        return list.initialize()
    }

    mutating func update(_ msg: any Message) -> Command? {
        return list.update(msg)
    }

    func view() -> ViewOutput {
        var view = list.view()
        view.altScreen = true
        return view
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
