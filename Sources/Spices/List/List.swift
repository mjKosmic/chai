import Chai
import Latte
// MARK: - Filter State

/// The current state of the list's filter.
public enum FilterState: Sendable {
    /// No filter is active.
    case unfiltered
    /// The user is actively typing a filter query.
    case filtering
    /// A filter has been applied and results are showing.
    case filterApplied
}

// MARK: - List messages

/// Internal message delivered when filter matching completes.
struct ListFilterMatchesMsg: Message {
    let matches: [ListFilterMatch]
}

/// Internal message for status message timeout.
struct ListStatusTimeoutMsg: Message {
    let id: Int
    let tag: Int
}

// MARK: - List Styles

/// Styles for the list component.
public struct ListStyles: Sendable {
    /// Style for the title bar.
    public var titleBar: Style
    /// Style for the title text.
    public var title: Style
    /// Style for the spinner.
    public var spinner: Style
    /// Style for the filter prompt.
    public var filterPrompt: Style
    /// Style for the filter cursor.
    public var filterCursor: Style
    /// Style for the status bar.
    public var statusBar: Style
    /// Style for the status bar when empty.
    public var statusEmpty: Style
    /// Style for the active filter indicator.
    public var statusBarActiveFilter: Style
    /// Style for the filter count.
    public var statusBarFilterCount: Style
    /// Style for the "no items" message.
    public var noItems: Style
    /// Style for the pagination.
    public var paginationStyle: Style
    /// Style for the help text.
    public var helpStyle: Style
    /// Style for the divider dot.
    public var dividerDot: Style

    /// Creates list styles with sensible defaults.
    public init() {
        self.titleBar = Style()
        self.title = Style(isBold: true)
        self.spinner = Style()
        self.filterPrompt = Style()
        self.filterCursor = Style()
        self.statusBar = Style(isDim: true)
        self.statusEmpty = Style(isDim: true)
        self.statusBarActiveFilter = Style()
        self.statusBarFilterCount = Style(isDim: true)
        self.noItems = Style(isDim: true)
        self.paginationStyle = Style(isDim: true)
        self.helpStyle = Style(isDim: true)
        self.dividerDot = Style(isDim: true)
    }
}

// MARK: - List KeyMap

/// Keybindings for the list component.
public struct ListKeyMap: Sendable, HelpKeyMap {
    public var cursorUp: KeyBinding
    public var cursorDown: KeyBinding
    public var nextPage: KeyBinding
    public var prevPage: KeyBinding
    public var goToStart: KeyBinding
    public var goToEnd: KeyBinding
    public var filter: KeyBinding
    public var clearFilter: KeyBinding
    public var cancelWhileFiltering: KeyBinding
    public var acceptWhileFiltering: KeyBinding
    public var showFullHelp: KeyBinding
    public var closeFullHelp: KeyBinding
    public var quit: KeyBinding
    public var forceQuit: KeyBinding

    /// Creates a list key map with default bindings.
    public init() {
        cursorUp = KeyBinding(.type(.up), .rune("k"),
                              help: KeyHelp("↑/k", "up"))
        cursorDown = KeyBinding(.type(.down), .rune("j"),
                                help: KeyHelp("↓/j", "down"))
        nextPage = KeyBinding(.type(.pageDown), .rune("l"), .type(.right),
                              help: KeyHelp("→/l/pgdn", "next page"))
        prevPage = KeyBinding(.type(.pageUp), .rune("h"), .type(.left),
                              help: KeyHelp("←/h/pgup", "prev page"))
        goToStart = KeyBinding(.type(.home), .rune("g"),
                               help: KeyHelp("g/home", "start"))
        goToEnd = KeyBinding(.type(.end),
                             help: KeyHelp("G/end", "end"))
        filter = KeyBinding(.rune("/"),
                            help: KeyHelp("/", "filter"))
        clearFilter = KeyBinding(.type(.escape),
                                 help: KeyHelp("esc", "clear filter"))
        cancelWhileFiltering = KeyBinding(.type(.escape),
                                          help: KeyHelp("esc", "cancel"))
        acceptWhileFiltering = KeyBinding(.type(.enter),
                                          help: KeyHelp("enter", "apply"))
        showFullHelp = KeyBinding(.rune("?"),
                                  help: KeyHelp("?", "more"))
        closeFullHelp = KeyBinding(.rune("?"),
                                   help: KeyHelp("?", "close help"))
        quit = KeyBinding(.rune("q"),
                          help: KeyHelp("q", "quit"))
        forceQuit = KeyBinding(.type(.ctrl("c")),
                               help: KeyHelp("ctrl+c", "force quit"))
    }

