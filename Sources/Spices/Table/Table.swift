import Chai
import Latte
// MARK: - Table types

/// A column definition for a table.
public struct TableColumn: Sendable {
    /// The column header text.
    public var title: String
    /// The column width in characters.
    public var width: Int

    /// Creates a table column.
    public init(title: String, width: Int) {
        self.title = title
        self.width = width
    }
}

/// A row of string values in a table.
public typealias TableRow = [String]

// MARK: - Table Styles

/// Styles for the table component.
public struct TableStyles: Sendable {
    /// Style for the header row.
    public var header: Style
    /// Style for regular (unselected) cells.
    public var cell: Style
    /// Style for the selected row.
    public var selected: Style

    /// Creates table styles with sensible defaults.
    public init() {
        self.header = Style(isBold: true)
        self.cell = Style()
        self.selected = Style().reverse()
    }
}

// MARK: - Table KeyMap

/// Keybindings for table navigation.
public struct TableKeyMap: Sendable, HelpKeyMap {
    public var lineUp: KeyBinding
    public var lineDown: KeyBinding
    public var pageUp: KeyBinding
    public var pageDown: KeyBinding
    public var halfPageUp: KeyBinding
    public var halfPageDown: KeyBinding
    public var gotoTop: KeyBinding
    public var gotoBottom: KeyBinding

    /// Creates a table key map with default bindings.
    public init() {
        lineUp = KeyBinding(.type(.up), .rune("k"),
                            help: KeyHelp("↑/k", "up"))
        lineDown = KeyBinding(.type(.down), .rune("j"),
                              help: KeyHelp("↓/j", "down"))
        pageUp = KeyBinding(.type(.pageUp), .rune("b"),
                            help: KeyHelp("b/pgup", "page up"))
        pageDown = KeyBinding(.type(.pageDown), .rune("f"), .type(.space),
                              help: KeyHelp("f/pgdn", "page down"))
        halfPageUp = KeyBinding(.rune("u"),
                                help: KeyHelp("u", "½ page up"))
        halfPageDown = KeyBinding(.rune("d"),
                                  help: KeyHelp("d", "½ page down"))
        gotoTop = KeyBinding(.type(.home), .rune("g"),
                             help: KeyHelp("g/home", "go to top"))
        gotoBottom = KeyBinding(.type(.end), .rune("G"),
                                help: KeyHelp("G/end", "go to bottom"))
    }

    public func shortHelp() -> [KeyBinding] {
        [lineUp, lineDown, pageUp, pageDown]
    }

    public func fullHelp() -> [[KeyBinding]] {
        [[lineUp, lineDown, pageUp, pageDown, halfPageUp, halfPageDown, gotoTop, gotoBottom]]
    }
}

// MARK: - Table

/// An interactive data table with selectable rows and scrolling.
///
/// The table displays columns with headers and rows of data. It
/// supports keyboard navigation, row selection, and scrolling for
/// content that exceeds the visible area.
///
/// ```swift
/// let columns = [
///     TableColumn(title: "Name", width: 20),
///     TableColumn(title: "Age", width: 5),
/// ]
/// let rows: [TableRow] = [
///     ["Alice", "30"],
///     ["Bob", "25"],
/// ]
/// var table = Table(columns: columns, rows: rows, height: 10)
///
/// // In update():
/// table.update(msg)
///
/// // Get selected row:
/// if let row = table.selectedRow { ... }
///
/// // In body:
/// table.body
/// ```
public struct Table: View {
    /// Keybindings for navigation.
    public var keyMap: TableKeyMap

    /// Help component for rendering keybinding help.
    public var help: Help

    /// Styles for the table.
    public var styles: TableStyles

    // MARK: Private state

    private var _columns: [TableColumn]
    private var _rows: [TableRow]
    private var _cursor: Int
    private var _focused: Bool
    private var _height: Int  // visible rows (excluding header)
    private var _viewportStart: Int

    // MARK: - Initializer

    /// Creates a new table.
    ///
    /// - Parameters:
    ///   - columns: Column definitions.
    ///   - rows: Row data.
    ///   - height: Visible row count (excluding header). Defaults to 10.
    public init(
        columns: [TableColumn] = [],
        rows: [TableRow] = [],
        height: Int = 10
    ) {
        self.keyMap = TableKeyMap()
        self.help = Help()
        self.styles = TableStyles()
        self._columns = columns
        self._rows = rows
        self._cursor = 0
        self._focused = false
        self._height = max(1, height)
        self._viewportStart = 0
    }

    // MARK: - ELM interface

    /// No initial command needed.
    public func initialize() -> Command? { nil }

    /// Handles key events for navigation.
    public mutating func update(_ msg: any Message) -> Command? {
        guard _focused else { return nil }
        guard let key = msg as? KeyMsg else { return nil }

        if keyMap.lineUp.matches(key) {
            moveUp(1)
        } else if keyMap.lineDown.matches(key) {
            moveDown(1)
        } else if keyMap.pageUp.matches(key) {
            moveUp(_height)
        } else if keyMap.pageDown.matches(key) {
            moveDown(_height)
        } else if keyMap.halfPageUp.matches(key) {
            moveUp(_height / 2)
        } else if keyMap.halfPageDown.matches(key) {
            moveDown(_height / 2)
        } else if keyMap.gotoTop.matches(key) {
            gotoTop()
        } else if keyMap.gotoBottom.matches(key) {
            gotoBottom()
        }

        return nil
    }

