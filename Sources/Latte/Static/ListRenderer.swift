// MARK: - ListEnumerator

/// A strategy for generating the prefix string for each entry in a ``ListRenderer``.
///
/// Implement this protocol to create custom list styles. The built-in
/// implementations are ``BulletEnumerator``, ``ArabicEnumerator``,
/// ``AlphabetEnumerator``, and ``RomanEnumerator``.
///
/// ```swift
/// struct CheckboxEnumerator: ListEnumerator {
///     func prefix(for items: [ListEntry], at index: Int) -> String { "☐ " }
/// }
/// ```
public protocol ListEnumerator: Sendable {
    /// Returns the prefix string for the entry at the given index.
    ///
    /// - Parameters:
    ///   - items: The full array of entries in the list (useful for width padding).
    ///   - index: The zero-based index of the entry being rendered.
    /// - Returns: A string prepended to the entry's value, e.g. `"• "` or `"1. "`.
    func prefix(for items: [ListEntry], at index: Int) -> String
}

// MARK: - Built-in enumerators

/// A list enumerator that prefixes every entry with a bullet character (`• `).
///
/// Example output:
/// ```
/// • Apples
/// • Bananas
/// • Cherries
/// ```
public struct BulletEnumerator: ListEnumerator {
    public init() {}
    public func prefix(for items: [ListEntry], at index: Int) -> String { "• " }
}

/// A list enumerator that prefixes entries with Arabic numerals (`1. `, `2. `, …).
///
/// Example output:
/// ```
/// 1. Apples
/// 2. Bananas
/// 3. Cherries
/// ```
public struct ArabicEnumerator: ListEnumerator {
    public init() {}
    public func prefix(for items: [ListEntry], at index: Int) -> String {
        "\(index + 1). "
    }
}

/// A list enumerator that prefixes entries with lower-case letters (`a. `, `b. `, …).
///
/// After `z.`, the sequence wraps back to `a.`.
///
/// Example output:
/// ```
/// a. Apples
/// b. Bananas
/// c. Cherries
/// ```
public struct AlphabetEnumerator: ListEnumerator {
    public init() {}
    public func prefix(for items: [ListEntry], at index: Int) -> String {
        let base = Unicode.Scalar("a").value
        let scalar = Unicode.Scalar(base + UInt32(index % 26))!
        return "\(Character(scalar)). "
    }
}

/// A list enumerator that prefixes entries with lower-case Roman numerals
/// (`i. `, `ii. `, `iii. `, …).
///
/// Example output:
/// ```
/// i.   Apples
/// ii.  Bananas
/// iii. Cherries
/// ```
public struct RomanEnumerator: ListEnumerator {
    public init() {}
    public func prefix(for items: [ListEntry], at index: Int) -> String {
        "\(toRoman(index + 1)). "
    }

    private func toRoman(_ n: Int) -> String {
        let table: [(Int, String)] = [
            (1000, "m"), (900, "cm"), (500, "d"), (400, "cd"),
            (100, "c"),  (90, "xc"),  (50, "l"),  (40, "xl"),
            (10, "x"),   (9, "ix"),   (5, "v"),   (4, "iv"),
            (1, "i"),
        ]
        var result = ""
        var remaining = n
        for (value, numeral) in table {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }
}

// MARK: - ListEntry

/// A single entry in a ``ListRenderer``.
///
/// Entries hold a plain or styled string value and an optional child
/// ``ListRenderer`` for nested lists.
///
/// > Note: Named `ListEntry` rather than `ListItem` to avoid ambiguity with the
/// > `Spices.ListItem` protocol used by the interactive list component.
///
/// ```swift
/// let nested = ListRenderer(
///     items: [ListEntry("A1"), ListEntry("A2")],
///     enumerator: BulletEnumerator())
///
/// let entry = ListEntry("A", children: nested)
/// ```
public struct ListEntry: Sendable {
    /// The display value of this entry.
    public var value: String

    /// An optional child list to render indented beneath this entry.
    public var children: ListRenderer?

