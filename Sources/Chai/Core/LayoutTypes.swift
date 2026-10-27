// MARK: - Layout value types

/// The layout query context passed to a view during measurement.
///
/// The query is **context, not a bound**: it tells the view what size the
/// parent is asking about on each axis, and the view reports the size it
/// wants — smaller than, equal to, or **larger than** the query. A `nil`
/// dimension means **ideal**: no context on that axis, so report your natural
/// size.
///
/// Overruling a report is normal and intentional: clamping the answer would
/// destroy information the parent needs (a scroll viewport must know its
/// content extends past the visible area even though the visible area is all
/// it can show). Enforcement happens downstream — the parent's allocation (the
/// rect in ``View/_embed(into:at:)``) and, finally, the ``CellBuffer`` bounds.
/// See ARCHITECTURE.md, "Query and allocation semantics".
///
/// ```swift
/// // Ask a view for its ideal size.
/// let ideal = text._measure(in: .unconstrained)
///
/// // Ask a view how it reports at a 20-column query context.
/// let size = text._measure(in: AvailableSize(width: 20, height: nil))
/// ```
public struct AvailableSize: Sendable, Equatable {

    /// The queried width, or `nil` for the view's ideal width.
    public var width: Int?

    /// The queried height, or `nil` for the view's ideal height.
    public var height: Int?

    /// Create a layout query context.
    ///
    /// - Parameters:
    ///   - width: The queried width, or `nil` to leave it at the view's
    ///     ideal width.
    ///   - height: The queried height, or `nil` to leave it at the view's
    ///     ideal height.
    public init(width: Int? = nil, height: Int? = nil) {
        self.width = width
        self.height = height
    }

    /// A query with no context on either axis: both dimensions are ideal.
    public static let unconstrained = AvailableSize(width: nil, height: nil)

    /// A zero query: report your **minimum** size.
    ///
    /// SwiftUI's `ProposedViewSize` has three special cases —
    /// `unspecified` (ideal), `zero` (minimum), and `infinity` (maximum).
    /// Chai has the first two, spelled ``unconstrained`` (ideal) and
    /// `.zero` (minimum); the third is deliberately absent (see
    /// ARCHITECTURE.md, "Why there is no `.infinity`").
    ///
    /// `.zero` is the context a container uses to ask for a child's
    /// *narrowest producible* form. Most views answer their minimum **by
    /// construction** — a ``ViewOutput`` is a fully-formed raster and reports
    /// its ideal size regardless (it may legitimately exceed the zero
    /// context: a report is never clamped), ``Spacer`` answers its rigid size,
    /// flexible ``Spacer()``/``Empty`` answer 0×0, and ``Fill`` answers
    /// `(0, 0)` because a zero query is `(available.width ?? 0,
    /// available.height ?? 0)`. ``Text`` is the one *compressible* view: at a
    /// zero (or negative) width query it wraps to its minimum width.
    ///
    /// ```swift
    /// // Ask a view for its minimum size.
    /// let minimum = text._measure(in: .zero)
    /// ```
    public static let zero = AvailableSize(width: 0, height: 0)
}

/// A concrete size measured for a view, in display columns and rows.
public struct ViewSize: Sendable, Equatable {

    /// Width in display columns.
    public var width: Int

    /// Height in rows.
    public var height: Int

    /// Create a size.
    ///
    /// - Parameters:
    ///   - width: Width in display columns.
    ///   - height: Height in rows.
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    /// A size with zero width and zero height (an empty view).
    public static let zero = ViewSize(width: 0, height: 0)
}

/// How much leftover main-axis space a view absorbs inside a stack.
///
/// A `nil` fraction on an axis means the view is **rigid** on that axis: it
/// takes exactly the size it measures and never absorbs leftover space. A
/// positive fraction means the view is **flexible** on that axis and shares
/// the stack's leftover space proportionally with the other flexible
/// siblings (see ``View/_flexibility()``).
///
/// A stack lays out along one main axis, so it consults only that axis's
/// fraction: ``HStack`` reads ``width``, ``VStack`` reads ``height``. The
/// other axis is the stack's cross axis, where the fraction is ignored.
///
/// ```swift
/// // Rigid on both axes (the default for every view).
/// let rigid = LayoutFlexibility.rigid
///
/// // Absorbs leftover space on both axes; an enclosing stack uses the one
/// // it lays out along.
/// let flexible = LayoutFlexibility(width: 1, height: 1)
/// ```
public struct LayoutFlexibility: Sendable, Equatable {

    /// The fraction of leftover horizontal space this view absorbs, or `nil`
    /// when it is rigid horizontally.
    public var width: Double?

    /// The fraction of leftover vertical space this view absorbs, or `nil`
    /// when it is rigid vertically.
    public var height: Double?

    /// Create a flexibility value.
    ///
    /// - Parameters:
    ///   - width: The horizontal share, or `nil` for rigid.
    ///   - height: The vertical share, or `nil` for rigid.
    public init(width: Double? = nil, height: Double? = nil) {
        self.width = width
        self.height = height
    }

    /// Rigid on both axes — the view absorbs no leftover space.
    public static let rigid = LayoutFlexibility(width: nil, height: nil)
}

/// A rect within a ``CellBuffer``: an origin plus a size.
///
/// This is the phase-4 **assignment** — the value a container hands a child
/// in ``View/_embed(into:at:)``. Under the hard-box contract it is both the
/// layout box and the painting bound: the kernel clips every write in the
/// child's subtree to it, and containers clamp child rects to their own
/// allocation. See `docs/history/VIEW-LAYER-MIGRATION-LOG.md`, "Phase 5 — Hard-box containment".
public struct ViewRect: Sendable, Equatable {

    /// The top-left corner of the rect.
    public var origin: ViewOrigin

    /// The rect's size in display columns and rows.
    public var size: ViewSize

    /// Create a rect.
    ///
    /// - Parameters:
    ///   - origin: The top-left corner.
    ///   - size: The size in display columns and rows.
    public init(origin: ViewOrigin = .zero, size: ViewSize) {
        self.origin = origin
        self.size = size
    }

    /// A zero-origin, zero-size rect.
    public static let zero = ViewRect(origin: .zero, size: .zero)

    /// The overlap of this rect with `other`.
    ///
    /// Returns a zero-sized rect when the two do not overlap. This is the
    /// clamping primitive of the hard-box contract: a container intersects
    /// each child rect with its own before handing it down.
    public func intersection(_ other: ViewRect) -> ViewRect {
        let col = max(origin.col, other.origin.col)
        let row = max(origin.row, other.origin.row)
        let right = min(origin.col + size.width, other.origin.col + other.size.width)
        let bottom = min(origin.row + size.height, other.origin.row + other.size.height)
        return ViewRect(
            origin: ViewOrigin(col: col, row: row),
            size: ViewSize(width: max(0, right - col), height: max(0, bottom - row))
        )
    }

    /// Whether this rect has no area.
    public var isEmpty: Bool {
        size.width <= 0 || size.height <= 0
    }
}

/// A position within a ``CellBuffer``, in display columns and rows.
public struct ViewOrigin: Sendable, Equatable {

    /// Column position (0-based, left edge).
    public var col: Int

    /// Row position (0-based, top edge).
    public var row: Int

    /// Create an origin.
    ///
    /// - Parameters:
    ///   - col: Column position.
    ///   - row: Row position.
    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }

    /// The top-left corner of a buffer.
    public static let zero = ViewOrigin(col: 0, row: 0)
}