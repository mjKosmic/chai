import Chai
import Latte

// MARK: - Menu ID Generator

private let _menuIDGenerator = IDGenerator()

// MARK: - Menu Messages

/// Posted when the user confirms a selection (Enter).
///
/// ```swift
/// if let msg = msg as? MenuSelectionMsg, msg.menuID == myMenu.id {
///     currentView = .detail(msg.item)
/// }
/// ```
public struct MenuSelectionMsg: Message, Sendable {
    public let menuID: Int
    public let item: any ListItem

    public init(menuID: Int, item: any ListItem) {
        self.menuID = menuID
        self.item = item
    }
}

/// Posted when the user cancels the menu (Escape or q).
///
/// ```swift
/// if let msg = msg as? MenuCancellationMsg, msg.menuID == myMenu.id {
///     currentView = .main
/// }
/// ```
public struct MenuCancellationMsg: Message, Sendable {
    public let menuID: Int
    public init(menuID: Int) { self.menuID = menuID }
}

// MARK: - MenuStyles

/// Visual styles and rune configuration for the ``Menu`` component.
///
/// The cursor column displays a single Unicode character — the rune — to
/// communicate which item is focused. Override ``cursorRune`` and the
/// corresponding `Style` properties to customise the appearance.
///
/// ```swift
/// var styles = MenuStyles()
/// styles.cursorRune = "▶"
/// styles.focusedStyle = Style().foreground(.ansi(.cyan))
/// ```
public struct MenuStyles: Sendable {
    /// Rune displayed next to the **focused** item. Default: `>`.
    public var cursorRune: Character

    /// Style applied to the cursor rune. Default: plain.
    public var cursorRuneStyle: Style

    /// Style applied to item text for the item under the cursor. Default: bold.
    public var focusedStyle: Style

    /// Style applied to item text for items that are **not** under the cursor. Default: dim.
    public var normalStyle: Style

    /// Creates styles with sensible defaults.
    ///
    /// | Property | Default |
    /// |---|---|
    /// | `cursorRune` | `>` |
    /// | `cursorRuneStyle` | plain |
    /// | `focusedStyle` | bold |
    /// | `normalStyle` | dim |
    public init() {
        self.cursorRune = ">"
        self.cursorRuneStyle = Style()
        self.focusedStyle = Style(isBold: true)
        self.normalStyle = Style(isDim: true)
    }
}

// MARK: - MenuKeyMap

/// Keybindings for the ``Menu`` component.
///
/// Replace any field with a custom ``KeyBinding`` to remap that action:
///
/// ```swift
/// var keyMap = MenuKeyMap()
/// keyMap.confirm = KeyBinding(.type(.space), help: KeyHelp("space", "select"))
/// ```
public struct MenuKeyMap: Sendable, HelpKeyMap {
    /// Move the cursor up one row.
    public var cursorUp: KeyBinding

    /// Move the cursor down one row.
    public var cursorDown: KeyBinding

    /// Confirm the selection under the cursor.
    public var confirm: KeyBinding

    /// Cancel without selecting.
    public var cancel: KeyBinding

    /// Quit the program without selecting.
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
        confirm = KeyBinding(
            .type(.enter),
            help: KeyHelp("enter", "confirm")
        )
        cancel = KeyBinding(
            .type(.escape),
            help: KeyHelp("esc", "cancel")
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
        [cursorUp, cursorDown, confirm, quit]
    }

    public func fullHelp() -> [[KeyBinding]] {
        [
            [cursorUp, cursorDown],
            [confirm, cancel, quit, forceQuit],
        ]
    }
}

// MARK: - Menu

/// A single-selection menu component.
///
/// The user navigates the list with the arrow keys or vi-style `j`/`k`
/// bindings, confirms a choice with Enter, or cancels with Escape.
/// After the program exits, inspect ``isConfirmed`` and ``selectedItem``
/// to distinguish a confirmed pick from a dismissal.
///
/// The list scrolls automatically to keep the cursor visible when there
/// are more items than the configured height.
///
/// ```swift
/// struct Option: ListItem {
///     let name: String
///     func filterValue() -> String { name }
/// }
///
/// let options: [any ListItem] = [
///     Option(name: "New file"),
///     Option(name: "Open file"),
///     Option(name: "Save"),
/// ]
///
/// var menu = Menu(items: options, height: 5)
///
/// // In view():
/// menu.view()
///
/// // After the program exits:
/// if menu.isConfirmed, let picked = menu.selectedItem {
///     print("User picked: \(picked.filterValue())")
/// }
/// ```
public struct Menu: View {
    // MARK: - Public configuration

    /// Visual styles and cursor rune character.
    public var styles: MenuStyles

