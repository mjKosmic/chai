// MARK: - Layout value types

/// A size proposal passed to a view during layout measurement.
///
/// The proposal carries the width and height a parent is offering. A `nil`
/// dimension means **ideal**: the view reports the size it would naturally
/// take, without being constrained. A non-`nil` dimension is a firm offer —
/// the view should report the size it would take within that bound.
///
/// ```swift
/// // Ask a view for its ideal size.
/// let ideal = text._sizeThatFits(.unspecified)
///
/// // Ask a view how wide it wants to be within a 20-column constraint.
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

    /// A proposal with no constraints: both dimensions are ideal.
    public static let unspecified = ProposedSize(width: nil, height: nil)
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