    /// Renders the table.
    public var body: ViewOutput {
        guard !_columns.isEmpty else { return "" }
        return ViewOutput(headerView() + StyledText("\n") + bodyView())
    }

    // MARK: - Public API

    /// Sets the columns.
    public mutating func setColumns(_ columns: [TableColumn]) {
        _columns = columns
    }

    /// Sets the rows.
    public mutating func setRows(_ rows: [TableRow]) {
        _rows = rows
        clampCursor()
    }

    /// The columns.
    public var columns: [TableColumn] { _columns }

    /// The rows.
    public var rows: [TableRow] { _rows }

    /// The currently selected row, or `nil` if the table is empty.
    public var selectedRow: TableRow? {
        guard !_rows.isEmpty else { return nil }
        return _rows[_cursor]
    }

    /// The index of the selected row.
    public var cursor: Int { _cursor }

    /// Sets the cursor position.
    public mutating func setCursor(_ index: Int) {
        _cursor = max(0, min(index, _rows.count - 1))
        updateViewportStart()
    }

    /// Whether the table is focused.
    public var isFocused: Bool { _focused }

    /// Focuses the table for keyboard input.
    public mutating func focus() {
        _focused = true
    }

    /// Blurs the table.
    public mutating func blur() {
        _focused = false
    }

    /// Sets the visible height (excluding header).
    public mutating func setHeight(_ height: Int) {
        _height = max(1, height)
        updateViewportStart()
    }

    /// Sets the total width, distributing among columns proportionally.
    public mutating func setWidth(_ width: Int) {
        guard !_columns.isEmpty else { return }
        let totalCurrentWidth = _columns.reduce(0) { $0 + $1.width }
        guard totalCurrentWidth > 0 else { return }
        let ratio = Double(width) / Double(totalCurrentWidth)
        for i in 0..<_columns.count {
            _columns[i].width = max(1, Int(Double(_columns[i].width) * ratio))
        }
    }

    /// Renders the help view for this table's keybindings as structured styled text.
    public func helpView() -> StyledText {
        help.view(keyMap: keyMap)
    }

    /// Creates a table from a string of values separated by a delimiter.
    ///
    /// The first row is used as column headers.
    public static func fromValues(
        _ values: String,
        separator: Character = ","
    ) -> Table {
        let lines = values.split(separator: "\n", omittingEmptySubsequences: true)
        guard !lines.isEmpty else { return Table() }

        let header = lines[0].split(separator: separator).map(String.init)
        let columns = header.map { TableColumn(title: $0.trimmingCharacters(in: .whitespaces), width: 15) }

        let rows: [TableRow] = lines.dropFirst().map { line in
            line.split(separator: separator).map {
                $0.trimmingCharacters(in: .whitespaces)
            }
        }

        return Table(columns: columns, rows: rows)
    }

    // MARK: - Navigation

    /// Moves the cursor up by the given number of rows.
    public mutating func moveUp(_ n: Int) {
        _cursor = max(0, _cursor - n)
        updateViewportStart()
    }

    /// Moves the cursor down by the given number of rows.
    public mutating func moveDown(_ n: Int) {
        guard !_rows.isEmpty else { return }
        _cursor = min(_rows.count - 1, _cursor + n)
        updateViewportStart()
    }

    /// Moves the cursor to the first row.
    public mutating func gotoTop() {
        _cursor = 0
        _viewportStart = 0
    }

    /// Moves the cursor to the last row.
    public mutating func gotoBottom() {
        _cursor = max(0, _rows.count - 1)
        updateViewportStart()
    }

    // MARK: - Private rendering

    private func headerView() -> StyledText {
        let cells = _columns.map { col in
            padOrTruncate(col.title, to: col.width)
        }
        return styles.header.styledText(cells.joined(separator: " "))
    }

    private func bodyView() -> StyledText {
        guard !_rows.isEmpty else { return StyledText() }

        let endIndex = min(_viewportStart + _height, _rows.count)
        var lines: [StyledText] = []

        for i in _viewportStart..<endIndex {
            let row = _rows[i]
            let cells = _columns.enumerated().map { (colIdx, col) in
                let value = colIdx < row.count ? row[colIdx] : ""
                return padOrTruncate(value, to: col.width)
            }
            let line = cells.joined(separator: " ")

            if i == _cursor && _focused {
                lines.append(styles.selected.styledText(line))
            } else {
                lines.append(styles.cell.styledText(line))
            }
        }

        return lines.joined()
    }

    private mutating func updateViewportStart() {
        if _cursor < _viewportStart {
            _viewportStart = _cursor
        } else if _cursor >= _viewportStart + _height {
            _viewportStart = _cursor - _height + 1
        }
    }

    private mutating func clampCursor() {
        if _rows.isEmpty {
            _cursor = 0
        } else {
            _cursor = min(_cursor, _rows.count - 1)
        }
        updateViewportStart()
    }

    /// Pads or truncates a string to the given width.
    ///
    /// `width` is clamped to at least 1 to guard against non-positive
    /// column widths that could cause a trap or nonsensical output.
    private func padOrTruncate(_ text: String, to width: Int) -> String {
        let w = max(1, width)
        let chars = Array(text)
        if chars.count >= w {
            if w > 1 {
                return String(chars.prefix(w - 1)) + "…"
            }
            return String(chars.prefix(w))
        }
        return text + String(repeating: " ", count: w - chars.count)
    }
}
