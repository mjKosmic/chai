// MARK: - Layout value types

/// A size proposal passed to a view during layout measurement.
///
/// A proposal is an **offer, not a bound**: it tells the view what the
/// parent is offering on each axis, and the view answers with the size it
/// wants. The answer is never clamped — a view may return a size smaller
/// than, equal to, or **larger than** the offer. A `nil` dimension means
/// **ideal**: no offer was made on that axis, so report your natural size.
///
/// Overruling an offer is normal and intentional: clamping the answer
/// would destroy information the parent needs (a scroll viewport must know
/// its content extends past the visible area even though the visible area
/// is all it can show). Enforcement happens downstream — the parent's
/// placement decision (the rect in ``View/_embed(into:at:)``)
/// and, finally, the ``CellBuffer`` bounds. See ARCHITECTURE.md
/// "An offer, not a box".
///
/// ```swift
/// // Ask a view for its ideal size.
/// let ideal = text._sizeThatFits(.unspecified)
///
/// // Ask a view how wide it wants to be when offered 20 columns.
/// let size = text._sizeThatFits(ProposedSize(width: 20, height: nil))
/// ```
public struct ProposedSize: Sendable, Equatable {

    /// The proposed width, or `nil` for the view's ideal width.
    public var width: Int?

    /// The proposed height, or `nil` for the view's ideal height.
    public var height: Int?

    /// Create a size proposal.
    ///
    /// - Parameters:
    ///   - width: The offered width, or `nil` to leave it at the view's
    ///     ideal width.
    ///   - height: The offered height, or `nil` to leave it at the view's
    ///     ideal height.
    public init(width: Int? = nil, height: Int? = nil) {
        self.width = width
        self.height = height
    }

    /// A proposal that offers nothing on either axis: both dimensions are
    /// ideal.
    public static let unspecified = ProposedSize(width: nil, height: nil)

    /// A zero offer: report your **minimum** size.
    ///
    /// SwiftUI's `ProposedViewSize` has three special cases — `unspecified`
    /// (ideal), `zero` (minimum), and `infinity` (maximum). Chai has the first
    /// two; the third is deliberately absent (see ARCHITECTURE.md, "Why there
    /// is no `.infinity`").
    ///
    /// `.zero` is the offer a container makes when it wants a child's
    /// *narrowest producible* form. Most views answer their minimum **by
    /// construction** — a ``ViewOutput`` is a fully-formed raster and answers
    /// its ideal size regardless (it may legitimately exceed the zero offer:
    /// the answer is never clamped), ``Spacer`` answers its rigid size,
    /// ``FlexibleSpacer``/``Empty`` answer 0×0, and ``Fill`` answers
    /// `(0, 0)` because a zero offer is `(proposal.width ?? 0,
    /// proposal.height ?? 0)`. ``Text`` is the one *compressible* view: at a
    /// zero (or negative) width proposal it wraps to its minimum width.
    ///
    /// ```swift
    /// // Ask a view for its minimum size.
    /// let minimum = text._sizeThatFits(.zero)
    /// ```
    public static let zero = ProposedSize(width: 0, height: 0)
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
/// in ``View/_embed(into:at:)``. It is a bound, unlike ``ProposedSize``: the
/// child renders inside the rect it was given (and may overflow it visually;
/// the buffer remains the only hard wall). See `UPGRADE.md`, "Phase 4 —
/// Top-down allocation engine".
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