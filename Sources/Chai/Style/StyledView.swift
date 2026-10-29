// MARK: - StyledView

/// A view that applies a ``Style`` to the cells its content paints.
///
/// `StyledView` is the type behind the ``View/styled(_:)`` modifier and its
/// conveniences (`.fg`, `.bg`, `.bold`, `.dim`, `.italic`, `.underline`,
/// `.strikethrough`). It is a paint-time wrapper: the child is laid out
/// exactly as it would be without the style, and the style is merged into the
/// child's **occupied rect** — the content it reports under the assignment,
/// clamped to the assignment.
///
/// ```swift
/// VStack {
///     Text("Title").bold()
///     Text("body").fg(.green)
/// }
/// .bg(.brightBlack)
/// ```
///
/// ## Engine semantics
///
/// - **Query:** forwarded unchanged, so styling never changes measurement,
///   wrapping, or the allocation a parent decides.
/// - **Allocation:** the child is queried under the assignment, embedded at
///   its report clamped to the assignment (the occupied rect), and every cell
///   in that rect is then merged with the style.
/// - **Merge:** foreground, background, and hyperlink fill only properties the
///   inner content left unset, and attributes are unioned. Underline style and
///   underline color are adopted only when the cell has no underline of its
///   own. Nested modifiers paint inside-out, so the innermost explicit value
///   wins while outer attributes still accumulate.
/// - **Background coverage:** because the merge visits the whole occupied
///   rect, a background covers internal spaces and the gaps around narrower
///   children, and stops at the rect boundary.
/// - **Flexibility:** forwarded from the child, so a styled flexible view
///   still absorbs a stack's leftover space.
public struct StyledView<Content: View>: View {
    /// The content whose cells are styled.
    let content: Content

    /// The style merged into the content's cells.
    let style: Style

    /// Create a styled wrapper around a view.
    ///
    /// - Parameters:
    ///   - content: The view to style.
    ///   - style: The style to merge into the content's painted cells.
    public init(_ content: Content, style: Style) {
        self.content = content
        self.style = style
    }
}

// MARK: - StyledView engine implementation

extension StyledView {
    /// Forward the child's report: styling is not a layout operation.
    public func _measure(in available: AvailableSize) -> ViewSize {
        content._measure(in: available)
    }

    /// Embed the child at its reported rect, clamped to the assignment, then
    /// merge the style into every cell in that rect.
    ///
    /// The report decides the occupied rect (shrink-wrap): a style on a
    /// view allocated more space than it reports paints only the reported
    /// area, so `frame()` remains the opt-in for filling a larger box.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let attributes = style.textAttributes
        guard attributes.appliesToCells else {
            // A style that sets nothing (an empty style, or one with only
            // explicit `.off` flags) is a pass-through and must not change
            // what the child is allocated.
            buffer.embed(content, at: rect)
            return
        }

        let reported = content._measure(
            in: AvailableSize(width: rect.size.width, height: rect.size.height)
        )
        let occupied = ViewRect(
            origin: rect.origin,
            size: ViewSize(
                width: min(reported.width, rect.size.width),
                height: min(reported.height, rect.size.height)
            )
        ).intersection(rect)
        guard !occupied.isEmpty else { return }

        buffer.embed(content, at: occupied)
        merge(attributes, into: &buffer, in: occupied)
    }

    /// Forward the child's flexibility: a style wrapper is transparent to a
    /// stack's leftover distribution.
    public func _flexibility() -> LayoutFlexibility {
        content._flexibility()
    }

    /// Fill unset cell properties from `attributes` and union its text
    /// attributes across every cell of `rect`.
    ///
    /// Cells outside the buffer, and wide-character continuation cells, are
    /// skipped: the primary cell of a wide glyph carries the style, and
    /// writing a continuation cell would split the glyph.
    private func merge(
        _ attributes: TextAttributes,
        into buffer: inout CellBuffer,
        in rect: ViewRect
    ) {
        for row in rect.origin.row..<(rect.origin.row + rect.size.height) {
            for col in rect.origin.col..<(rect.origin.col + rect.size.width) {
                var cell = buffer[col, row]
                guard cell.width != 0 else { continue }

                if let foreground = attributes.foreground, cell.foreground == nil {
                    cell.foreground = foreground
                }
                if let background = attributes.background, cell.background == nil {
                    cell.background = background
                }
                if let hyperlink = attributes.hyperlink, cell.hyperlink == nil {
                    cell.hyperlink = hyperlink
                }

                // Underline decoration is inner-wins: an outer modifier adopts
                // only when the cell has no underline of its own.
                let hasUnderline = cell.underlineStyle != .none
                    || cell.attributes.contains(.underline)
                if !hasUnderline, attributes.underlineStyle != .none {
                    cell.underlineStyle = attributes.underlineStyle
                    cell.underlineColor = attributes.underlineColor
                }
                cell.attributes.formUnion(attributes.attributes)

                buffer.set(col: col, row: row, cell)
            }
        }
    }
}

// MARK: - View styling modifiers

extension View {
    /// Apply a style value to this view's painted cells.
    ///
    /// - Parameter style: The style to merge into every cell this view paints.
    /// - Returns: A ``StyledView`` wrapping this view.
    public func styled(_ style: Style) -> StyledView<Self> {
        StyledView(self, style: style)
    }

    /// Apply a foreground color to this view's painted cells.
    ///
    /// ```swift
    /// Text("error").fg(.red)
    /// ```
    ///
    /// - Parameter color: The foreground color.
    /// - Returns: A ``StyledView`` wrapping this view.
    public func fg(_ color: Color) -> StyledView<Self> {
        styled(Style().foreground(color))
    }

    /// Apply a background color to this view's occupied rect.
    ///
    /// The background covers every cell the view occupies, including internal
    /// spaces and gaps around narrower children. It never changes the view's
    /// size.
    ///
    /// - Parameter color: The background color.
    /// - Returns: A ``StyledView`` wrapping this view.
    public func bg(_ color: Color) -> StyledView<Self> {
        styled(Style().background(color))
    }

    /// Render this view's painted cells in bold.
    ///
    /// - Returns: A ``StyledView`` wrapping this view.
    public func bold() -> StyledView<Self> {
        styled(Style().bold())
    }

    /// Render this view's painted cells with reduced intensity.
    ///
    /// - Returns: A ``StyledView`` wrapping this view.
    public func dim() -> StyledView<Self> {
        styled(Style().dim())
    }

    /// Render this view's painted cells in italic.
    ///
    /// - Returns: A ``StyledView`` wrapping this view.
    public func italic() -> StyledView<Self> {
        styled(Style().italic())
    }

    /// Render this view's painted cells with a single underline.
    ///
    /// - Returns: A ``StyledView`` wrapping this view.
    public func underline() -> StyledView<Self> {
        styled(Style().underline())
    }

    /// Render this view's painted cells with a strikethrough.
    ///
    /// - Returns: A ``StyledView`` wrapping this view.
    public func strikethrough() -> StyledView<Self> {
        styled(Style().strikethrough())
    }
}

// MARK: - Cell applicability

extension TextAttributes {
    /// Whether this value sets any property that can be merged into a cell.
    ///
    /// A style value can be non-empty while setting nothing paintable: a
    /// ``Style`` of only `.off` flags carries intent for inheritance but emits
    /// no attribute bits, colors, or hyperlink.
    fileprivate var appliesToCells: Bool {
        foreground != nil
            || background != nil
            || hyperlink != nil
            || !attributes.isEmpty
            || underlineStyle != .none
            || underlineColor != nil
    }
}
