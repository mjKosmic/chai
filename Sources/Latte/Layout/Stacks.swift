import Chai

// MARK: - VStack

/// A container that stacks its children vertically.
///
/// Children are joined top-to-bottom, aligned horizontally according to the
/// `alignment` parameter.
///
/// ```swift
/// VStack(alignment: .center) {
///     Text("Title").bold()
///     Text("Subtitle").dim()
/// }
/// ```
public struct VStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let content: Content

    /// Create a vertical stack with the given alignment and content.
    ///
    /// - Parameters:
    ///   - alignment: How children are aligned horizontally when they have
    ///     different widths. Defaults to `.left`.
    ///   - content: A ``ViewBuilder`` closure that provides the children.
    public init(
        alignment: HorizontalAlignment = .left,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: ViewOutput {
        // A `ViewBuilder` closure's default join is vertical, so the
        // content's resolved output is already the children stacked
        // top-to-bottom.
        let joined = content._resolveToViewOutput()

        guard alignment != .left else { return joined }

        let lines = joined.content.splitLines()
        let maxWidth = lines.map(\.columnWidth).max() ?? 0
        let aligned = lines.map { $0.aligned(toWidth: maxWidth, alignment) }
        return ViewOutput(StyledText.fromLines(aligned))
    }
}

// MARK: - HStack

/// A container that stacks its children horizontally.
///
/// Children are joined left-to-right, aligned vertically according to the
/// `alignment` parameter.
///
/// ```swift
/// HStack(alignment: .bottom) {
///     Text("Left")
///     mainContent
/// }
/// ```
public struct HStack<Content: View>: View {
    let alignment: VerticalAlignment
    let content: Content

    /// Create a horizontal stack with the given alignment and content.
    ///
    /// - Parameters:
    ///   - alignment: How children are aligned vertically when they have
    ///     different heights. Defaults to `.top`.
    ///   - content: A ``ViewBuilder`` closure that provides the children.
    public init(
        alignment: VerticalAlignment = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: ViewOutput {
        let parts = content._childViews().map { $0._resolveToViewOutput() }
        return Self.joinHorizontally(parts, align: alignment)
    }

    private static func joinHorizontally(_ components: [ViewOutput], align: VerticalAlignment) -> ViewOutput {
        guard !components.isEmpty else { return ViewOutput("") }
        guard components.count > 1 else { return components[0] }

        var result = components[0].content
        for component in components.dropFirst() {
            if !component.content.isEmpty {
                result = result.beside(component.content, align: align)
            }
        }
        return ViewOutput(result)
    }
}

// MARK: - VStack engine implementation
//
// Phase-2 layout engine (UPGRADE.md): the container renders children instead
// of joining their resolved outputs. Parity with the eager `body` above is
// verified by the corpus in Tests/LatteTests/LayoutParity.
//
// Proposal semantics are identical between the fit and render passes — both
// propose the stack's width and leave height ideal — so a child measures the
// same in both passes. This consistency is a hard requirement: M4's `frame()`
// will render a stack at an assigned size wider than its ideal and relies on
// the child measuring identically in both passes.

extension VStack {
    /// Measure each child with the stack's proposal width (height ideal) and
    /// size to (max child width, Σ child heights).
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let sizes = content._childViews().map {
            $0._sizeThatFits(ProposedSize(width: proposal.width, height: nil))
        }
        return ViewSize(
            width: sizes.map(\.width).max() ?? 0,
            height: sizes.reduce(0) { $0 + $1.height }
        )
    }

    /// Place each child at the alignment fraction of the horizontal shortage —
    /// mirroring `aligned(toWidth:_:)`'s `leftPad = Int(shortage * fraction)`
    /// formula and `max(0, ...)` guard — then advance the row by the child's
    /// height. Empty children measure 0×0 and advance nothing, carrying the
    /// eager skip-empty semantics.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize) {
        var row = origin.row
        for child in content._childViews() {
            let childSize = child._sizeThatFits(ProposedSize(width: size.width, height: nil))
            let shortage = max(0, size.width - childSize.width)
            let col = origin.col + Int(Double(shortage) * alignment.fraction)
            child._render(into: &buffer, at: ViewOrigin(col: col, row: row), size: childSize)
            row += childSize.height
        }
    }
}

// MARK: - HStack engine implementation

extension HStack {
    /// Measure each child with the stack's proposal height (width ideal) and
    /// size to (Σ child widths, max child height). Each column keeps its own
    /// measured width — this reproduces `beside()`'s per-column (not shared)
    /// width normalization naturally.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let sizes = content._childViews().map {
            $0._sizeThatFits(ProposedSize(width: nil, height: proposal.height))
        }
        return ViewSize(
            width: sizes.reduce(0) { $0 + $1.width },
            height: sizes.map(\.height).max() ?? 0
        )
    }

    /// Place each child at the alignment fraction of the vertical shortage —
    /// mirroring `extendLines`' `topPad = Int(shortage * fraction)` formula —
    /// then advance the column by the child's width.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize) {
        var col = origin.col
        for child in content._childViews() {
            let childSize = child._sizeThatFits(ProposedSize(width: nil, height: size.height))
            let shortage = max(0, size.height - childSize.height)
            let row = origin.row + Int(Double(shortage) * alignment.fraction)
            child._render(into: &buffer, at: ViewOrigin(col: col, row: row), size: childSize)
            col += childSize.width
        }
    }
}
