// MARK: - Structural views

/// Join view outputs top-to-bottom, skipping empty components.
///
/// This is the default join strategy for ``ViewBuilder`` composition: it
/// matches the legacy eager ``ViewBuilder`` behavior where a bare
/// `@ViewBuilder` closure stacks its children vertically.
func joinVertically(_ components: [ViewOutput]) -> ViewOutput {
    guard !components.isEmpty else { return ViewOutput("") }
    guard components.count > 1 else { return components[0] }

    var result = components[0].content
    for component in components.dropFirst() {
        if !component.content.isEmpty {
            if !result.isEmpty {
                result.append("\n")
            }
            result += component.content
        }
    }
    return ViewOutput(result)
}

/// Embed `children` top-to-bottom into `rect`.
///
/// This is the **allocation** analogue of ``joinVertically(_:)`` for structural
/// views that are rendered directly (as a root view or under a wrapper) rather
/// than flattened by a container. Each child is queried at the rect's width and
/// the row advances by its reported height, so empty children advance nothing
/// (the phase-1 skip-empty semantics). Structural views inside a container are
/// flattened by ``View/_childViews()`` and never reach this function.
func embedStackedVertically(_ children: [any View], into buffer: inout CellBuffer, at rect: ViewRect) {
    var row = rect.origin.row
    for child in children {
        let size = child._sizeThatFits(ProposedSize(width: rect.size.width, height: nil))
        child._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: rect.origin.col, row: row), size: size)
        )
        row += size.height
    }
}

// MARK: - TupleView

/// A structural view that groups multiple children produced by ``ViewBuilder``.
///
/// You don't create `TupleView` directly — it's produced automatically when
/// a ``ViewBuilder`` closure contains multiple expressions.
///
/// The default ``body`` stacks children vertically (matching the legacy
/// ``ViewBuilder`` behavior). Container views like `HStack` enumerate the
/// children directly via ``_childViews()`` to apply their own layout
/// strategy. Each child's own collected views are flattened into the
/// tuple's children, so structural views (``ForEachView``, nested
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

    public var body: ViewOutput {
        joinVertically(_childViews().map { $0._resolveToViewOutput() })
    }

    /// Allocation entrance when the tuple is rendered directly (as a root or
    /// under a wrapper): children stack vertically, matching ``body``.
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

    public var body: ViewOutput {
        switch storage {
        case .first(let content):
            content._resolveToViewOutput()
        case .second(let content):
            content._resolveToViewOutput()
        }
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

    /// Allocation entrance: the active branch's children stack vertically,
    /// matching ``body``.
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

    public var body: ViewOutput {
        content?._resolveToViewOutput() ?? ViewOutput("")
    }

    /// The wrapped content's children when present, none when `nil`.
    public func _childViews() -> [any View] {
        content?._childViews() ?? []
    }

    /// Allocation entrance: the present content's children stack vertically,
    /// matching ``body``. An absent branch embeds nothing.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        embedStackedVertically(_childViews(), into: &buffer, at: rect)
    }
}

// MARK: - ForEachView

/// A structural view produced by `for...in` loops in a ``ViewBuilder``.
///
/// The default ``body`` stacks children vertically. Like ``TupleView``,
/// it is transparent to containers: ``_childViews()`` returns one view per
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

    public var body: ViewOutput {
        joinVertically(_childViews().map { $0._resolveToViewOutput() })
    }

    /// Allocation entrance when the loop is rendered directly: children stack
    /// vertically, matching ``body``.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        embedStackedVertically(_childViews(), into: &buffer, at: rect)
    }
}
