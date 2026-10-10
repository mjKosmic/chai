import Chai

// MARK: - VStack

/// A container that stacks its children vertically.
///
/// Children are joined top-to-bottom, aligned horizontally according to the
/// `alignment` parameter.
///
/// ```swift
/// VStack(alignment: .center) {
///     Text("Title").bold()
///     Text("Subtitle").dim()
/// }
/// ```
public struct VStack<Content: View>: View {
    let alignment: HorizontalAlignment
    let content: Content

    /// Create a vertical stack with the given alignment and content.
    ///
    /// - Parameters:
    ///   - alignment: How children are aligned horizontally when they have
    ///     different widths. Defaults to `.left`.
    ///   - content: A ``ViewBuilder`` closure that provides the children.
    public init(
        alignment: HorizontalAlignment = .left,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: ViewOutput {
        // A `ViewBuilder` closure's default join is vertical, so the
        // content's resolved output is already the children stacked
        // top-to-bottom.
        let joined = content._resolveToViewOutput()

        guard alignment != .left else { return joined }

        let lines = joined.content.splitLines()
        let maxWidth = lines.map(\.columnWidth).max() ?? 0
        let aligned = lines.map { $0.aligned(toWidth: maxWidth, alignment) }
        return ViewOutput(StyledText.fromLines(aligned))
    }
}

// MARK: - HStack

/// A container that stacks its children horizontally.
///
/// Children are joined left-to-right, aligned vertically according to the
/// `alignment` parameter.
///
/// ```swift
/// HStack(alignment: .bottom) {
///     Text("Left")
///     mainContent
/// }
/// ```
public struct HStack<Content: View>: View {
    let alignment: VerticalAlignment
    let content: Content

    /// Create a horizontal stack with the given alignment and content.
    ///
    /// - Parameters:
    ///   - alignment: How children are aligned vertically when they have
    ///     different heights. Defaults to `.top`.
    ///   - content: A ``ViewBuilder`` closure that provides the children.
    public init(
        alignment: VerticalAlignment = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: ViewOutput {
        let parts = content._collectChildOutputs()
        return Self.joinHorizontally(parts, align: alignment)
    }

    private static func joinHorizontally(_ components: [ViewOutput], align: VerticalAlignment) -> ViewOutput {
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