    public func shortHelp() -> [KeyBinding] {
        [cursorUp, cursorDown, filter, showFullHelp, quit]
    }

    public func fullHelp() -> [[KeyBinding]] {
        [
            [cursorUp, cursorDown, nextPage, prevPage, goToStart, goToEnd],
            [filter, clearFilter, showFullHelp, quit, forceQuit],
        ]
    }
}

// MARK: - List

/// A feature-rich browsable list with fuzzy filtering, pagination,
/// help, spinner, and status messages.
///
/// The list composes several sub-components (``Paginator``, ``TextInput``,
/// ``Spinner``, ``Help``) into a batteries-included browsable interface.
///
/// ```swift
/// struct Item: ListItem {
///     let name: String
///     func filterValue() -> String { name }
/// }
///
/// let items: [any ListItem] = [Item(name: "Foo"), Item(name: "Bar")]
/// var list = List(items: items, delegate: DefaultListItemDelegate(), width: 40, height: 20)
///
/// // In initialize():
/// list.initialize()
///
/// // In update():
/// list.update(msg)
///
/// // In view():
/// list.view()
/// ```
public struct List: Sendable {
    /// The list title.
    public var title: String

    /// Whether scrolling wraps around.
    public var infiniteScrolling: Bool

    /// Styles for the list.
    public var styles: ListStyles

    /// Keybindings.
    public var keyMap: ListKeyMap

    /// The paginator sub-component.
    public var paginator: Paginator

    /// The help sub-component.
    public var help: Help

    /// The filter text input sub-component.
    public var filterInput: TextInput

    /// The duration status messages remain visible.
    public var statusMessageLifetime: Duration

    /// The item rendering delegate.
    public var delegate: any ListItemDelegate

    /// The filter function.
    public var filter: (@Sendable (String, [any ListItem]) -> [ListFilterMatch])?

    // MARK: - Visibility toggles

    /// Whether to show the title bar.
    public var showTitle: Bool

    /// Whether to show the filter input.
    public var showFilter: Bool

    /// Whether to show the status bar.
    public var showStatusBar: Bool

    /// Whether to show the pagination indicator.
    public var showPagination: Bool

    /// Whether to show the help view.
    public var showHelp: Bool

    /// Whether filtering is enabled.
    public var filteringEnabled: Bool

    // MARK: Private state

    private let _id: Int
    private var _items: [any ListItem]
    private var _filteredItems: [ListFilterMatch]
    private var _cursor: Int
    private var _filterState: FilterState
    private var _width: Int
    private var _height: Int
    private var _spinner: Spinner
    private var _showSpinner: Bool
    private var _statusMessage: String?
    private var _statusTag: Int
    private var _itemNameSingular: String
    private var _itemNamePlural: String
    private var _disableQuitKeybindings: Bool

    // MARK: - Initializer

    /// Creates a new list.
    ///
    /// - Parameters:
    ///   - items: The items to display.
    ///   - delegate: The item rendering delegate.
    ///   - width: Display width.
    ///   - height: Display height.
    public init(
        items: [any ListItem] = [],
        delegate: any ListItemDelegate = DefaultListItemDelegate(),
        width: Int = 40,
        height: Int = 20
    ) {
        self.title = ""
        self.infiniteScrolling = false
        self.styles = ListStyles()
        self.keyMap = ListKeyMap()
        self.paginator = Paginator(type: .dots, perPage: 1)
        self.help = Help(width: width)
        self.filterInput = TextInput(prompt: "Filter: ", placeholder: "", width: width)
        self.filterInput.promptStyle = Style()
        self.statusMessageLifetime = .seconds(2)
        self.delegate = delegate
        self.filter = { @Sendable query, items in defaultListFilter(query: query, items: items) }
        self.showTitle = true
        self.showFilter = true
        self.showStatusBar = true
        self.showPagination = true
        self.showHelp = true
        self.filteringEnabled = true
        self._id = _listIDGenerator.next()
        self._items = items
        self._filteredItems = items.map { ListFilterMatch(item: $0) }
        self._cursor = 0
        self._filterState = .unfiltered
        self._width = width
        self._height = height
        self._spinner = Spinner(type: .dot)
        self._showSpinner = false
        self._statusMessage = nil
        self._statusTag = 0
        self._itemNameSingular = "item"
        self._itemNamePlural = "items"
        self._disableQuitKeybindings = false

        updatePagination()
    }

