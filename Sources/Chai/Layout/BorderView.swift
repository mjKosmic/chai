
// MARK: - BorderView
//
// The border is a rect inset in the view tree. The wrapper reserves one cell
// on every side, reports the child's size plus the frame, draws the box at its
// allocated origin, and embeds the child inside. Like padding it shrink-wraps
// to its content; the assignment bounds the child's query so wrapping
// composes.

/// A view that draws a border around its content.
///
/// ``View/bordered(_:)`` reserves one terminal cell on every side: the child
/// is queried and embedded inside the frame, and the border glyphs are painted
/// at the wrapper's allocated origin. The wrapper stays in the view tree, so
/// the box participates in layout like any other view:
///
/// ```swift
/// HStack {
///     Text("a").bordered(.ascii)   // occupies 3×3
///     Text("b")
/// }
/// ```
///
/// ## Engine semantics
///
/// - **Query:** the child is queried with the assignment reduced by two on
///   each axis; the report is the child's report plus two.
/// - **Allocation:** the box is drawn at the assigned origin at the reported
///   size (child plus the frame), clamped to the assignment so a clipped box
///   still closes its visible edges, and the child is embedded one cell
///   inside. Like padding, the wrapper shrink-wraps rather than stretching to
///   a larger assignment; `frame()` is the opt-in for filling.
/// - **Flexibility:** forwarded from the child (a flexible child inside a
///   border still absorbs a stack's leftover space).
///
/// ## Styling
///
/// Border glyphs can carry a ``Style``. `borderStyle` applies to every edge;
/// `topStyle`, `bottomStyle`, `leftStyle`, and `rightStyle` override it per
/// side. Corners inherit the style of their horizontal edge. The content
/// inside the border is never styled by these parameters.
public struct BorderView<Content: View>: View {
    /// The glyph set used to draw the box.
    let style: Border
    /// Style applied to every edge unless a per-side style overrides it.
    let borderStyle: Style?
    /// Style for the top edge and top corners.
    let topStyle: Style?
    /// Style for the bottom edge and bottom corners.
    let bottomStyle: Style?
    /// Style for the left edge on content lines.
    let leftStyle: Style?
    /// Style for the right edge on content lines.
    let rightStyle: Style?
    /// The bordered content.
    let content: Content

    /// Create a border wrapper.
    ///
    /// - Parameters:
    ///   - style: The ``Border`` character set to draw.
    ///   - borderStyle: Style applied to all border glyphs. Defaults to `nil`.
    ///   - topStyle: Style for the top edge and top corners; overrides
    ///     `borderStyle` for those glyphs.
    ///   - bottomStyle: Style for the bottom edge and bottom corners; overrides
    ///     `borderStyle` for those glyphs.
    ///   - leftStyle: Style for the left edge on content lines; overrides
    ///     `borderStyle` for those glyphs.
    ///   - rightStyle: Style for the right edge on content lines; overrides
    ///     `borderStyle` for those glyphs.
    ///   - content: A ``ViewBuilder`` closure providing the content.
    public init(
        _ style: Border = .normal,
        borderStyle: Style? = nil,
        topStyle: Style? = nil,
        bottomStyle: Style? = nil,
        leftStyle: Style? = nil,
        rightStyle: Style? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.style = style
        self.borderStyle = borderStyle
        self.topStyle = topStyle
        self.bottomStyle = bottomStyle
        self.leftStyle = leftStyle
        self.rightStyle = rightStyle
        self.content = content()
    }
}

// MARK: - BorderView engine implementation

extension BorderView {
    /// The child's query context inside the one-cell frame.
    private func childQuery(for available: AvailableSize) -> AvailableSize {
        AvailableSize(
            width: available.width.map { max(0, $0 - 2) },
            height: available.height.map { max(0, $0 - 2) }
        )
    }

    /// Report the child's report plus the one-cell frame on each side.
    public func _measure(in available: AvailableSize) -> ViewSize {
        let child = content._measure(in: childQuery(for: available))
        return ViewSize(width: child.width + 2, height: child.height + 2)
    }

