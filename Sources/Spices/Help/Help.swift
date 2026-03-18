import Chai
import Latte
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
    /// - Returns: The rendered help as structured ``StyledText``.
    public func view(keyMap: any HelpKeyMap) -> StyledText {
        if showAll {
            return fullHelpView(keyMap: keyMap)
        } else {
            return shortHelpView(keyMap: keyMap)
        }
    }

    // MARK: - Short help

    /// Renders a single-line help view showing the most important bindings.
    public func shortHelpView(keyMap: any HelpKeyMap) -> StyledText {
        let bindings = keyMap.shortHelp().filter { $0.isEnabled }
        guard !bindings.isEmpty else { return StyledText() }

        let separatorText = styles.shortSeparator.styledText(shortSeparator)
        var result = StyledText()
        var currentWidth = 0

        for (i, binding) in bindings.enumerated() {
            let entry = renderShortEntry(binding)
            let entryWidth = binding.help.key.count + 1 + binding.help.description.count

            // Check if adding this entry would exceed width
            let separatorWidth = i > 0 ? shortSeparator.count : 0
            let totalWidth = currentWidth + separatorWidth + entryWidth

            if totalWidth > width && i > 0 {
                // Truncate with ellipsis
                result += separatorText
                result += styles.ellipsis.styledText(ellipsis)
                break
            }

            if i > 0 {
                result += separatorText
            }
            result += entry
            currentWidth = totalWidth
        }

        return result
    }

    /// Renders the full multi-column help view.
    public func fullHelpView(keyMap: any HelpKeyMap) -> StyledText {
        let groups = keyMap.fullHelp()
        guard !groups.isEmpty else { return StyledText() }

        // Build one column (array of StyledText rows) per group.
        var styledColumns: [[StyledText]] = []
        for group in groups {
            let enabled = group.filter { $0.isEnabled }
            guard !enabled.isEmpty else { continue }
            styledColumns.append(enabled.map { renderFullEntry($0) })
        }

        guard !styledColumns.isEmpty else { return StyledText() }
        return joinStyledColumns(styledColumns, separator: fullSeparator)
    }

    // MARK: - Private rendering

    private func renderShortEntry(_ binding: KeyBinding) -> StyledText {
        styles.shortKey.styledText(binding.help.key)
            + StyledText(" ")
            + styles.shortDesc.styledText(binding.help.description)
    }

    private func renderFullEntry(_ binding: KeyBinding) -> StyledText {
        styles.fullKey.styledText(binding.help.key)
            + StyledText(" ")
            + styles.fullDesc.styledText(binding.help.description)
    }

    /// Joins columns of ``StyledText`` rows side-by-side, padding each column
    /// to a uniform width using the terminal display-column width of each entry.
    ///
    /// Uses ``StyledText/columnWidth`` rather than `plainText.count` so that
    /// wide characters (CJK, emoji) are measured correctly and columns align.
    private func joinStyledColumns(_ columns: [[StyledText]], separator: String) -> StyledText {
        let maxRows = columns.reduce(0) { max($0, $1.count) }
        guard maxRows > 0 else { return StyledText() }

        // Compute each column's display width using terminal column widths.
        let columnWidths: [Int] = columns.map { rows in
            rows.reduce(0) { max($0, $1.columnWidth) }
        }

        var resultRows: [StyledText] = []
        for row in 0..<maxRows {
            var rowText = StyledText()
            for (colIdx, col) in columns.enumerated() {
                let entry   = row < col.count ? col[row] : StyledText()
                let padding = max(0, columnWidths[colIdx] - entry.columnWidth)

                if colIdx > 0 {
                    rowText += StyledText(separator)
                }
                rowText += entry
                if padding > 0 {
                    rowText += StyledText(String(repeating: " ", count: padding))
                }
            }
            resultRows.append(rowText)
        }

        return resultRows.joined()
    }
}