    // MARK: - ELM interface

    /// Returns commands for sub-component initialization.
    public mutating func initialize() -> Command? {
        var commands: [Command] = []
        if let cmd = _spinner.initialize() { commands.append(cmd) }
        return commands.isEmpty ? nil : .batch(commands)
    }

    /// Handles all input for the list and its sub-components.
    public mutating func update(_ msg: any Message) -> Command? {
        // Spinner updates
        if let spinnerCmd = _spinner.update(msg) {
            return spinnerCmd
        }

        // Status message timeout
        if let timeout = msg as? ListStatusTimeoutMsg,
           timeout.id == _id, timeout.tag == _statusTag {
            _statusMessage = nil
            return nil
        }

        // Window size
        if let size = msg as? WindowSizeMsg {
            setSize(width: size.width, height: size.height)
            return nil
        }

        // Key handling
        guard let key = msg as? KeyMsg else { return nil }

        // Force quit always works
        if keyMap.forceQuit.matches(key) {
            return .quit
        }

        switch _filterState {
        case .filtering:
            return handleFilteringKey(key)
        case .unfiltered, .filterApplied:
            return handleBrowsingKey(key)
        }
    }

    /// Renders the complete list view.
    public func view() -> ViewOutput {
        var sections: [StyledText] = []
        let visibleItems = currentVisibleItems

        // Title bar
        if showTitle && !title.isEmpty {
            var titleLine = styles.title.styledText(title)
            if _showSpinner {
                titleLine += StyledText(" ") + _spinner.view().content
            }
            sections.append(titleLine.styled(styles.titleBar.textAttributes))
        }

        // Filter input — use .content directly to preserve structured styling.
        if _filterState == .filtering {
            sections.append(filterInput.view().content)
        }

        // Items
        if visibleItems.isEmpty {
            let noun = _items.count == 1 ? _itemNameSingular : _itemNamePlural
            if _filterState == .filterApplied {
                sections.append(styles.noItems.styledText("No matching \(noun)."))
            } else {
                sections.append(styles.noItems.styledText("No \(noun)."))
            }
        } else {
            let bounds = paginator.sliceBounds(totalItems: visibleItems.count)
            for i in bounds {
                let match = visibleItems[i]
                let isSelected = i == _cursor
                // delegate.render() returns StyledText directly.
                let rendered = delegate.render(
                    item: match.item,
                    index: i,
                    isSelected: isSelected,
                    width: _width
                )
                sections.append(rendered)

                // Spacing between items
                if delegate.spacing > 0 && i < bounds.upperBound - 1 {
                    sections.append(StyledText(String(repeating: "\n", count: delegate.spacing)))
                }
            }
        }

        // Status bar
        if showStatusBar {
            sections.append(statusBarView())
        }

        // Pagination — use paginator's StyledText content directly, then apply style.
        if showPagination && paginator.totalPages > 1 {
            sections.append(paginator.view().content.styled(styles.paginationStyle.textAttributes))
        }

        // Help — help.view() already returns StyledText with per-key styling;
        // apply the list's helpStyle as a base style over all segments.
        if showHelp {
            sections.append(help.view(keyMap: keyMap).styled(styles.helpStyle.textAttributes))
        }

        return ViewOutput(sections.joined())
    }

    // MARK: - Public API

    /// The items in the list.
    public var items: [any ListItem] { _items }

    /// Sets the items and re-applies the current filter.
    public mutating func setItems(_ items: [any ListItem]) {
        _items = items
        applyFilter()
        updatePagination()
    }

    /// The currently visible items (filtered or all).
    public var visibleItems: [ListFilterMatch] {
        currentVisibleItems
    }

