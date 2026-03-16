import Chai

// MARK: - SelectableListStyles

/// Visual styles and rune configuration for the ``SelectableList`` component.
///
/// The cursor column displays a single Unicode character — the rune — to
/// communicate whether each item is selected. Override ``selectedRune`` and
/// ``unselectedRune`` to choose different characters; override the
/// corresponding `Style` properties to apply ANSI colour or text-attribute
/// styling to those characters and to item text.
///
/// ```swift
/// var styles = SelectableListStyles()
/// styles.selectedRune   = "✓"
/// styles.unselectedRune = "✗"
/// styles.selectedRuneStyle = Style().foreground(.ansi(.green))
/// ```
public struct SelectableListStyles: Sendable {
    /// Rune displayed next to an **unselected** item. Default: `○`.
    public var unselectedRune: Character

    /// Rune displayed next to a **selected** item. Default: `●`.
    public var selectedRune: Character

    /// Style applied to the rune when the item is **unselected**.
    public var unselectedRuneStyle: Style

    /// Style applied to the rune when the item is **selected**.
    public var selectedRuneStyle: Style

    /// Style applied to item text when the cursor is on that row but the
    /// item is **not** selected.
    public var focusedStyle: Style

    /// Style applied to item text when the cursor is on that row **and**
    /// the item is selected.
    public var focusedSelectedStyle: Style

    /// Style applied to item text for items that are selected but **not**
    /// under the cursor.
    public var selectedStyle: Style

    /// Style applied to item text that is neither selected nor focused.
    public var normalStyle: Style

    /// Creates styles with sensible defaults.
    ///
    /// | Property | Default |
    /// |---|---|
    /// | `unselectedRune` | `○` |
    /// | `selectedRune` | `●` |
    /// | `unselectedRuneStyle` | dim |
    /// | `selectedRuneStyle` | plain |
    /// | `focusedStyle` | bold |
    /// | `focusedSelectedStyle` | bold |
    /// | `selectedStyle` | plain |
    /// | `normalStyle` | dim |
    public init() {
        self.unselectedRune = "○"
        self.selectedRune = "●"
        self.unselectedRuneStyle = Style(isDim: true)
        self.selectedRuneStyle = Style()
        self.focusedStyle = Style(isBold: true)
        self.focusedSelectedStyle = Style(isBold: true)
        self.selectedStyle = Style()
        self.normalStyle = Style(isDim: true)
    }
}

// MARK: - SelectableListKeyMap

/// Keybindings for the ``SelectableList`` component.
///
/// Replace any field with a custom ``KeyBinding`` to remap that action:
///
/// ```swift
/// var keyMap = SelectableListKeyMap()
/// keyMap.toggle = KeyBinding(.type(.enter), help: KeyHelp("enter", "toggle"))
/// ```
public struct SelectableListKeyMap: Sendable, HelpKeyMap {
    /// Move the cursor up one row.
    public var cursorUp: KeyBinding

    /// Move the cursor down one row.
    public var cursorDown: KeyBinding

    /// Toggle the selection state of the item under the cursor.
    public var toggle: KeyBinding

    /// Select every item in the list.
    public var selectAll: KeyBinding

    /// Deselect every item in the list.
    public var deselectAll: KeyBinding

    /// Quit the program.
    public var quit: KeyBinding

    /// Force-quit the program (always active).
    public var forceQuit: KeyBinding

    /// Creates a key map with default bindings.
    public init() {
        cursorUp = KeyBinding(
            .type(.up), .rune("k"),
            help: KeyHelp("↑/k", "up")
        )
        cursorDown = KeyBinding(
            .type(.down), .rune("j"),
            help: KeyHelp("↓/j", "down")
        )
        toggle = KeyBinding(
            .type(.space),
            help: KeyHelp("space", "toggle")
        )
        selectAll = KeyBinding(
            .type(.ctrl("a")),
            help: KeyHelp("ctrl+a", "select all")
        )
        deselectAll = KeyBinding(
            .type(.escape),
            help: KeyHelp("esc", "deselect all")
        )
        quit = KeyBinding(
            .rune("q"),
            help: KeyHelp("q", "quit")
        )
        forceQuit = KeyBinding(
            .type(.ctrl("c")),
            help: KeyHelp("ctrl+c", "force quit")
        )
    }

    public func shortHelp() -> [KeyBinding] {
        [cursorUp, cursorDown, toggle, quit]
    }

