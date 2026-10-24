// MARK: - AnyView

/// A type-erased view.
///
/// Use `AnyView` when a child's concrete type is not known statically — for
/// example a `for` loop over a heterogeneous `[any View]`, or a stored
/// property that holds one of several view types.
///
/// ```swift
/// let rows: [any View] = [Text("a"), Text("bb"), ViewOutput("ccc")]
/// VStack {
///     for row in rows {
///         row
///     }
/// }
/// ```
///
/// ## Transparent to the layout engine
///
/// `AnyView` forwards **all four** engine SPI methods to the erased view:
///
/// - ``View/_measure(in:)`` and ``View/_embed(into:at:)`` — erasure never
///   changes measurement or painting.
/// - ``View/_childViews()`` — an erased structural view stays *transparent*:
///   `AnyView(TupleView(...))` inside an `HStack` still exposes its individual
///   children, so they lay out as columns rather than one opaque block.
/// - ``View/_flexibility()`` — an erased flexible ``Spacer()`` still absorbs a
///   stack's leftover space. Dropping this forwarding is the silent-failure
///   case flagged in the PR #21 review: the wrapper would be rigid, the stack
///   would not fill, and nothing would crash.
public struct AnyView: View {
    private let base: any View

    /// Wrap any view.
    ///
    /// - Parameter view: The view to erase. An existing `AnyView` is simply
    ///   erased again (forwarding stays one hop deep per wrapper).
    public init(_ view: any View) {
        self.base = view
    }

    /// Forward the erased view's measurement.
    public func _measure(in available: AvailableSize) -> ViewSize {
        base._measure(in: available)
    }

    /// Forward the erased view's allocation walk.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        base._embed(into: &buffer, at: rect)
    }

    /// Forward the erased view's children so structural views stay
    /// transparent to containers.
    public func _childViews() -> [any View] {
        base._childViews()
    }

    /// Forward the erased view's flexibility so it still participates in a
    /// stack's leftover distribution.
    public func _flexibility() -> LayoutFlexibility {
        base._flexibility()
    }
}
