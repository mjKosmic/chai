import Chai

// MARK: - PaddingView (Stage C wrapper)
//
// Phase 4 P4a (UPGRADE.md, "Stage C on the new kernel"): modifier wrappers
// stay in the tree. A padding wrapper is a CONTAINER, not a raster transform:
// it reports the child's size plus its insets, and its allocation entrance
// gives the child an inset rect. The assignment bounds the child's query (so
// wrapping composes with padding), and the child's report — not the assigned
// rect — decides the painted extent (shrink-wrap; phase-4 decision 1). The
// root renderer's rect is the terminal width, so a root padding wrapper still
// shrink-wraps to its content instead of stretching it; `frame()` is the
// opt-in for filling.

/// A view that surrounds its content with blank space.
///
/// ``View/padded(top:right:bottom:left:)`` places padding *inside* the view's
/// own bounds: the wrapper occupies the child's size plus the insets, and the
/// child is embedded at the inset origin. Unlike the eager
/// ``ViewOutput/padded(top:right:bottom:left:)`` transform, the wrapper stays
/// in the view tree, so it composes with the layout engine:
///
/// ```swift
/// HStack {
///     Text("a").padded(1)          // occupies 3×3
///     Text("b")
/// }
/// ```
///
/// ## Engine semantics
///
/// - **Query:** the child is queried with the assignment reduced by the
///   insets, so a wrapping child wraps into the padded area. The report is
///   the child's report plus the insets.
/// - **Allocation:** the child is embedded at `origin + insets` with the size
///   it reports under the inset query. The wrapper shrink-wraps; excess
///   assigned space stays blank to the right and below.
/// - **Flexibility:** forwarded from the child, so a flexible child inside
///   padding still absorbs a stack's leftover space. Dropping this forwarding
///   would silently make the wrapper rigid — the PR #21 review's
///   silent-failure pattern.
public struct PaddingView<Content: View>: View {
    /// Lines of padding above the content.
    let top: Int
    /// Columns of padding to the right of the content.
    let right: Int
    /// Lines of padding below the content.
    let bottom: Int
    /// Columns of padding to the left of the content.
    let left: Int
    /// The padded content.
    let content: Content

    /// Create a padding wrapper.
    ///
    /// - Parameters:
    ///   - top: Lines of padding above the content.
    ///   - right: Columns of padding to the right of the content.
    ///   - bottom: Lines of padding below the content.
    ///   - left: Columns of padding to the left of the content.
    ///   - content: A ``ViewBuilder`` closure providing the content.
    public init(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.top = max(0, top)
        self.right = max(0, right)
        self.bottom = max(0, bottom)
        self.left = max(0, left)
        self.content = content()
    }

    // MARK: Legacy body (eager path)

    /// The eager resolution path, retired with the rest of the eager family
    /// in P4b. It reproduces the pre-wrapper behavior exactly (the raster is
    /// padded after resolution), so the parity spec keeps its reference while
    /// both paths coexist.
    public var body: ViewOutput {
        ViewOutput(
            content._resolveToViewOutput().content.pad(
                top: top,
                right: right,
                bottom: bottom,
                left: left
            )
        )
    }
}

// MARK: - PaddingView engine implementation

extension PaddingView {
    /// The child's proposal under this wrapper's assignment, with each axis
    /// reduced by its insets. A `nil` assignment stays ideal; a degenerate
    /// assignment floors at zero rather than proposing a negative size.
    private func childProposal(for proposal: ProposedSize) -> ProposedSize {
        ProposedSize(
            width: proposal.width.map { max(0, $0 - left - right) },
            height: proposal.height.map { max(0, $0 - top - bottom) }
        )
    }

    /// Report the child's report plus the insets (shrink-wrap).
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let child = content._sizeThatFits(childProposal(for: proposal))
        return ViewSize(
            width: child.width + left + right,
            height: child.height + top + bottom
        )
    }

    /// Embed the child at the inset origin, at the size it reports under the
    /// inset query. The wrapper does not stretch the child to fill the
    /// assignment; the parent's rect is a bound on the query, and `frame()`
    /// is the opt-in that fills.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let childSize = content._sizeThatFits(childProposal(for: ProposedSize(
            width: rect.size.width,
            height: rect.size.height
        )))
        content._embed(
            into: &buffer,
            at: ViewRect(
                origin: ViewOrigin(col: rect.origin.col + left, row: rect.origin.row + top),
                size: childSize
            )
        )
    }

    /// Forward the child's flexibility: padding is transparent to a stack's
    /// leftover distribution.
    public func _flexibility() -> LayoutFlexibility {
        content._flexibility()
    }
}

// MARK: - View.padded / View.margined modifiers

extension View {
    /// Add interior padding around this view.
    ///
    /// The padding stays in the view tree: the wrapper occupies this view's
    /// size plus the insets, and the content is placed at the inset origin.
    ///
    /// ```swift
    /// VStack {
    ///     Text("Title")
    ///     Text("Body")
    /// }
    /// .padded(top: 1, right: 2, bottom: 1, left: 2)
    /// ```
    ///
    /// - Parameters:
    ///   - top: Lines of padding above the content.
    ///   - right: Columns of padding to the right of the content.
    ///   - bottom: Lines of padding below the content.
    ///   - left: Columns of padding to the left of the content.
    /// - Returns: A ``PaddingView`` wrapping this view.
    public func padded(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0
    ) -> PaddingView<Self> {
        PaddingView(top: top, right: right, bottom: bottom, left: left) { self }
    }

    /// Add equal padding on all sides.
    ///
    /// - Parameter amount: The amount of padding on each side.
    /// - Returns: A ``PaddingView`` wrapping this view.
    public func padded(_ amount: Int) -> PaddingView<Self> {
        padded(top: amount, right: amount, bottom: amount, left: amount)
    }

    /// Add padding with vertical and horizontal values (CSS-style 2-value).
    ///
    /// - Parameters:
    ///   - vertical: Lines of padding above and below.
    ///   - horizontal: Columns of padding left and right.
    /// - Returns: A ``PaddingView`` wrapping this view.
    public func padded(_ vertical: Int, _ horizontal: Int) -> PaddingView<Self> {
        padded(
            top: vertical,
            right: horizontal,
            bottom: vertical,
            left: horizontal
        )
    }

    /// Add exterior margin around this view.
    ///
    /// At the raster level margin and padding are identical (the eager helpers
    /// share one implementation). The distinction is semantic — margin is
    /// outside the border, padding is inside — so this returns the same
    /// ``PaddingView`` wrapper under a margin-facing name.
    ///
    /// - Parameters:
    ///   - top: Lines of margin above the content.
    ///   - right: Columns of margin to the right of the content.
    ///   - bottom: Lines of margin below the content.
    ///   - left: Columns of margin to the left of the content.
    /// - Returns: A ``PaddingView`` wrapping this view.
    public func margined(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0
    ) -> PaddingView<Self> {
        padded(top: top, right: right, bottom: bottom, left: left)
    }

    /// Add equal margin on all sides.
    ///
    /// - Parameter amount: The amount of margin on each side.
    /// - Returns: A ``PaddingView`` wrapping this view.
    public func margined(_ amount: Int) -> PaddingView<Self> {
        padded(amount)
    }

    /// Add margin with vertical and horizontal values (CSS-style 2-value).
    ///
    /// - Parameters:
    ///   - vertical: Lines of margin above and below.
    ///   - horizontal: Columns of margin left and right.
    /// - Returns: A ``PaddingView`` wrapping this view.
    public func margined(_ vertical: Int, _ horizontal: Int) -> PaddingView<Self> {
        padded(vertical, horizontal)
    }
}