    public func fullHelp() -> [[KeyBinding]] {
        [
            [cursorUp, cursorDown],
            [toggle, selectAll, deselectAll],
            [quit, forceQuit],
        ]
    }
}

// MARK: - SelectableList

/// A multi-select list component.
///
/// Items can be individually toggled on or off with the space bar.
/// Navigation uses the arrow keys or vi-style `j`/`k` bindings.
///
/// The cursor column shows configurable runes to communicate selection
/// state — a hollow circle `○` for unselected items and a filled circle
/// `●` for selected items by default. Both runes and their styles are
/// configurable through ``styles``.
///
/// The list scrolls automatically to keep the cursor visible when there
/// are more items than the configured height.
///
/// ```swift
/// struct Fruit: ListItem {
///     let name: String
///     func filterValue() -> String { name }
/// }
///
/// let fruits: [any ListItem] = [
///     Fruit(name: "Apple"),
///     Fruit(name: "Banana"),
///     Fruit(name: "Cherry"),
/// ]
///
/// var picker = SelectableList(items: fruits, height: 10)
///
/// // In view():
/// picker.view()
///
/// // After the user confirms, retrieve selected items:
/// let chosen = picker.selectedItems
/// ```
public struct SelectableList: Sendable {
    // MARK: - Public configuration

    /// Visual styles and rune characters.
    public var styles: SelectableListStyles

    /// Keybindings.
    public var keyMap: SelectableListKeyMap

    /// Whether the cursor wraps from the last item to the first and vice versa.
    public var infiniteScrolling: Bool

    // MARK: - Private state

    private var _items: [any ListItem]
    private var _selectedIndices: Set<Int>
    private var _cursor: Int
    private var _offset: Int
    private var _width: Int
    private var _height: Int

    // MARK: - Initializer

    /// Creates a new selectable list.
    ///
    /// - Parameters:
    ///   - items: The items to display. Defaults to an empty array.
    ///   - width: Display width in terminal columns. Defaults to `40`.
    ///   - height: Maximum number of visible rows. Defaults to `10`.
    public init(
        items: [any ListItem] = [],
        width: Int = 40,
        height: Int = 10
    ) {
        self.styles = SelectableListStyles()
        self.keyMap = SelectableListKeyMap()
        self.infiniteScrolling = false
        self._items = items
        self._selectedIndices = []
        self._cursor = 0
        self._offset = 0
        self._width = max(1, width)
        self._height = max(1, height)
    }

    // MARK: - ELM interface

    /// No initial command is needed.
    public func initialize() -> Command? { nil }

    /// Handles keyboard input and window-resize messages.
    ///
    /// Responds to navigation, toggle, select-all, deselect-all, and quit
    /// bindings from ``keyMap``. ``keyMap/forceQuit`` always takes effect
    /// regardless of the ``KeyBinding/isEnabled`` state of other bindings.
    ///
    /// - Parameter msg: A message from the Chai event loop.
    /// - Returns: `.quit` when the user activates a quit binding, `nil` otherwise.
    public mutating func update(_ msg: any Message) -> Command? {
        if let size = msg as? WindowSizeMsg {
            setSize(width: size.width, height: size.height)
            return nil
        }

        guard let key = msg as? KeyMsg else { return nil }

        if keyMap.forceQuit.matches(key) {
            return .quit
        } else if keyMap.cursorUp.matches(key) {
            moveCursorUp()
        } else if keyMap.cursorDown.matches(key) {
            moveCursorDown()
        } else if keyMap.toggle.matches(key) {
            toggleSelection(at: _cursor)
        } else if keyMap.selectAll.matches(key) {
            selectAll()
        } else if keyMap.deselectAll.matches(key) {
            deselectAll()
        } else if keyMap.quit.matches(key) {
            return .quit
        }

        return nil
    }

