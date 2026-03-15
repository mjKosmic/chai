import Chai

// MARK: - HelpKeyMap Protocol

/// A protocol for types that provide keybinding information for the help view.
///
/// Components expose a `KeyMap` struct and conform it to `HelpKeyMap`
/// to integrate with the ``Help`` component.
///
/// ```swift
/// struct MyKeyMap: HelpKeyMap {
///     var quit = KeyBinding(.rune("q"), .type(.ctrl("c")),
///                           help: KeyHelp("q/ctrl+c", "quit"))
///     var up = KeyBinding(.type(.up), .rune("k"),
///                         help: KeyHelp("↑/k", "up"))
///
///     func shortHelp() -> [KeyBinding] { [up, quit] }
///     func fullHelp() -> [[KeyBinding]] { [[up, quit]] }
/// }
/// ```
public protocol HelpKeyMap: Sendable {
    /// Returns bindings for the short (single-line) help view.
    func shortHelp() -> [KeyBinding]

    /// Returns groups of bindings for the full (multi-column) help view.
    ///
    /// Each inner array represents a column of related bindings.
    func fullHelp() -> [[KeyBinding]]
}

// MARK: - Help Styles

/// Styles for the help component's rendering.
public struct HelpStyles: Sendable {
    /// Style for the ellipsis shown when help is truncated.
    public var ellipsis: Style

    /// Style for key names in the short help view.
    public var shortKey: Style

    /// Style for descriptions in the short help view.
    public var shortDesc: Style

    /// Style for the separator between entries in the short help view.
    public var shortSeparator: Style

    /// Style for key names in the full help view.
    public var fullKey: Style

    /// Style for descriptions in the full help view.
    public var fullDesc: Style

    /// Style for the separator between entries in the full help view.
    public var fullSeparator: Style

    /// Creates help styles with sensible defaults.
    public init() {
        self.ellipsis = Style(isDim: true)
        self.shortKey = Style(isBold: true)
        self.shortDesc = Style(isDim: true)
        self.shortSeparator = Style(isDim: true)
        self.fullKey = Style(isBold: true)
        self.fullDesc = Style(isDim: true)
        self.fullSeparator = Style(isDim: true)
    }
}

// MARK: - Help

/// A help view that automatically generates keybinding documentation.
///
/// The help component renders keybinding information in two modes:
///
/// - **Short**: A single line showing the most important bindings.
/// - **Full**: A multi-column layout showing all bindings.
///
/// ```swift
/// var help = Help()
///
/// // In view():
/// help.view(keyMap: myKeyMap)
/// ```
public struct Help: Sendable {
    /// The maximum width of the help view.
    public var width: Int

    /// Whether to show the full (multi-column) help view.
    public var showAll: Bool

    /// The separator string between entries in the short view.
    public var shortSeparator: String

    /// The separator string between entries in the full view.
    public var fullSeparator: String

    /// The string shown when help text is truncated.
    public var ellipsis: String

    /// Styles for the help view.
    public var styles: HelpStyles

    // MARK: - Initializer

    /// Creates a new help component.
    ///
    /// - Parameter width: Maximum width. Defaults to 80.
    public init(width: Int = 80) {
        self.width = width
        self.showAll = false
        self.shortSeparator = " · "
        self.fullSeparator = "    "
        self.ellipsis = "…"
        self.styles = HelpStyles()
    }

    // MARK: - ELM interface

    /// No initial command needed.
    public func initialize() -> Command? { nil }

    /// Help has no key handling of its own.
    public mutating func update(_ msg: any Message) -> Command? { nil }

    /// Renders the help view for the given key map.
    ///
    /// - Parameter keyMap: A type providing keybinding information.
    /// - Returns: The rendered help string.
    public func view(keyMap: any HelpKeyMap) -> String {
        if showAll {
            return fullHelpView(keyMap: keyMap)
        } else {
            return shortHelpView(keyMap: keyMap)
        }
    }

    // MARK: - Short help

    /// Renders a single-line help view showing the most important bindings.
    public func shortHelpView(keyMap: any HelpKeyMap) -> String {
        let bindings = keyMap.shortHelp().filter { $0.isEnabled }
        guard !bindings.isEmpty else { return "" }

        let separator = styles.shortSeparator.render(shortSeparator)
        var result = ""
        var currentWidth = 0

        for (i, binding) in bindings.enumerated() {
            let entry = renderShortEntry(binding)
            let entryWidth = binding.help.key.count + 1 + binding.help.description.count

            // Check if adding this entry would exceed width
            let separatorWidth = i > 0 ? shortSeparator.count : 0
            let totalWidth = currentWidth + separatorWidth + entryWidth

            if totalWidth > width && i > 0 {
                // Truncate with ellipsis
                result += styles.shortSeparator.render(shortSeparator)
                result += styles.ellipsis.render(ellipsis)
                break
            }

            if i > 0 {
                result += separator
            }
            result += entry
            currentWidth = totalWidth
        }

        return result
    }

    /// Renders the full multi-column help view.
    public func fullHelpView(keyMap: any HelpKeyMap) -> String {
        let groups = keyMap.fullHelp()
        guard !groups.isEmpty else { return "" }

        var columns: [String] = []

        for group in groups {
            let enabledBindings = group.filter { $0.isEnabled }
            guard !enabledBindings.isEmpty else { continue }

            let column = enabledBindings.map { binding in
                renderFullEntry(binding)
            }.joined(separator: "\n")

            columns.append(column)
        }

        guard !columns.isEmpty else { return "" }

        // Join columns side by side
        return joinColumns(columns, separator: fullSeparator)
    }

    // MARK: - Private rendering

    private func renderShortEntry(_ binding: KeyBinding) -> String {
        let key = styles.shortKey.render(binding.help.key)
        let desc = styles.shortDesc.render(binding.help.description)
        return "\(key) \(desc)"
    }

    private func renderFullEntry(_ binding: KeyBinding) -> String {
        let key = styles.fullKey.render(binding.help.key)
        let desc = styles.fullDesc.render(binding.help.description)
        return "\(key) \(desc)"
    }

    /// Joins multiple columns of text side by side.
    private func joinColumns(_ columns: [String], separator: String) -> String {
        let splitColumns: [[String]] = columns.map {
            $0.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        }

        let maxRows = splitColumns.reduce(0) { max($0, $1.count) }
        guard maxRows > 0 else { return "" }

        // Calculate column widths (based on raw text, not ANSI)
        let columnWidths: [Int] = splitColumns.map { rows in
            rows.reduce(0) { max($0, stripANSI($1).count) }
        }

        var rows: [String] = []
        for row in 0..<maxRows {
            var parts: [String] = []
            for (colIdx, col) in splitColumns.enumerated() {
                let text = row < col.count ? col[row] : ""
                let rawWidth = stripANSI(text).count
                let padding = max(0, columnWidths[colIdx] - rawWidth)
                parts.append(text + String(repeating: " ", count: padding))
            }
            rows.append(parts.joined(separator: separator))
        }

        return rows.joined(separator: "\n")
    }

    /// Strips ANSI escape sequences from a string for width calculation.
    private func stripANSI(_ text: String) -> String {
        // Remove ESC[ ... m sequences
        var result = ""
        var inEscape = false
        for char in text {
            if char == "\u{1B}" {
                inEscape = true
                continue
            }
            if inEscape {
                if char == "m" {
                    inEscape = false
                }
                continue
            }
            result.append(char)
        }
        return result
    }
}
