import Chai

// MARK: - Flexible leftover distribution (A2)
//
// Phase-3 A2 (UPGRADE.md): a stack whose main axis has at least one
// positively-flexible child FILLS a non-`nil` main-axis proposal and splits
// the leftover between the flexible children proportionally. When no child is
// flexible this helper returns `nil` and the caller keeps its pre-A2 code path
// byte-for-byte.
//
// Fit and render both recompute the distribution from the same proposal; the
// A0 fit/render value-equality contract guarantees the render proposal equals
// the fit proposal, so placement is identical across passes by construction.

/// The stack's main-axis size and its children's final main-axis sizes, after
/// distributing leftover space to flexible children.
///
/// - Parameters:
///   - rigidSizes: Each child's rigidly-measured main-axis size.
///   - fractions: Each child's main-axis flexibility fraction (`nil`,
///     non-positive, or non-finite means rigid).
///   - proposal: The stack's main-axis proposal (`nil` = ideal).
/// - Returns: `nil` when no child is positively flexible (the caller uses its
///   rigid path); otherwise the stack's main-axis size and the children's
///   final main-axis sizes.
private func distributedMainAxis(
    rigidSizes: [Int],
    fractions: [Double?],
    proposal: Int?
) -> (stackSize: Int, childSizes: [Int])? {
    // `_flexibility()` is public SPI, so a fraction can be anything a custom
    // conformer returns: normalize a `nil`/non-positive/non-finite fraction to
    // rigid rather than letting `NaN` reach `Int(_:)` (which would trap).
    let shares = fractions.map { fraction -> Double in
        guard let fraction, fraction > 0, fraction.isFinite else { return 0 }
        return fraction
    }
    let totalFlex = shares.reduce(0, +)
    guard totalFlex > 0 else { return nil }

    let rigidTotal = rigidSizes.reduce(0, +)
    // A flexing stack fills a non-nil proposal; with no offer it is
    // content-sized (the flexible children stay at their rigid size).
    let stackSize = proposal ?? rigidTotal
    let leftover = max(0, stackSize - rigidTotal)
    let childSizes = zip(rigidSizes, shares).map { rigid, share -> Int in
        guard share > 0 else { return rigid }
        // Normalized share, `Int()`-truncated: the division remainder is left
        // unallocated at the trailing end of the stack. `share / totalFlex`
        // is at most 1, so the product never exceeds `leftover`.
        return rigid + Int(Double(leftover) * (share / totalFlex))
    }
    return (stackSize, childSizes)
}

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
// Proposal semantics are identical between the fit and render passes: the
// render pass carries the incoming proposal (A0) and proposes the stack's
// width with height ideal to every child, exactly as the fit pass did — so a
// child measures the same in both passes even when its assigned size differs
// from the proposed width. This consistency is a hard requirement: M4's
// `frame()` renders a stack at an assigned size wider than its ideal and
// relies on the child measuring identically in both passes.