    /// Renders the visible slice of the list.
    ///
    /// Each row is formatted as:
    /// ```
    /// <rune> <item text>
    /// ```
    ///
    /// The rune reflects the item's selection state; text styling reflects
    /// whether the row is focused (cursor) and/or selected.
    ///
    /// - Returns: A ``Chai/ViewOutput`` whose content is the rendered list.
    public func view() -> ViewOutput {
        guard !_items.isEmpty else {
            return ViewOutput(styles.normalStyle.render("No items."))
        }

        let end = min(_offset + _height, _items.count)
        var lines: [String] = []

        for i in _offset..<end {
            let isSelected = _selectedIndices.contains(i)
            let isFocused = i == _cursor

            // ── Rune column ──────────────────────────────────────────────
            let rune = isSelected ? styles.selectedRune : styles.unselectedRune
            let styledRune = isSelected
                ? styles.selectedRuneStyle.render(String(rune))
                : styles.unselectedRuneStyle.render(String(rune))

            // ── Item text ────────────────────────────────────────────────
            // Available columns: total width minus rune (1) and separator space (1).
            let availableWidth = max(0, _width - 2)
            let rawText = _items[i].filterValue()
            let text: String
            if availableWidth <= 0 {
                // No room for text; render only the rune (and separator space).
                text = ""
            } else if rawText.count > availableWidth {
                text = String(rawText.prefix(max(0, availableWidth - 1))) + "…"
            } else {
                text = rawText
            }

            let styledText: String
            if isFocused {
                styledText = isSelected
                    ? styles.focusedSelectedStyle.render(text)
                    : styles.focusedStyle.render(text)
            } else {
                styledText = isSelected
                    ? styles.selectedStyle.render(text)
                    : styles.normalStyle.render(text)
            }

            lines.append(styledRune + " " + styledText)
        }

        return ViewOutput(lines.joined(separator: "\n"))
    }

    // MARK: - Public API

    /// All items in the list.
    public var items: [any ListItem] { _items }

    /// The set of indices that are currently selected.
    public var selectedIndices: Set<Int> { _selectedIndices }

    /// All currently selected items, in index order.
    public var selectedItems: [any ListItem] {
        _selectedIndices.sorted().compactMap { idx in
            guard idx < _items.count else { return nil }
            return _items[idx]
        }
    }

    /// The index of the item currently under the cursor.
    public var cursorIndex: Int { _cursor }

    /// The item currently under the cursor, or `nil` if the list is empty.
    public var cursorItem: (any ListItem)? {
        guard !_items.isEmpty, _cursor < _items.count else { return nil }
        return _items[_cursor]
    }

    /// Replaces all items and resets selection and cursor to zero.
    ///
    /// - Parameter items: The replacement items.
    public mutating func setItems(_ items: [any ListItem]) {
        _items = items
        _selectedIndices = []
        _cursor = 0
        _offset = 0
    }

    /// Updates the display dimensions.
    ///
    /// - Parameters:
    ///   - width: New width in terminal columns.
    ///   - height: New maximum visible row count.
    public mutating func setSize(width: Int, height: Int) {
        _width = max(1, width)
        _height = max(1, height)
        scrollToCursor()
    }

    /// Toggles the selection state of the item at `index`.
    ///
    /// If the index is out of range the call is a no-op.
    ///
    /// - Parameter index: Zero-based item index.
    public mutating func toggleSelection(at index: Int) {
        guard index >= 0, index < _items.count else { return }
        if _selectedIndices.contains(index) {
            _selectedIndices.remove(index)
        } else {
            _selectedIndices.insert(index)
        }
    }

    /// Selects every item in the list.
    public mutating func selectAll() {
        _selectedIndices = Set(0..<_items.count)
    }

    /// Deselects every item in the list.
    public mutating func deselectAll() {
        _selectedIndices = []
    }

    /// Moves the cursor to the given index, scrolling the viewport if needed.
    ///
    /// The index is clamped to `0...(items.count - 1)`.
    ///
    /// - Parameter index: Zero-based item index.
    public mutating func setCursor(_ index: Int) {
        guard !_items.isEmpty else { return }
        _cursor = max(0, min(index, _items.count - 1))
        scrollToCursor()
    }

    // MARK: - Private: Navigation

    private mutating func moveCursorUp() {
        guard !_items.isEmpty else { return }
        if _cursor > 0 {
            _cursor -= 1
        } else if infiniteScrolling {
            _cursor = _items.count - 1
        }
        scrollToCursor()
    }

    private mutating func moveCursorDown() {
        guard !_items.isEmpty else { return }
        if _cursor < _items.count - 1 {
            _cursor += 1
        } else if infiniteScrolling {
            _cursor = 0
        }
        scrollToCursor()
    }

    // MARK: - Private: Scrolling

    /// Adjusts `_offset` so `_cursor` is always within the visible window.
    private mutating func scrollToCursor() {
        if _cursor < _offset {
            _offset = _cursor
        } else if _cursor >= _offset + _height {
            _offset = _cursor - _height + 1
        }
        // Clamp offset so we never show a blank tail.
        let maxOffset = max(0, _items.count - _height)
        _offset = max(0, min(_offset, maxOffset))
    }
}
