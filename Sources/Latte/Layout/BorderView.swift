import Chai

// MARK: - BorderView (Stage C wrapper)
//
// Phase 4 P4a (UPGRADE.md, "Stage C on the new kernel"): the border is a rect
// inset in the view tree. The wrapper reserves one cell on every side, reports
// the child's size plus the frame, draws the box at its allocated origin, and
// embeds the child inside. Like padding it shrink-wraps to its content; the
// assignment bounds the child's query so wrapping composes.

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
///   size (child plus the frame), and the child is embedded one cell inside.
///   Like padding, the wrapper shrink-wraps rather than stretching to a larger
///   assignment; `frame()` is the opt-in for filling.
/// - **Flexibility:** forwarded from the child (a flexible child inside a
///   border still absorbs a stack's leftover space).
public struct BorderView<Content: View>: View {
    /// The glyph set used to draw the box.
    let style: Border
    /// The bordered content.
    let content: Content

    /// Create a border wrapper.
    ///
    /// - Parameters:
    ///   - style: The ``Border`` character set to draw.
    ///   - content: A ``ViewBuilder`` closure providing the content.
    public init(_ style: Border = .normal, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    // MARK: Legacy body (eager path)

    /// The eager resolution path, retired with the rest of the eager family
    /// in P4b. It reproduces the pre-wrapper behavior exactly.
    public var body: ViewOutput {
        ViewOutput(content._resolveToViewOutput().content.bordered(style))
    }
}

// MARK: - BorderView engine implementation

extension BorderView {
    /// The child's proposal inside the one-cell frame.
    private func childProposal(for proposal: ProposedSize) -> ProposedSize {
        ProposedSize(
            width: proposal.width.map { max(0, $0 - 2) },
            height: proposal.height.map { max(0, $0 - 2) }
        )
    }

    /// Report the child's report plus the one-cell frame on each side.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let child = content._sizeThatFits(childProposal(for: proposal))
        return ViewSize(width: child.width + 2, height: child.height + 2)
    }

    /// Draw the box at the wrapper's allocated origin and embed the child one
    /// cell inside, at the size the child reports under the inset query.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let childSize = content._sizeThatFits(childProposal(for: ProposedSize(
            width: rect.size.width,
            height: rect.size.height
        )))
        drawBox(
            width: childSize.width + 2,
            height: childSize.height + 2,
            into: &buffer,
            at: rect.origin
        )
        content._embed(
            into: &buffer,
            at: ViewRect(
                origin: ViewOrigin(col: rect.origin.col + 1, row: rect.origin.row + 1),
                size: childSize
            )
        )
    }

    /// Forward the child's flexibility: the border is transparent to a
    /// stack's leftover distribution.
    public func _flexibility() -> LayoutFlexibility {
        content._flexibility()
    }

    // MARK: Drawing

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
            paint(style.topLeft, col: origin.col, row: origin.row, into: &buffer)
        } else {
            paint(style.topLeft, col: origin.col, row: origin.row, into: &buffer)
            paint(style.topRight, col: lastCol, row: origin.row, into: &buffer)
            for col in (origin.col + 1)..<lastCol {
                paint(style.top, col: col, row: origin.row, into: &buffer)
            }
        }

        // Bottom edge.
        if height > 1 {
            if width == 1 {
                paint(style.bottomLeft, col: origin.col, row: lastRow, into: &buffer)
            } else {
                paint(style.bottomLeft, col: origin.col, row: lastRow, into: &buffer)
                paint(style.bottomRight, col: lastCol, row: lastRow, into: &buffer)
                for col in (origin.col + 1)..<lastCol {
                    paint(style.bottom, col: col, row: lastRow, into: &buffer)
                }
            }
        }

        // Side edges between the corners.
        if height > 2 {
            for row in (origin.row + 1)..<lastRow {
                paint(style.left, col: origin.col, row: row, into: &buffer)
                if width > 1 {
                    paint(style.right, col: lastCol, row: row, into: &buffer)
                }
            }
        }
    }

    /// Paint a glyph string starting at `col`. ``Border`` documents every
    /// field as a single terminal column; a multi-character custom glyph is
    /// written left-to-right and its display width advances the column.
    private func paint(
        _ glyph: String,
        col: Int,
        row: Int,
        into buffer: inout CellBuffer
    ) {
        var currentCol = col
        for character in glyph {
            let width = displayWidth(of: character)
            guard width > 0 else { continue }
            buffer.set(
                col: currentCol,
                row: row,
                Cell(character: character, width: Int8(width))
            )
            currentCol += width
        }
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
    /// - Parameter style: The ``Border`` character set to use.
    /// - Returns: A ``BorderView`` wrapping this view.
    public func bordered(_ style: Border = .normal) -> BorderView<Self> {
        BorderView(style) { self }
    }
}
