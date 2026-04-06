import Chai

// MARK: - HStackBuilder

/// A result builder that composes multiple ``View`` values into a single
/// ``ViewOutput`` by placing them side by side horizontally.
///
/// This builder is used internally by ``HStack``. It has the same expression
/// and control-flow support as ``ViewBuilder`` but joins children with
/// horizontal composition instead of vertical stacking.
@resultBuilder
public struct HStackBuilder {

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

    /// Combine multiple components by placing them side by side.
    public static func buildBlock(_ components: ViewOutput...) -> ViewOutput {
        joinHorizontally(components, align: .top)
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
        joinHorizontally(components, align: .top)
    }

    // MARK: - Limited availability

    /// Support `#available` checks.
    public static func buildLimitedAvailability(_ component: ViewOutput) -> ViewOutput {
        component
    }

    // MARK: - Join strategy

    static func joinHorizontally(_ components: [ViewOutput], align: VerticalAlignment) -> ViewOutput {
        guard !components.isEmpty else { return ViewOutput("") }
        guard components.count > 1 else { return components[0] }

        var result = components[0].content
        for component in components.dropFirst() {
            if !component.content.isEmpty {
                result = result.beside(component.content, align: align)
            }
        }
        return ViewOutput(result)
    }
}
