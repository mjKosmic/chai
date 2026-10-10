import Chai

// MARK: - Paginator Type

/// The visual style of a paginator.
public enum PaginatorType: Sendable {
    /// Dot-style pagination (e.g. `"● ○ ○ ○"`).
    case dots
    /// Arabic numeral pagination (e.g. `"1/5"`).
    case arabic
}

// MARK: - Paginator KeyMap

/// Keybindings for paginator navigation.
public struct PaginatorKeyMap: Sendable {
    /// Move to the previous page.
    public var prevPage: KeyBinding

    /// Move to the next page.
    public var nextPage: KeyBinding

    /// Creates a paginator key map with default bindings.
    public init(
        prevPage: KeyBinding = KeyBinding(
            .type(.pageUp), .type(.left), .rune("h"),
            help: KeyHelp("←/h/pgup", "prev page")
        ),
        nextPage: KeyBinding = KeyBinding(
            .type(.pageDown), .type(.right), .rune("l"),
            help: KeyHelp("→/l/pgdn", "next page")
        )
    ) {
        self.prevPage = prevPage
        self.nextPage = nextPage
    }
}

// MARK: - Paginator

/// A pagination state manager with optional visual rendering.
///
/// `Paginator` handles the logic of navigating pages: tracking the
/// current page, computing slice bounds, and rendering dot or arabic
/// style indicators. It does *not* render the page content itself.
///
/// ```swift
/// var paginator = Paginator(perPage: 10, totalItems: 45)
///
/// // Get the slice for the current page:
/// let bounds = paginator.sliceBounds(totalItems: items.count)
/// let pageItems = Array(items[bounds])
///
/// // Render the page indicator:
/// paginator.body   // "● ○ ○ ○ ○" or "1/5"
/// ```
public struct Paginator: View {
    /// The visual style — dots or arabic numbers.
    public var type: PaginatorType

    /// The current page (zero-indexed).
    public var page: Int

    /// The number of items per page.
    public var perPage: Int

    /// The total number of pages.
    public var totalPages: Int

    /// The string used for the active dot.
    public var activeDot: String

    /// The string used for inactive dots.
    public var inactiveDot: String

    /// Format string for arabic pagination. Receives (current, total).
    public var arabicFormat: String

    /// The keybindings for page navigation.
    public var keyMap: PaginatorKeyMap

    // MARK: - Initializer

    /// Creates a new paginator.
    ///
    /// - Parameters:
    ///   - type: The display type. Defaults to `.dots`.
    ///   - perPage: Items per page. Defaults to 10.
    ///   - totalItems: Total number of items. Defaults to 0.
    public init(
        type: PaginatorType = .dots,
        perPage: Int = 10,
        totalItems: Int = 0
    ) {
        self.type = type
        self.page = 0
        self.perPage = max(1, perPage)
        self.totalPages = Self.calculateTotalPages(totalItems: totalItems, perPage: perPage)
        self.activeDot = "●"
        self.inactiveDot = "○"
        self.arabicFormat = "%d/%d"
        self.keyMap = PaginatorKeyMap()
    }

    // MARK: - ELM interface

    /// No initial command needed.
    public func initialize() -> Command? { nil }

    /// Handles page navigation key events.
    public mutating func update(_ msg: any Message) -> Command? {
        guard let key = msg as? KeyMsg else { return nil }

        if keyMap.nextPage.matches(key) {
            nextPage()
        } else if keyMap.prevPage.matches(key) {
            prevPage()
        }

        return nil
    }

    /// Renders the pagination indicator.
    public var body: ViewOutput {
        switch type {
        case .dots:
            return ViewOutput(dotsView())
        case .arabic:
            return ViewOutput(arabicView())
        }
    }

    // MARK: - Navigation

    /// Advances to the next page if not already on the last page.
    public mutating func nextPage() {
        if !onLastPage {
            page += 1
        }
    }

    /// Moves to the previous page if not already on the first page.
    public mutating func prevPage() {
        if !onFirstPage {
            page -= 1
        }
    }

    /// Whether the current page is the first page.
    public var onFirstPage: Bool { page == 0 }

    /// Whether the current page is the last page.
    public var onLastPage: Bool { page >= totalPages - 1 }

    // MARK: - Slice computation

    /// Computes the array index range for items on the current page.
    ///
    /// - Parameter totalItems: The total number of items.
    /// - Returns: A range suitable for subscripting an array.
    public func sliceBounds(totalItems: Int) -> Range<Int> {
        let start = page * perPage
        let end = min(start + perPage, totalItems)
        guard start < totalItems else { return 0..<0 }
        return start..<end
    }

    /// The number of items on the current page.
    ///
    /// - Parameter totalItems: The total number of items.
    /// - Returns: The count of items on this page.
    public func itemsOnPage(totalItems: Int) -> Int {
        let bounds = sliceBounds(totalItems: totalItems)
        return bounds.count
    }

    /// Updates the total pages based on a new item count.
    public mutating func setTotalPages(fromItems totalItems: Int) {
        totalPages = Self.calculateTotalPages(totalItems: totalItems, perPage: perPage)
        // Clamp current page
        if page >= totalPages {
            page = max(0, totalPages - 1)
        }
    }

    // MARK: - Private rendering

    private func dotsView() -> String {
        (0..<totalPages).map { i in
            i == page ? activeDot : inactiveDot
        }.joined(separator: " ")
    }

    private func arabicView() -> String {
        String(format: arabicFormat, page + 1, totalPages)
    }

    private static func calculateTotalPages(totalItems: Int, perPage: Int) -> Int {
        let pp = max(1, perPage)
        guard totalItems > 0 else { return 1 }
        return (totalItems + pp - 1) / pp
    }
}
