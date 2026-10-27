// MARK: - Structural views

/// Embed `children` top-to-bottom into `rect`.
///
/// This is the allocation analogue of the vertical join for structural views
/// that are rendered directly (as a root view or under a wrapper) rather than
/// flattened by a container. Each child is queried at the rect's width and the
/// row advances by its reported height, so empty children advance nothing.
/// Structural views inside a container are flattened by ``View/_childViews()``
/// and never reach this function.
func embedStackedVertically(_ children: [any View], into buffer: inout CellBuffer, at rect: ViewRect) {
    var row = rect.origin.row
    let bottom = rect.origin.row + rect.size.height
    for child in children {
        guard row < bottom else { break }
        let remaining = bottom - row
        let size = child._measure(in: AvailableSize(width: rect.size.width, height: nil))
        let childRect = ViewRect(
            origin: ViewOrigin(col: rect.origin.col, row: row),
            size: ViewSize(
                width: min(size.width, rect.size.width),
                height: min(size.height, remaining)
            )
        ).intersection(rect)
        guard childRect.size.height > 0 else { continue }
        if childRect.size.width > 0 {
            buffer.embed(child, at: childRect)
        }
        row += childRect.size.height
    }
}

/// Measure `children` the way ``embedStackedVertically(_:into:at:)`` places
/// them: each child is queried at the available width (height is ideal), the
/// occupied width is the widest report, and the height is the sum of reports.
///
/// Structural views use this as their query kernel when they are measured
/// directly rather than flattened by a container.
func measureStackedVertically(_ children: [any View], available: AvailableSize) -> ViewSize {
    var width = 0
    var height = 0
    for child in children {
        let size = child._measure(in: AvailableSize(width: available.width, height: nil))
        width = max(width, size.width)
        height += size.height
    }
    return ViewSize(width: width, height: height)
}

// MARK: - TupleView

/// A structural view that groups multiple children produced by ``ViewBuilder``.
///
/// You don't create `TupleView` directly — it's produced automatically when
/// a ``ViewBuilder`` closure contains multiple expressions.
///
/// Containers enumerate the children directly via ``_childViews()`` to apply
/// their own layout strategy. Each child's own collected views are flattened
/// into the tuple's children, so structural views (``ForEachView``, nested
/// `TupleView`s) are transparent to containers — a `for` loop inside an
/// `HStack` lays its elements out horizontally, as it does in SwiftUI.
public struct TupleView<each T: View>: View {
    public let children: (repeat each T)

    public init(_ children: repeat each T) {
        self.children = (repeat each children)
    }

    public func _childViews() -> [any View] {
        var parts: [any View] = []
        for child in repeat each children {
            parts.append(contentsOf: child._childViews())
        }
        return parts
    }

    /// Measurement entrance when the tuple is rendered directly (as a root or
    /// under a wrapper): children are queried and stacked vertically.
    public func _measure(in available: AvailableSize) -> ViewSize {
        measureStackedVertically(_childViews(), available: available)
    }

    /// Allocation entrance when the tuple is rendered directly (as a root or
    /// under a wrapper): children stack vertically.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        embedStackedVertically(_childViews(), into: &buffer, at: rect)
    }
}

// MARK: - ConditionalContent

/// A structural view produced by `if/else` branches in a ``ViewBuilder``.
///
/// You don't create this directly — it's produced by ``ViewBuilder``
/// when a closure contains `if/else` control flow. The inactive branch
/// produces no content.
public struct ConditionalContent<TrueContent: View, FalseContent: View>: View {
    enum Storage: Sendable {
        case first(TrueContent)
        case second(FalseContent)
    }

    let storage: Storage

    public static func first(_ content: TrueContent) -> Self {
        Self(storage: .first(content))
    }

    public static func second(_ content: FalseContent) -> Self {
        Self(storage: .second(content))
    }

    /// Only the active branch contributes children. A multi-expression
    /// branch body is itself a ``TupleView``, so flattening the branch keeps
    /// per-child enumeration.
    public func _childViews() -> [any View] {
        switch storage {
        case .first(let content):
            content._childViews()
        case .second(let content):
            content._childViews()
        }
    }

    /// Measurement entrance: the active branch's children are queried and
    /// stacked vertically.
    public func _measure(in available: AvailableSize) -> ViewSize {
        measureStackedVertically(_childViews(), available: available)
    }

    /// Allocation entrance: the active branch's children stack vertically.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        embedStackedVertically(_childViews(), into: &buffer, at: rect)
    }
}

// MARK: - OptionalView

/// A structural view produced by `if` without `else` in a ``ViewBuilder``.
///
/// When the wrapped content is `nil`, produces empty output.
public struct OptionalView<Wrapped: View>: View {
    let content: Wrapped?

    public init(_ content: Wrapped?) {
        self.content = content
    }

    /// The wrapped content's children when present, none when `nil`.
    public func _childViews() -> [any View] {
        content?._childViews() ?? []
    }

    /// Measurement entrance: the present content's children are queried and
    /// stacked vertically. An absent branch reports nothing.
    public func _measure(in available: AvailableSize) -> ViewSize {
        measureStackedVertically(_childViews(), available: available)
    }

    /// Allocation entrance: the present content's children stack vertically.
    /// An absent branch embeds nothing.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        embedStackedVertically(_childViews(), into: &buffer, at: rect)
    }
}

// MARK: - ForEachView

/// A structural view produced by `for...in` loops in a ``ViewBuilder``.
///
/// It is transparent to containers: ``_childViews()`` returns one view per
/// element, so a `for` loop inside an `HStack` lays its elements out
/// horizontally.
public struct ForEachView<Content: View>: View {
    let children: [Content]

    public init(_ children: [Content]) {
        self.children = children
    }

    public func _childViews() -> [any View] {
        var parts: [any View] = []
        for child in children {
            parts.append(contentsOf: child._childViews())
        }
        return parts
    }

    /// Measurement entrance when the loop is rendered directly: children are
    /// queried and stacked vertically.
    public func _measure(in available: AvailableSize) -> ViewSize {
        measureStackedVertically(_childViews(), available: available)
    }

    /// Allocation entrance when the loop is rendered directly: children stack
    /// vertically.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        embedStackedVertically(_childViews(), into: &buffer, at: rect)
    }
}