    /// Creates a list entry with an optional nested child renderer.
    ///
    /// - Parameters:
    ///   - value: The display text of this entry.
    ///   - children: An optional ``ListRenderer`` whose output is indented
    ///     two spaces beneath this entry's line. Defaults to `nil`.
    public init(_ value: String, children: ListRenderer? = nil) {
        self.value = value
        self.children = children
    }
}

// MARK: - ListRenderer

/// A static, non-interactive list renderer that formats a sequence of
/// ``ListEntry`` values into a styled, enumerated string.
///
/// `ListRenderer` is entirely output-focused — it produces a formatted
/// `String` and has no concept of selection or interaction. For interactive
/// list components, use `Spices.SelectableList` or `Spices.List`.
///
/// ```swift
/// let renderer = ListRenderer(
///     items: [ListEntry("Apples"), ListEntry("Bananas"), ListEntry("Cherries")],
///     enumerator: BulletEnumerator())
///
/// print(renderer.render())
/// // • Apples
/// // • Bananas
/// // • Cherries
/// ```
///
/// Entries support nesting via the ``ListEntry/children`` property:
///
/// ```swift
/// let produce = ListRenderer(
///     items: [ListEntry("Fruit"), ListEntry("Vegetables")],
///     enumerator: BulletEnumerator())
///
/// let shopping = ListRenderer(
///     items: [
///         ListEntry("Groceries", children: produce),
///         ListEntry("Household"),
///     ],
///     enumerator: ArabicEnumerator())
///
/// print(shopping.render())
/// // 1. Groceries
/// //   • Fruit
/// //   • Vegetables
/// // 2. Household
/// ```
public struct ListRenderer: Sendable {
    /// The items to render.
    public var items: [ListEntry]

    /// The enumerator that generates the prefix for each item.
    public var enumerator: any ListEnumerator

    /// An optional style applied to each item's value text.
    public var itemStyle: Style?

    /// An optional style applied to each item's prefix (the enumerator output).
    public var enumeratorStyle: Style?

    /// Creates a list renderer.
    ///
    /// - Parameters:
    ///   - items: The items to render.
    ///   - enumerator: The strategy for generating item prefixes.
    ///   - itemStyle: Optional style applied to each item's value.
    ///   - enumeratorStyle: Optional style applied to each item's prefix.
    public init(
        items: [ListEntry],
        enumerator: any ListEnumerator,
        itemStyle: Style? = nil,
        enumeratorStyle: Style? = nil
    ) {
        self.items = items
        self.enumerator = enumerator
        self.itemStyle = itemStyle
        self.enumeratorStyle = enumeratorStyle
    }

    // MARK: - Rendering

    /// Renders the list to a formatted, multi-line string.
    ///
    /// Colors in ``itemStyle`` and ``enumeratorStyle`` are downsampled to the
    /// given ``ColorProfile``, consistent with the pattern established in
    /// ``border(_:_:top:right:bottom:left:borderStyle:topStyle:bottomStyle:leftStyle:rightStyle:profile:)``.
    ///
    /// - Parameter profile: The terminal color profile to target.
    ///   Defaults to ``ColorProfile/trueColor``.
    /// - Returns: A string where each item occupies one or more lines, with
    ///   nested child lists indented by two spaces.
    public func render(profile: ColorProfile = .trueColor) -> String {
        renderLines(indent: "", profile: profile)
    }

    // MARK: - Internal

    /// Recursive rendering helper that prepends `indent` to every line.
    func renderLines(indent: String, profile: ColorProfile) -> String {
        var lines: [String] = []

        for (i, item) in items.enumerated() {
            let prefixStr = enumerator.prefix(for: items, at: i)
            let styledPrefix = enumeratorStyle?.render(prefixStr, profile: profile) ?? prefixStr
            let styledValue  = itemStyle?.render(item.value, profile: profile) ?? item.value
            lines.append(indent + styledPrefix + styledValue)

            if let childRenderer = item.children, !childRenderer.items.isEmpty {
                let childIndent = indent + "  "
                let childOutput = childRenderer.renderLines(indent: childIndent, profile: profile)
                if !childOutput.isEmpty {
                    lines.append(childOutput)
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