    /// The currently selected item.
    public var selectedItem: (any ListItem)? {
        let items = currentVisibleItems
        guard !items.isEmpty, _cursor < items.count else { return nil }
        return items[_cursor].item
    }

    /// The index of the selected item in the visible list.
    public var index: Int { _cursor }

    /// The global index of the selected item in the original items array.
    public func globalIndex(of visibleIndex: Int) -> Int? {
        let items = currentVisibleItems
        guard visibleIndex < items.count else { return nil }
        let selectedValue = items[visibleIndex].item.filterValue()
        return _items.firstIndex { $0.filterValue() == selectedValue }
    }

    /// Sets the cursor to a specific index.
    public mutating func select(_ index: Int) {
        let items = currentVisibleItems
        _cursor = max(0, min(index, items.count - 1))
    }

    /// Sets the display size.
    public mutating func setSize(width: Int, height: Int) {
        _width = width
        _height = height
        help.width = width
        filterInput.width = width
        updatePagination()
    }

    /// The current filter state.
    public var filterState: FilterState { _filterState }

    /// Sets a status message that auto-dismisses after ``statusMessageLifetime``.
    @discardableResult
    public mutating func newStatusMessage(_ text: String) -> Command? {
        _statusMessage = text
        _statusTag += 1
        let id = self._id
        let tag = self._statusTag
        let lifetime = self.statusMessageLifetime
        return .tick(lifetime) { _ in
            ListStatusTimeoutMsg(id: id, tag: tag)
        }
    }

    /// Starts the spinner.
    @discardableResult
    public mutating func startSpinner() -> Command? {
        _showSpinner = true
        _spinner.reset()
        return _spinner.tick()
    }

    /// Stops the spinner.
    public mutating func stopSpinner() {
        _showSpinner = false
    }

    /// Toggles the spinner.
    @discardableResult
    public mutating func toggleSpinner() -> Command? {
        if _showSpinner {
            stopSpinner()
            return nil
        } else {
            return startSpinner()
        }
    }

    /// Disables the default quit keybindings (q/ctrl+c).
    public mutating func disableQuitKeybindings() {
        _disableQuitKeybindings = true
        keyMap.quit.isEnabled = false
    }

    /// Sets the singular/plural nouns for the item type.
    public mutating func setItemNames(singular: String, plural: String) {
        _itemNameSingular = singular
        _itemNamePlural = plural
    }

    /// Removes an item at the given index.
    public mutating func removeItem(at index: Int) {
        guard index >= 0 && index < _items.count else { return }
        _items.remove(at: index)
        applyFilter()
        updatePagination()
    }

    /// Inserts an item at the given index.
    public mutating func insertItem(_ item: any ListItem, at index: Int) {
        let idx = max(0, min(index, _items.count))
        _items.insert(item, at: idx)
        applyFilter()
        updatePagination()
    }

    // MARK: - Private: Key handling

    private mutating func handleBrowsingKey(_ key: KeyMsg) -> Command? {
        if keyMap.cursorUp.matches(key) {
            cursorUp()
        } else if keyMap.cursorDown.matches(key) {
            cursorDown()
        } else if keyMap.nextPage.matches(key) {
            paginator.nextPage()
            _cursor = min(_cursor, currentVisibleItems.count - 1)
        } else if keyMap.prevPage.matches(key) {
            paginator.prevPage()
            _cursor = min(_cursor, currentVisibleItems.count - 1)
        } else if keyMap.goToStart.matches(key) {
            _cursor = 0
            paginator.page = 0
        } else if keyMap.goToEnd.matches(key) {
            // Match "G"
            if key.type.isRunes && key.runes == ["G"] {
                let items = currentVisibleItems
                _cursor = max(0, items.count - 1)
                paginator.page = max(0, paginator.totalPages - 1)
            }
        } else if keyMap.filter.matches(key) && filteringEnabled {
            startFiltering()
        } else if keyMap.clearFilter.matches(key) && _filterState == .filterApplied {
            clearFilter()
        } else if keyMap.showFullHelp.matches(key) {
            help.showAll.toggle()
        } else if keyMap.quit.matches(key) && !_disableQuitKeybindings {
            return .quit
        }
        return nil
    }

