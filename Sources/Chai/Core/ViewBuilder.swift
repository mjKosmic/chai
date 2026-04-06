// MARK: - ViewBuilder

/// A result builder that composes multiple ``View`` values into a single
/// ``ViewOutput`` by stacking them vertically.
///
/// Use `@ViewBuilder` on closures or computed properties to enable
/// declarative, multi-expression view composition:
///
/// ```swift
/// var body: ViewOutput {
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

    /// Accept any ``View``-conforming value.
    public static func buildExpression(_ view: any View) -> ViewOutput {
        view.body
    }

    /// Accept a ``ViewOutput`` directly.
    public static func buildExpression(_ output: ViewOutput) -> ViewOutput {
        output
    }

    // MARK: - Block

    /// Combine a single component.
    public static func buildBlock(_ component: ViewOutput) -> ViewOutput {
        component
    }

    /// Combine multiple components by stacking them vertically.
    public static func buildBlock(_ components: ViewOutput...) -> ViewOutput {
        joinVertically(components)
    }

    // MARK: - Conditionals

    /// Support `if` without `else`.
    public static func buildOptional(_ component: ViewOutput?) -> ViewOutput {
        component ?? ViewOutput("")
    }

    /// Support the `if` branch of `if/else`.
    public static func buildEither(first component: ViewOutput) -> ViewOutput {
        component
    }

    /// Support the `else` branch of `if/else`.
    public static func buildEither(second component: ViewOutput) -> ViewOutput {
        component
    }

    // MARK: - Loops

    /// Support `for...in` loops.
    public static func buildArray(_ components: [ViewOutput]) -> ViewOutput {
        joinVertically(components)
    }

    // MARK: - Limited availability

    /// Support `#available` checks.
    public static func buildLimitedAvailability(_ component: ViewOutput) -> ViewOutput {
        component
    }

    // MARK: - Join strategy

    private static func joinVertically(_ components: [ViewOutput]) -> ViewOutput {
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
}
