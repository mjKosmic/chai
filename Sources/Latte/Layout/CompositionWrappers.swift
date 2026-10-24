import Chai

// MARK: - View.beside / View.above (Stage C composition)
//
// Phase 4 P4a (UPGRADE.md, "Stage C on the new kernel"): the eager
// `ViewOutput.beside(_:align:)` / `.above(_:align:)` transforms become
// container sugar. Composition is a container rule — `beside` is an
// `HStack`, `above` is a `VStack` — so the two views stay in the tree and
// the stack allocates their rects.

extension View {
    /// Place another view to the right of this one.
    ///
    /// Sugar for an ``HStack`` with two children: the pair is measured and
    /// allocated by the stack, so each side keeps its own engine behavior
    /// (wrapping, flexibility, frames) instead of being flattened to a raster.
    ///
    /// ```swift
    /// Text("left").beside(Text("right"), align: .bottom)
    /// ```
    ///
    /// - Parameters:
    ///   - other: The view to place on the right.
    ///   - align: Vertical alignment when the views have different heights.
    ///     Defaults to ``VerticalAlignment/top``.
    /// - Returns: A view that arranges this view and `other` horizontally.
    public func beside<Other: View>(
        _ other: Other,
        align: VerticalAlignment = .top
    ) -> some View {
        HStack(alignment: align) {
            self
            other
        }
    }

    /// Place another view below this one.
    ///
    /// Sugar for a ``VStack`` with two children: the pair is measured and
    /// allocated by the stack, so each side keeps its own engine behavior
    /// (wrapping, flexibility, frames) instead of being flattened to a raster.
    ///
    /// ```swift
    /// Text("top").above(Text("bottom"), align: .center)
    /// ```
    ///
    /// - Parameters:
    ///   - other: The view to place below.
    ///   - align: Horizontal alignment when the views have different widths.
    ///     Defaults to ``HorizontalAlignment/left``.
    /// - Returns: A view that arranges this view and `other` vertically.
    public func above<Other: View>(
        _ other: Other,
        align: HorizontalAlignment = .left
    ) -> some View {
        VStack(alignment: align) {
            self
            other
        }
    }
}
