// MARK: - TreeNode

/// A node in a hierarchical tree rendered by ``TreeRenderer``.
///
/// A node holds a display string and an array of child nodes. The tree can
/// be arbitrarily deep.
///
/// ```swift
/// let root = TreeNode(".",
///     children: [
///         TreeNode("A", children: [TreeNode("A1")]),
///         TreeNode("B"),
///         TreeNode("C", children: [TreeNode("C1"), TreeNode("C2")]),
///     ])
/// ```
public struct TreeNode: Sendable {
    /// The display value of this node.
    public var value: String

    /// The child nodes, rendered indented beneath this node.
    public var children: [TreeNode]

    /// Creates a tree node.
    ///
    /// - Parameters:
    ///   - value: The display string for this node. ANSI escape codes are
    ///     allowed — they do not affect connector alignment.
    ///   - children: The child nodes. Defaults to an empty array (leaf node).
    public init(_ value: String, children: [TreeNode] = []) {
        self.value = value
        self.children = children
    }
}

// MARK: - TreeEnumerator

/// The connector characters used to draw tree branches.
///
/// Two built-in styles are provided:
/// - ``default``: uses `└──` for last children (straight-line corners).
/// - ``rounded``: uses `╰──` for last children (rounded corners).
///
/// A ``custom(intermediate:last:indent:)`` case allows fully custom branch
/// characters. The `indent` value is used as the continuation prefix under
/// non-last nodes; the same visual width in spaces is used under last nodes.
///
/// ```swift
/// // ASCII tree
/// let ascii = TreeEnumerator.custom(
///     intermediate: "+-- ",
///     last:         "`-- ",
///     indent:       "|   ")
/// ```
public enum TreeEnumerator: Sendable {
    /// Standard box-drawing connectors.
    ///
    /// Non-last children: `├── `
    /// Last children:     `└── `
    /// Continuation:      `│   `
    case `default`

    /// Rounded box-drawing connectors.
    ///
    /// Non-last children: `├── `
    /// Last children:     `╰── `
    /// Continuation:      `│   `
    case rounded

    /// Fully custom connector strings.
    ///
    /// - Parameters:
    ///   - intermediate: Connector for non-last children (e.g. `"├── "`).
    ///   - last:         Connector for the last child (e.g. `"└── "`).
    ///   - indent:       Continuation prefix under non-last nodes (e.g. `"│   "`).
    ///     The same visual width in spaces is used under last nodes.
    case custom(intermediate: String, last: String, indent: String)

    // MARK: - Accessor helpers

    /// Connector prepended to a non-last child node.
    var intermediateConnector: String {
        switch self {
        case .default, .rounded:                     return "├── "
        case .custom(let s, _, _):                   return s
        }
    }

    /// Connector prepended to the last child node.
    var lastConnector: String {
        switch self {
        case .default:                               return "└── "
        case .rounded:                               return "╰── "
        case .custom(_, let s, _):                   return s
        }
    }

    /// Continuation prefix added when traversing deeper under a non-last node.
    var continuationIndent: String {
        switch self {
        case .default, .rounded:                     return "│   "
        case .custom(_, _, let s):                   return s
        }
    }

    /// Blank prefix (spaces) of the same visible width as ``continuationIndent``,
    /// used when traversing deeper under a last node.
    var emptyIndent: String {
        switch self {
        case .default, .rounded: return "    "
        case .custom(_, _, let s):
            return String(repeating: " ", count: visibleWidth(of: s))
        }
    }
}

// MARK: - TreeRenderer

/// A static tree renderer that formats a hierarchical ``TreeNode`` structure
/// into a string using box-drawing connector characters.
///
/// `TreeRenderer` is output-focused: it produces a formatted `String` with no
/// interactive behaviour.
///
/// ```swift
/// let root = TreeNode(".",
///     children: [
///         TreeNode("A", children: [TreeNode("A1")]),
///         TreeNode("B"),
///         TreeNode("C", children: [TreeNode("C1"), TreeNode("C2")]),
///     ])
///
/// let renderer = TreeRenderer(root: root)
/// print(renderer.render())
/// ```
///
/// Default output:
/// ```
/// .
/// ├── A
/// │   └── A1
/// ├── B
/// └── C
///     ├── C1
///     └── C2
/// ```
public struct TreeRenderer: Sendable {
    /// The root node of the tree.
    public var root: TreeNode

    /// The connector style for tree branches.
    public var enumerator: TreeEnumerator

    /// Creates a tree renderer.
    ///
    /// - Parameters:
    ///   - root: The root node whose value is printed first and whose children
    ///     are rendered recursively beneath it.
    ///   - enumerator: The connector style. Defaults to ``TreeEnumerator/default``.
    public init(root: TreeNode, enumerator: TreeEnumerator = .default) {
        self.root = root
        self.enumerator = enumerator
    }

    // MARK: - Rendering

    /// Renders the tree to a formatted, multi-line string.
    ///
    /// ANSI escape codes in node values are preserved and do not affect
    /// connector alignment — connectors and indents are plain strings.
    ///
    /// - Returns: The rendered tree string, with the root value on the first
    ///   line and children on subsequent indented lines.
    public func render() -> String {
        var lines: [String] = [root.value]
        renderChildren(root.children, prefix: "", lines: &lines)
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func renderChildren(
        _ children: [TreeNode],
        prefix: String,
        lines: inout [String]
    ) {
        for (i, child) in children.enumerated() {
            let isLast = i == children.count - 1
            let connector = isLast ? enumerator.lastConnector : enumerator.intermediateConnector
            lines.append(prefix + connector + child.value)

            let childPrefix = prefix + (isLast ? enumerator.emptyIndent : enumerator.continuationIndent)
            renderChildren(child.children, prefix: childPrefix, lines: &lines)
        }
    }
}