extension VStack {
    /// Measure each child with the stack's proposal width (height ideal) and
    /// size to (max child width, Σ child heights).
    ///
    /// When a child is flexible on the main (vertical) axis, the stack fills a
    /// non-`nil` height proposal and splits the leftover between the flexible
    /// children (phase-3 A2; see `distributedMainAxis`). With no flexible
    /// child the measurement is unchanged: children's rigid heights sum to the
    /// stack's height.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let children = content._childViews()
        let childProposal = ProposedSize(width: proposal.width, height: nil)
        let sizes = children.map { $0._sizeThatFits(childProposal) }
        let width = sizes.map(\.width).max() ?? 0
        guard let distributed = distributedMainAxis(
            rigidSizes: sizes.map(\.height),
            fractions: children.map { $0._flexibility().height },
            proposal: proposal.height
        ) else {
            return ViewSize(width: width, height: sizes.reduce(0) { $0 + $1.height })
        }
        return ViewSize(width: width, height: distributed.stackSize)
    }

    /// Place each child at the alignment fraction of the horizontal shortage —
    /// mirroring `aligned(toWidth:_:)`'s `leftPad = Int(shortage * fraction)`
    /// formula and `max(0, ...)` guard — then advance the row by the child's
    /// height. Empty children measure 0×0 and advance nothing, carrying the
    /// eager skip-empty semantics.
    ///
    /// Each child is re-measured and rendered with the same proposal the fit
    /// pass used — `ProposedSize(width: proposal.width, height: nil)` — so a
    /// proposal-consuming child measures identically in both passes even when
    /// the assigned `size.width` differs from the incoming proposal width (the
    /// renderer-root case). The assigned `size` still drives placement:
    /// shortage is computed against `size.width`, not the proposal.
    ///
    /// A flexible child is rendered at its FINAL height (rigid + its share of
    /// the leftover) and the row advances by that final height, so the
    /// distribution is identical to the fit pass.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        var row = origin.row
        let childProposal = ProposedSize(width: proposal.width, height: nil)
        let children = content._childViews()
        let sizes = children.map { $0._sizeThatFits(childProposal) }
        let heights = distributedMainAxis(
            rigidSizes: sizes.map(\.height),
            fractions: children.map { $0._flexibility().height },
            proposal: proposal.height
        )?.childSizes ?? sizes.map(\.height)
        for index in children.indices {
            let childSize = ViewSize(width: sizes[index].width, height: heights[index])
            let shortage = max(0, size.width - childSize.width)
            let col = origin.col + Int(Double(shortage) * alignment.fraction)
            children[index]._render(into: &buffer, at: ViewOrigin(col: col, row: row), size: childSize, proposal: childProposal)
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
    ///
    /// When a child is flexible on the main (horizontal) axis, the stack fills
    /// a non-`nil` width proposal and splits the leftover between the flexible
    /// children (phase-3 A2; see `distributedMainAxis`). With no flexible
    /// child the measurement is unchanged.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let children = content._childViews()
        let childProposal = ProposedSize(width: nil, height: proposal.height)
        let sizes = children.map { $0._sizeThatFits(childProposal) }
        let height = sizes.map(\.height).max() ?? 0
        guard let distributed = distributedMainAxis(
            rigidSizes: sizes.map(\.width),
            fractions: children.map { $0._flexibility().width },
            proposal: proposal.width
        ) else {
            return ViewSize(width: sizes.reduce(0) { $0 + $1.width }, height: height)
        }
        return ViewSize(width: distributed.stackSize, height: height)
    }

    /// Place each child at the alignment fraction of the vertical shortage —
    /// mirroring `extendLines`' `topPad = Int(shortage * fraction)` formula —
    /// then advance the column by the child's width.
    ///
    /// Each child is re-measured and rendered with the same proposal the fit
    /// pass used — `ProposedSize(width: nil, height: proposal.height)`.
    ///
    /// A flexible child is rendered at its FINAL width (rigid + its share of
    /// the leftover) and the column advances by that final width, so the
    /// distribution is identical to the fit pass.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        var col = origin.col
        let childProposal = ProposedSize(width: nil, height: proposal.height)
        let children = content._childViews()
        let sizes = children.map { $0._sizeThatFits(childProposal) }
        let widths = distributedMainAxis(
            rigidSizes: sizes.map(\.width),
            fractions: children.map { $0._flexibility().width },
            proposal: proposal.width
        )?.childSizes ?? sizes.map(\.width)
        for index in children.indices {
            let childSize = ViewSize(width: widths[index], height: sizes[index].height)
            let shortage = max(0, size.height - childSize.height)
            let row = origin.row + Int(Double(shortage) * alignment.fraction)
            children[index]._render(into: &buffer, at: ViewOrigin(col: col, row: row), size: childSize, proposal: childProposal)
            col += childSize.width
        }
    }
}