    /// Keybindings.
    public var keyMap: MenuKeyMap

    /// Whether the cursor wraps from the last item to the first and vice versa.
    public var infiniteScrolling: Bool

    // MARK: - Private state

    private let _id: Int
    private var _items: [any ListItem]
    private var _cursor: Int
    private var _offset: Int
    private var _width: Int
    private var _height: Int
    private var _confirmed: Bool

    // MARK: - Initializer

    /// Creates a new menu.
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
        self._id = _menuIDGenerator.next()
        self.styles = MenuStyles()
        self.keyMap = MenuKeyMap()
        self.infiniteScrolling = false
        self._items = items
        self._cursor = 0
        self._offset = 0
        self._width = max(1, width)
        self._height = max(1, height)
        self._confirmed = false
    }

    // MARK: - ELM interface

    /// No initial command is needed.
    public func initialize() -> Command? { nil }

    /// Handles keyboard input and window-resize messages.
    ///
    /// Responds to navigation, confirm, cancel, and quit bindings from
    /// ``keyMap``. ``keyMap/forceQuit`` always takes effect regardless of
    /// the ``KeyBinding/isEnabled`` state of other bindings.
    ///
    /// - Parameter msg: A message from the Chai event loop.
    /// - Returns: A ``Command`` posting a ``MenuSelectionMsg`` on confirm,
    ///   a ``MenuCancellationMsg`` on cancel/quit, `.quit` on force-quit, or `nil` otherwise.
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
        } else if keyMap.confirm.matches(key), !_items.isEmpty {
            _confirmed = true
            let id = _id
            let item = _items[_cursor]
            return .perform { MenuSelectionMsg(menuID: id, item: item) }
        } else if keyMap.cancel.matches(key) {
            let id = _id
            return .perform { MenuCancellationMsg(menuID: id) }
        } else if keyMap.quit.matches(key) {
            let id = _id
            return .perform { MenuCancellationMsg(menuID: id) }
        }

        return nil
    }

    /// Renders the visible slice of the menu.
    ///
    /// Each row is formatted as:
    /// ```
    /// > item text    (focused row)
    ///   item text    (other rows)
    /// ```
    ///
    /// - Returns: A ``Chai/ViewOutput`` whose content is the rendered menu.
    public var body: ViewOutput {
        guard !_items.isEmpty else {
            return ViewOutput(styles.normalStyle.styledText("No items."))
        }

        let end = min(_offset + _height, _items.count)
        var lines: [StyledText] = []

        for i in _offset..<end {
            let isFocused = i == _cursor

            // ── Rune column ──────────────────────────────────────────────
            let styledRune: StyledText = isFocused
                ? styles.cursorRuneStyle.styledText(String(styles.cursorRune))
                : StyledText(" ")

            // ── Item text ────────────────────────────────────────────────
            // Available columns: total width minus rune (1) and separator space (1).
            let availableWidth = max(0, _width - 2)
            let rawText = _items[i].filterValue()
            let text: String
            if availableWidth <= 0 {
                text = ""
            } else if rawText.count > availableWidth {
                text = String(rawText.prefix(max(0, availableWidth - 1))) + "…"
            } else {
                text = rawText
            }

            let styledItem: StyledText = isFocused
                ? styles.focusedStyle.styledText(text)
                : styles.normalStyle.styledText(text)

            lines.append(styledRune + StyledText(" ") + styledItem)
        }

        return ViewOutput(lines.joined())
    }

    // MARK: - Public API

    /// Unique identifier for this menu instance, useful for routing messages.
    public var id: Int { _id }

    /// All items in the menu.
    public var items: [any ListItem] { _items }

    /// The index of the item currently under the cursor.
    public var cursorIndex: Int { _cursor }

    /// The item currently under the cursor, or `nil` if the menu is empty.
    public var cursorItem: (any ListItem)? {
        guard !_items.isEmpty, _cursor < _items.count else { return nil }
        return _items[_cursor]
    }

    /// Whether the user confirmed a selection by pressing Enter.
    public var isConfirmed: Bool { _confirmed }

    /// The confirmed item, or `nil` if the user did not press Enter.
    ///
    /// This is non-nil only when ``isConfirmed`` is `true`.
    public var selectedItem: (any ListItem)? {
        guard _confirmed, !_items.isEmpty, _cursor < _items.count else { return nil }
        return _items[_cursor]
    }

    /// Replaces all items and resets cursor and confirmation state.
    ///
    /// - Parameter items: The replacement items.
    public mutating func setItems(_ items: [any ListItem]) {
        _items = items
        _cursor = 0
        _offset = 0
        _confirmed = false
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
