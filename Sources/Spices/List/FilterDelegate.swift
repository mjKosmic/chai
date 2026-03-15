import Chai

// MARK: - ListItem Protocol

/// A protocol for items displayed in a ``List``.
///
/// Implement this protocol on your data types to make them displayable
/// in a list. The ``filterValue()`` method is used for fuzzy filtering.
///
/// ```swift
/// struct Task: ListItem {
///     let title: String
///     let done: Bool
///
///     func filterValue() -> String { title }
/// }
/// ```
public protocol ListItem: Sendable {
    /// Returns a string used for filtering this item.
    func filterValue() -> String
}

// MARK: - ListItemDelegate Protocol

/// A protocol for rendering list items.
///
/// Implement this to control how items are displayed in the list.
/// Each item is rendered individually, with information about whether
/// it is currently selected.
///
/// ```swift
/// struct TaskDelegate: ListItemDelegate {
///     func render(item: any ListItem, index: Int, isSelected: Bool, width: Int) -> String {
///         guard let task = item as? Task else { return "" }
///         let check = task.done ? "✓" : " "
///         let prefix = isSelected ? ">" : " "
///         return "\(prefix) [\(check)] \(task.title)"
///     }
///     var height: Int { 1 }
///     var spacing: Int { 0 }
/// }
/// ```
public protocol ListItemDelegate: Sendable {
    /// Renders a single item.
    ///
    /// - Parameters:
    ///   - item: The item to render.
    ///   - index: The item's index in the visible list.
    ///   - isSelected: Whether this item is currently highlighted.
    ///   - width: The available width for rendering.
    /// - Returns: The rendered string for this item.
    func render(item: any ListItem, index: Int, isSelected: Bool, width: Int) -> String

    /// The height in lines of each rendered item.
    var height: Int { get }

    /// The number of blank lines between items.
    var spacing: Int { get }
}

// MARK: - Default Item Delegate

/// A simple default delegate that renders items as plain text.
public struct DefaultListItemDelegate: ListItemDelegate, Sendable {
    /// The style for the selected item indicator.
    public var selectedStyle: Style

    /// The style for normal items.
    public var normalStyle: Style

    /// Creates a default item delegate.
    public init() {
        self.selectedStyle = Style(isBold: true)
        self.normalStyle = Style()
    }

    public func render(item: any ListItem, index: Int, isSelected: Bool, width: Int) -> String {
        let prefix = isSelected ? "> " : "  "
        let text = item.filterValue()
        let line = prefix + text

        // Truncate if needed
        if line.count > width {
            let truncated = String(line.prefix(max(0, width - 1))) + "…"
            return isSelected ? selectedStyle.render(truncated) : normalStyle.render(truncated)
        }

        return isSelected ? selectedStyle.render(line) : normalStyle.render(line)
    }

    public var height: Int { 1 }
    public var spacing: Int { 0 }
}

// MARK: - Filter Match

/// A match result from filtering, pairing an item with its match score.
public struct ListFilterMatch: Sendable {
    /// The matched item.
    public let item: any ListItem
    /// The indexes of matched characters in the filter value.
    public let matchedIndexes: [Int]

    public init(item: any ListItem, matchedIndexes: [Int] = []) {
        self.item = item
        self.matchedIndexes = matchedIndexes
    }
}

// MARK: - Default Filter

/// The default fuzzy filter function.
///
/// Performs a simple substring/prefix match. For true fuzzy matching,
/// you can provide a custom filter function to the ``List``.
public func defaultListFilter(
    query: String,
    items: [any ListItem]
) -> sending [ListFilterMatch] {
    guard !query.isEmpty else {
        return items.map { ListFilterMatch(item: $0) }
    }

    let lowercaseQuery = query.lowercased()

    return items.compactMap { item in
        let value = item.filterValue().lowercased()

        // Try prefix match first
        if value.hasPrefix(lowercaseQuery) {
            let indexes = Array(0..<lowercaseQuery.count)
            return ListFilterMatch(item: item, matchedIndexes: indexes)
        }

        // Then try subsequence match
        if let indexes = fuzzyMatch(query: lowercaseQuery, in: value) {
            return ListFilterMatch(item: item, matchedIndexes: indexes)
        }

        return nil
    }
}

/// Simple fuzzy matching: checks if all characters of the query appear
/// in order within the target string.
private func fuzzyMatch(query: String, in target: String) -> [Int]? {
    var matchedIndexes: [Int] = []
    var queryIterator = query.makeIterator()
    var currentQueryChar = queryIterator.next()

    for (i, char) in target.enumerated() {
        guard let qChar = currentQueryChar else { break }
        if char == qChar {
            matchedIndexes.append(i)
            currentQueryChar = queryIterator.next()
        }
    }

    // All query characters were found
    return currentQueryChar == nil ? matchedIndexes : nil
}