    private mutating func handleFilteringKey(_ key: KeyMsg) -> Command? {
        if keyMap.cancelWhileFiltering.matches(key) {
            cancelFiltering()
            return nil
        }
        if keyMap.acceptWhileFiltering.matches(key) {
            acceptFilter()
            return nil
        }

        // Delegate to text input
        let cmd = filterInput.update(key)
        applyFilter()
        return cmd
    }

    // MARK: - Private: Navigation

    private mutating func cursorUp() {
        let items = currentVisibleItems
        guard !items.isEmpty else { return }

        if _cursor > 0 {
            _cursor -= 1
        } else if infiniteScrolling {
            _cursor = items.count - 1
            paginator.page = max(0, paginator.totalPages - 1)
        }

        // Update paginator page
        if paginator.perPage > 0 {
            let page = _cursor / paginator.perPage
            paginator.page = page
        }
    }

    private mutating func cursorDown() {
        let items = currentVisibleItems
        guard !items.isEmpty else { return }

        if _cursor < items.count - 1 {
            _cursor += 1
        } else if infiniteScrolling {
            _cursor = 0
            paginator.page = 0
        }

        // Update paginator page
        if paginator.perPage > 0 {
            let page = _cursor / paginator.perPage
            paginator.page = page
        }
    }

    // MARK: - Private: Filtering

    private mutating func startFiltering() {
        _filterState = .filtering
        filterInput.setValue("")
        _ = filterInput.focus()
    }

    private mutating func cancelFiltering() {
        _filterState = _filteredItems.count < _items.count ? .filterApplied : .unfiltered
        filterInput.blur()
    }

    private mutating func acceptFilter() {
        if filterInput.value.isEmpty {
            clearFilter()
        } else {
            _filterState = .filterApplied
        }
        filterInput.blur()
    }

    private mutating func clearFilter() {
        _filterState = .unfiltered
        filterInput.setValue("")
        filterInput.blur()
        _filteredItems = _items.map { ListFilterMatch(item: $0) }
        _cursor = 0
        updatePagination()
    }

    private mutating func applyFilter() {
        let query = filterInput.value
        if query.isEmpty {
            _filteredItems = _items.map { ListFilterMatch(item: $0) }
        } else if let filterFn = filter {
            _filteredItems = filterFn(query, _items)
        } else {
            _filteredItems = _items.map { ListFilterMatch(item: $0) }
        }
        _cursor = min(_cursor, max(0, _filteredItems.count - 1))
        updatePagination()
    }

    // MARK: - Private: Helpers

    private var currentVisibleItems: [ListFilterMatch] {
        switch _filterState {
        case .unfiltered:
            return _items.map { ListFilterMatch(item: $0) }
        case .filtering, .filterApplied:
            return _filteredItems
        }
    }

    private mutating func updatePagination() {
        let items = currentVisibleItems
        // Calculate items per page based on height
        let itemHeight = delegate.height + delegate.spacing
        let chrome = chromeHeight
        let availableHeight = max(1, _height - chrome)
        let perPage = max(1, itemHeight > 0 ? availableHeight / itemHeight : availableHeight)

        paginator.perPage = perPage
        paginator.setTotalPages(fromItems: items.count)
    }

    /// The height taken by non-item UI elements.
    private var chromeHeight: Int {
        var h = 0
        if showTitle && !title.isEmpty { h += 1 }
        if _filterState == .filtering { h += 1 }
        if showStatusBar { h += 1 }
        if showPagination && paginator.totalPages > 1 { h += 1 }
        if showHelp { h += 1 }
        return h
    }

    private func statusBarView() -> StyledText {
        if let msg = _statusMessage {
            return styles.statusBar.styledText(msg)
        }

        let items = currentVisibleItems
        let total = _items.count
        let visible = items.count
        let noun = total == 1 ? _itemNameSingular : _itemNamePlural

        switch _filterState {
        case .unfiltered:
            return styles.statusBar.styledText("\(total) \(noun)")
        case .filtering, .filterApplied:
            return styles.statusBarFilterCount.styledText("\(visible)/\(total) \(noun)")
        }
    }
}

// MARK: - ID generation

private let _listIDGenerator = IDGenerator()
