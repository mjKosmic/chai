import Chai

// MARK: - Flexible leftover distribution (A2, re-roled in phase 4)
//
// Phase-3 A2 (UPGRADE.md): a stack whose main axis has at least one
// positively-flexible child FILLS a non-`nil` main-axis assignment and splits
// the leftover between the flexible children proportionally. When no child is
// flexible this helper returns `nil` and the caller keeps its pre-A2 code path
// byte-for-byte.
//
// Phase 4 (top-down allocation) keeps this math but changes its role: the
// "assignment" is the stack's assigned rect dimension when allocating
// (`_embed`) and the query context when reporting (`_measure(in:)`). The
// shares are container-internal decisions, not a leftover smuggled through
// negotiation. The formula is byte-equal to A2's: normalized shares, `Int()`
// truncation, remainder left unallocated at the trailing end.

/// The stack's main-axis size and its children's final main-axis sizes, after
/// distributing leftover space to flexible children.
///
/// - Parameters:
///   - rigidSizes: Each child's rigidly-measured main-axis size.
///   - fractions: Each child's main-axis flexibility fraction (`nil`,
///     non-positive, or non-finite means rigid).
///   - assigned: The stack's assigned main-axis size (`nil` = content-sized).
///     For `_measure` this is the query context; for `_embed` it is the
///     assigned rect dimension.
/// - Returns: `nil` when no child is positively flexible (the caller uses its
///   rigid path); otherwise the stack's main-axis size and the children's
///   final main-axis sizes.
private func distributedMainAxis(
    rigidSizes: [Int],
    fractions: [Double?],
    assigned: Int?
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
    // A flexing stack fills a non-nil assignment; with no assignment it is
    // content-sized (the flexible children stay at their rigid size). It
    // never reports BELOW its rigid content — a 0-wide spacer must not hide
    // overflow from the parent — and a negative or zero assignment floors at
    // the rigid total (which is >= 0).
    let stackSize = max(assigned ?? rigidTotal, rigidTotal)
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

// MARK: - Shared allocation shape
//
// Phase 4 (top-down allocation): a stack computes ONE shape — the occupied
// size plus every child's allocated size — and both the query kernel
// (`_measure`, used for reservation and buffer sizing) and the allocation
// walk (`_embed`) resolve through it. The two can never disagree about sizes;
// only placement differs (cursor advancement + alignment anchoring).

/// A stack's occupied size and its children's allocated sizes.
private struct StackAllocation {
    /// The size the stack occupies in its assigned rect (shrink-wrap on the
    /// cross axis; the main axis follows the assignment when flexing/absorbing).
    var occupied: ViewSize
    /// Each child's allocated size, in child order.
    var childSizes: [ViewSize]
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
}

// MARK: - VStack engine implementation
//
// Phase 4: the stack computes one shape (query + allocation), allocates each
// child a rect, and embeds it. `_measure` is the pure query kernel
// (report only — used for buffer sizing and clip reservation). The corpus in
// Tests/LatteTests/LayoutParity is the mechanical spec.

extension VStack {
    /// The stack's allocation shape under an assigned width/height context.
    ///
    /// Cross axis (width): every child is *queried* at the assigned width
    /// (`(width, nil)`) — a query, never an offer. The reported width becomes
    /// the child's rect width; the occupied width is the maximum report
    /// (shrink-wrap — phase-4 decision 1), so a `Fill` child naturally claims
    /// the assigned width via its own report.
    ///
    /// Main axis (height): each report is an allocated row height. A row never
    /// exceeds the stack's remaining allocation — the hard-box contract
    /// clips the last row rather than letting it paint outside. When a child is
    /// flexible on the height axis and the assigned height exceeds the rigid
    /// total, the leftover is distributed by ``distributedMainAxis``.
    private func allocation(assignedWidth: Int?, assignedHeight: Int?) -> StackAllocation {
        let children = content._childViews()
        let childProposal = AvailableSize(width: assignedWidth, height: nil)
        let reports = children.map { $0._measure(in: childProposal) }
        let distributed = distributedMainAxis(
            rigidSizes: reports.map(\.height),
            fractions: children.map { $0._flexibility().height },
            assigned: assignedHeight
        )
        let heights = distributed?.childSizes ?? reports.map(\.height)
        let occupied = ViewSize(
            width: reports.map(\.width).max() ?? 0,
            height: distributed?.stackSize ?? reports.map(\.height).reduce(0, +)
        )
        return StackAllocation(
            occupied: occupied,
            childSizes: zip(reports.map(\.width), heights).map { ViewSize(width: $0, height: $1) }
        )
    }

    /// Report the occupied size under the query context (the pure sizing
    /// pass — used for reservation and buffer sizing, never binding).
    public func _measure(in available: AvailableSize) -> ViewSize {
        allocation(assignedWidth: available.width, assignedHeight: available.height).occupied
    }

    /// Allocate each child a row rect and embed it (phase 4).
    ///
    /// Rows advance by ALLOCATED heights; each child is anchored at the
    /// alignment fraction of the horizontal shortage — the same
    /// `Int(Double(shortage) * fraction)` formula as `aligned(toWidth:_:)`,
    /// measured against the stack's OCCUPIED width (shrink-wrap), not the
    /// assigned rect width. Children whose reports exceed the stack's
    /// allocation are clamped to it and clipped; rows advance by the
    /// allocated height, so nothing paints outside the stack.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let shape = allocation(assignedWidth: rect.size.width, assignedHeight: rect.size.height)
        let children = content._childViews()
        // Alignment is measured against the visible box: when the stack's
        // content is larger than its allocation, the overflow is clipped, not
        // used to push children outside the rect.
        let visibleWidth = min(shape.occupied.width, rect.size.width)
        let bottom = rect.origin.row + rect.size.height
        var row = rect.origin.row

        for index in children.indices {
            guard row < bottom else { break }
            let remaining = bottom - row
            let reported = shape.childSizes[index]
            let width = min(reported.width, rect.size.width)
            let height = min(reported.height, remaining)
            guard height > 0 else { continue }

            let shortage = max(0, visibleWidth - width)
            let col = rect.origin.col + Int(Double(shortage) * alignment.fraction)
            let childRect = ViewRect(
                origin: ViewOrigin(col: col, row: row),
                size: ViewSize(width: width, height: height)
            ).intersection(rect)

            if !childRect.isEmpty {
                buffer.embed(children[index], at: childRect)
            }
            row += height
        }
    }
}

