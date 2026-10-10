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

// MARK: - TupleView

/// A structural view that groups multiple children produced by ``ViewBuilder``.
///
/// You don't create `TupleView` directly — it's produced automatically when
/// a ``ViewBuilder`` closure contains multiple expressions.
///
/// The default ``body`` stacks children vertically (matching the legacy
/// ``ViewBuilder`` behavior). Container views like `HStack` enumerate the
/// children directly via ``_collectChildOutputs`` to apply their own layout
/// strategy. Each child's own collected outputs are flattened into the
/// tuple's children, so structural views (``ForEachView``, nested
/// `TupleView`s) are transparent to containers — a `for` loop inside an
/// `HStack` lays its elements out horizontally, as it does in SwiftUI.
public struct TupleView<each T: View>: View {
    public let children: (repeat each T)

    public init(_ children: repeat each T) {
        self.children = (repeat each children)
    }

    public func _collectChildOutputs() -> [ViewOutput] {
        var parts: [ViewOutput] = []
        for child in repeat each children {
            parts.append(contentsOf: child._collectChildOutputs())
        }
        return parts
    }

    public var body: ViewOutput {
        joinVertically(_collectChildOutputs())
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
}

// MARK: - ForEachView

/// A structural view produced by `for...in` loops in a ``ViewBuilder``.
///
/// The default ``body`` stacks children vertically. Like ``TupleView``,
/// it is transparent to containers: ``_collectChildOutputs`` returns one
/// output per element, so a `for` loop inside an `HStack` lays its
/// elements out horizontally.
public struct ForEachView<Content: View>: View {
    let children: [Content]

    public init(_ children: [Content]) {
        self.children = children
    }

    public func _collectChildOutputs() -> [ViewOutput] {
        var parts: [ViewOutput] = []
        for child in children {
            parts.append(contentsOf: child._collectChildOutputs())
        }
        return parts
    }

    public var body: ViewOutput {
        joinVertically(_collectChildOutputs())
    }
}