    /// Draw the box at the wrapper's allocated origin and embed the child one
    /// cell inside, clamped to the available area. Under the hard-box
    /// contract the box and child are additionally clipped to the allocation.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let inset = ViewRect(
            origin: ViewOrigin(col: rect.origin.col + 1, row: rect.origin.row + 1),
            size: ViewSize(
                width: max(0, rect.size.width - 2),
                height: max(0, rect.size.height - 2)
            )
        ).intersection(rect)

        let reported = content._measure(
            in: AvailableSize(width: inset.size.width, height: inset.size.height)
        )

        // The box is drawn at the report (child plus the frame), but never
        // larger than the allocation: under the hard-box contract a clipped
        // border must still close its visible edges. Drawing at the
        // unclamped report would push the bottom/right edges outside the
        // allocation, where the kernel drops them.
        drawBox(
            width: min(reported.width + 2, rect.size.width),
            height: min(reported.height + 2, rect.size.height),
            into: &buffer,
            at: rect.origin
        )

        let childSize = ViewSize(
            width: min(reported.width, inset.size.width),
            height: min(reported.height, inset.size.height)
        )
        let childRect = ViewRect(origin: inset.origin, size: childSize).intersection(inset)
        if !childRect.isEmpty {
            buffer.embed(content, at: childRect)
        }
    }

    /// Forward the child's flexibility: the border is transparent to a
    /// stack's leftover distribution.
    public func _flexibility() -> LayoutFlexibility {
        content._flexibility()
    }

    // MARK: Drawing

    /// Style for the top edge and its corners.
    private var effectiveTop: Style? { topStyle ?? borderStyle }
    /// Style for the bottom edge and its corners.
    private var effectiveBottom: Style? { bottomStyle ?? borderStyle }
    /// Style for the left edge between the corners.
    private var effectiveLeft: Style? { leftStyle ?? borderStyle }
    /// Style for the right edge between the corners.
    private var effectiveRight: Style? { rightStyle ?? borderStyle }

    /// Paint the box's edges into the buffer. Degenerate sizes draw the part
    /// that fits: a one-column box paints its left edge glyphs, and a
    /// one-row box paints only the top edge.
    private func drawBox(
        width: Int,
        height: Int,
        into buffer: inout CellBuffer,
        at origin: ViewOrigin
    ) {
        guard width > 0, height > 0 else { return }
        let lastCol = origin.col + width - 1
        let lastRow = origin.row + height - 1

        // Top edge (and the top corners when there is room for them).
        if width == 1 {
            paint(style.topLeft, col: origin.col, row: origin.row, style: effectiveTop, into: &buffer)
        } else {
            paint(style.topLeft, col: origin.col, row: origin.row, style: effectiveTop, into: &buffer)
            paint(style.topRight, col: lastCol, row: origin.row, style: effectiveTop, into: &buffer)
            for col in (origin.col + 1)..<lastCol {
                paint(style.top, col: col, row: origin.row, style: effectiveTop, into: &buffer)
            }
        }

        // Bottom edge.
        if height > 1 {
            if width == 1 {
                paint(style.bottomLeft, col: origin.col, row: lastRow, style: effectiveBottom, into: &buffer)
            } else {
                paint(style.bottomLeft, col: origin.col, row: lastRow, style: effectiveBottom, into: &buffer)
                paint(style.bottomRight, col: lastCol, row: lastRow, style: effectiveBottom, into: &buffer)
                for col in (origin.col + 1)..<lastCol {
                    paint(style.bottom, col: col, row: lastRow, style: effectiveBottom, into: &buffer)
                }
            }
        }

        // Side edges between the corners.
        if height > 2 {
            for row in (origin.row + 1)..<lastRow {
                paint(style.left, col: origin.col, row: row, style: effectiveLeft, into: &buffer)
                if width > 1 {
                    paint(style.right, col: lastCol, row: row, style: effectiveRight, into: &buffer)
                }
            }
        }
    }

    /// Paint a glyph string starting at `col`. ``Border`` documents every
    /// field as a single terminal column; a multi-character custom glyph is
    /// written left-to-right and its display width advances the column.
    /// Glyph cells carry the resolved style as structured attributes.
    private func paint(
        _ glyph: String,
        col: Int,
        row: Int,
        style: Style?,
        into buffer: inout CellBuffer
    ) {
        var currentCol = col
        for character in glyph {
            let width = displayWidth(of: character)
            guard width > 0 else { continue }
            buffer.set(
                col: currentCol,
                row: row,
                styledCell(character, width: width, style: style)
            )
            currentCol += width
        }
    }

    /// Build a border glyph cell, attaching the style's structured attributes
    /// when one is present.
    private func styledCell(_ character: Character, width: Int, style: Style?) -> Cell {
        guard let style else {
            return Cell(character: character, width: Int8(width))
        }
        let attributes = style.textAttributes
        return Cell(
            character: character,
            width: Int8(width),
            foreground: attributes.foreground,
            background: attributes.background,
            attributes: attributes.attributes,
            hyperlink: attributes.hyperlink,
            underlineStyle: attributes.underlineStyle,
            underlineColor: attributes.underlineColor
        )
    }
}

// MARK: - View.bordered modifier

extension View {
    /// Draw a border around this view.
    ///
    /// The border reserves one cell on every side and stays in the view tree,
    /// so the framed content participates in layout like any other view.
    ///
    /// ```swift
    /// VStack {
    ///     Text("Title")
    ///     Text("Body")
    /// }
    /// .bordered(.rounded)
    /// ```
    ///
    /// - Parameters:
    ///   - style: The ``Border`` character set to use.
    ///   - borderStyle: Style applied to all border glyphs. Defaults to `nil`.
    ///   - topStyle: Style for the top edge and top corners.
    ///   - bottomStyle: Style for the bottom edge and bottom corners.
    ///   - leftStyle: Style for the left edge on content lines.
    ///   - rightStyle: Style for the right edge on content lines.
    /// - Returns: A ``BorderView`` wrapping this view.
    public func bordered(
        _ style: Border = .normal,
        borderStyle: Style? = nil,
        topStyle: Style? = nil,
        bottomStyle: Style? = nil,
        leftStyle: Style? = nil,
        rightStyle: Style? = nil
    ) -> BorderView<Self> {
        BorderView(
            style,
            borderStyle: borderStyle,
            topStyle: topStyle,
            bottomStyle: bottomStyle,
            leftStyle: leftStyle,
            rightStyle: rightStyle
        ) { self }
    }
}
