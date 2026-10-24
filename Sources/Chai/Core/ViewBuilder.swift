// MARK: - ViewBuilder

/// A result builder that composes multiple ``View`` values into a
/// structural view tree.
///
/// Use `@ViewBuilder` on closures or computed properties to enable
/// declarative, multi-expression view composition:
///
/// ```swift
/// @ViewBuilder var body: some View {
///     VStack {
///         Text("Title").bold()
///         list
///         Text("Footer").dim()
///     }
/// }
/// ```
///
/// Supports `if`, `if/else`, `if let`, `switch`, and `for...in`.
@resultBuilder
public struct ViewBuilder {

    // MARK: - Expression

    /// Accept any ``View``-conforming value and pass it through.
    public static func buildExpression<V: View>(_ view: V) -> V {
        view
    }

    /// Accept a ``ViewOutput`` directly.
    ///
    /// This overload also enables string literals and interpolations as
    /// builder expressions — `"Count: \(count)"` builds a ``ViewOutput``
    /// through `ExpressibleByStringInterpolation`.
    public static func buildExpression(_ output: ViewOutput) -> ViewOutput {
        output
    }

    /// Accept a type-erased view directly.
    ///
    /// Existentials do not conform to their own protocol, so `any View`
    /// cannot use the generic overload. Erasing it here makes heterogeneous
    /// runtime-built children expressible — a `for` loop over `[any View]`
    /// works, and each element becomes an ``AnyView``.
    ///
    /// Marked disfavoured so a concrete view keeps the generic overload (and
    /// with it, its concrete type in single-expression builders such as
    /// `PaddingView { self }`).
    @_disfavoredOverload
    public static func buildExpression(_ view: any View) -> AnyView {
        AnyView(view)
    }

    // MARK: - Block

    /// Combine a single component (pass-through).
    public static func buildBlock<V: View>(_ component: V) -> V {
        component
    }

    /// Combine multiple components into a ``TupleView``.
    public static func buildBlock<each V: View>(
        _ views: repeat each V
    ) -> TupleView<repeat each V> {
        TupleView(repeat each views)
    }

    // MARK: - Conditionals

    /// Support `if` without `else`.
    public static func buildOptional<V: View>(_ component: V?) -> OptionalView<V> {
        OptionalView(component)
    }

    /// Support the `if` branch of `if/else`.
    public static func buildEither<T: View, F: View>(
        first component: T
    ) -> ConditionalContent<T, F> {
        .first(component)
    }

    /// Support the `else` branch of `if/else`.
    public static func buildEither<T: View, F: View>(
        second component: F
    ) -> ConditionalContent<T, F> {
        .second(component)
    }

    // MARK: - Loops

    /// Support `for...in` loops.
    public static func buildArray<V: View>(_ components: [V]) -> ForEachView<V> {
        ForEachView(components)
    }

    /// Support `for...in` loops over heterogeneous views.
    ///
    /// The homogeneous overload above stays the default (a concrete `[V]`
    /// keeps its element type, so `ForEachView<V>` remains transparent). This
    /// overload handles `[any View]`, erasing each element and wrapping the
    /// result in an ``AnyView`` (which forwards `_childViews`, so the loop's
    /// elements stay visible to containers).
    @_disfavoredOverload
    public static func buildArray(_ components: [any View]) -> AnyView {
        AnyView(ForEachView(components.map { AnyView($0) }))
    }

    // MARK: - Limited availability

    /// Support `#available` checks.
    public static func buildLimitedAvailability<V: View>(_ component: V) -> V {
        component
    }
}
