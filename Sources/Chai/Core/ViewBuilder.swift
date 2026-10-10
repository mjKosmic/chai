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

    // MARK: - Limited availability

    /// Support `#available` checks.
    public static func buildLimitedAvailability<V: View>(_ component: V) -> V {
        component
    }
}
