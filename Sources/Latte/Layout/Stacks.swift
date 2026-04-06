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
public struct VStack: View {
    private let output: ViewOutput

    /// Create a vertical stack with the given alignment and content.
    ///
    /// - Parameters:
    ///   - alignment: How children are aligned horizontally when they have
    ///     different widths. Defaults to `.left`.
    ///   - content: A ``ViewBuilder`` closure that provides the children.
    public init(
        alignment: HorizontalAlignment = .left,
        @ViewBuilder content: () -> ViewOutput
    ) {
        if alignment == .left {
            self.output = content()
        } else {
            let raw = content()
            let lines = raw.content.splitLines()
            let maxWidth = lines.map(\.columnWidth).max() ?? 0
            let aligned = lines.map { $0.aligned(toWidth: maxWidth, alignment) }
            self.output = ViewOutput(StyledText.fromLines(aligned))
        }
    }

    public var body: ViewOutput { output }
}

// MARK: - HStack

/// A container that places its children side by side horizontally.
///
/// Children are joined left-to-right, aligned vertically according to the
/// `alignment` parameter.
///
/// ```swift
/// HStack(alignment: .middle) {
///     sidebar
///     mainContent
/// }
/// ```
public struct HStack: View {
    private let output: ViewOutput

    /// Create a horizontal stack with the given alignment and content.
    ///
    /// - Parameters:
    ///   - alignment: How children are aligned vertically when they have
    ///     different heights. Defaults to `.top`.
    ///   - content: An ``HStackBuilder`` closure that provides the children.
    public init(
        alignment: VerticalAlignment = .top,
        @HStackBuilder content: () -> ViewOutput
    ) {
        self.output = content()
    }

    public var body: ViewOutput { output }
}