// MARK: - HStack engine implementation

extension HStack {
    /// The stack's allocation shape under an assigned width/height context.
    ///
    /// Main axis (width): columns are measured at **ideal** width — the
    /// allocator rule that replaces the phase-3 "HStack never proposes width"
    /// artifact (so a wrapping `Text` is inert inside an HStack). Width-flex
    /// children then absorb the assigned leftover per ``View/_flexibility()``;
    /// `Fill`-by-type columns absorb whatever remains after the flexible
    /// shares (phase-4 decision 2: `Fill` claims its allocated rect, and this
    /// is the container rule that makes a `Fill` under an `HStack`
    /// expressible, which the phase-3 engine could not measure).
    ///
    /// Cross axis (height): each column reports its own height at the height
    /// context; the occupied height is the maximum report. Columns are
    /// anchored by the alignment fraction against the occupied height.
    private func allocation(assignedWidth: Int?, assignedHeight: Int?) -> StackAllocation {
        let children = content._childViews()
        let childProposal = AvailableSize(width: nil, height: assignedHeight)
        let reports = children.map { $0._measure(in: childProposal) }
        let distributed = distributedMainAxis(
            rigidSizes: reports.map(\.width),
            fractions: children.map { $0._flexibility().width },
            assigned: assignedWidth
        )
        var widths = distributed?.childSizes ?? reports.map(\.width)

        // `Fill` columns claim the remaining assigned width, split evenly.
        // This is a container decision (allocation authority), not a child
        // answer: at an ideal-width query `Fill` reports 0, so without this
        // rule it could never fill an HStack. The pins it changes are
        // documented in UPGRADE.md ("Phase 4 — allocation deltas").
        if let assignedWidth, children.contains(where: { $0 is Fill }) {
            let unassigned = max(0, assignedWidth - widths.reduce(0, +))
            let fills = children.filter { $0 is Fill }.count
            let share = fills > 0 ? unassigned / fills : 0
            for index in children.indices where children[index] is Fill {
                widths[index] = share
            }
        }

        let occupied = ViewSize(
            width: distributed?.stackSize ?? widths.reduce(0, +),
            height: reports.map(\.height).max() ?? 0
        )
        return StackAllocation(
            occupied: occupied,
            childSizes: zip(widths, reports.map(\.height)).map { ViewSize(width: $0, height: $1) }
        )
    }

    /// Report the occupied size under the query context (the pure sizing
    /// pass — used for reservation and buffer sizing, never binding).
    public func _measure(in available: AvailableSize) -> ViewSize {
        allocation(assignedWidth: available.width, assignedHeight: available.height).occupied
    }

    /// Allocate each child a column rect and embed it (phase 4).
    ///
    /// Columns advance by ALLOCATED widths; each child is anchored at the
    /// alignment fraction of the vertical shortage against the occupied
    /// height. An unallocated trailing remainder (proportional-share
    /// truncation) stays blank, exactly as pinned by the A2 tests.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let shape = allocation(assignedWidth: rect.size.width, assignedHeight: rect.size.height)
        let children = content._childViews()
        let visibleHeight = min(shape.occupied.height, rect.size.height)
        let right = rect.origin.col + rect.size.width
        var col = rect.origin.col

        for index in children.indices {
            guard col < right else { break }
            let remaining = right - col
            let reported = shape.childSizes[index]
            let width = min(reported.width, remaining)
            guard width > 0 else { continue }
            let height = min(reported.height, rect.size.height)

            let shortage = max(0, visibleHeight - height)
            let row = rect.origin.row + Int(Double(shortage) * alignment.fraction)
            let childRect = ViewRect(
                origin: ViewOrigin(col: col, row: row),
                size: ViewSize(width: width, height: height)
            ).intersection(rect)

            if !childRect.isEmpty {
                buffer.embed(children[index], at: childRect)
            }
            col += width
        }
    }
}
