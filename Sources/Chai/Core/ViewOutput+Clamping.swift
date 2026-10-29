// MARK: - ViewOutput raster helpers
//
// Raster clamping operates on a finished ``ViewOutput``. It is a content
// transformation, not a layout modifier: the clamped view reports the smaller
// size, unlike a fixed ``frame`` which allocates a rect and clips the paint at
// its boundary. Neither operation replaces the other.

extension ViewOutput {

    /// Truncate each line to at most `max` display columns.
    ///
    /// A wide character that would straddle the boundary is dropped whole.
    /// Content narrower than `max` is left unchanged.
    ///
    /// - Parameter max: The maximum column width.
    public func clampedWidth(_ max: Int) -> ViewOutput {
        transformContent { $0.clampWidth(max) }
    }

    /// Keep only the first `max` lines.
    ///
    /// - Parameter max: The maximum line count.
    public func clampedHeight(_ max: Int) -> ViewOutput {
        transformContent { $0.clampHeight(max) }
    }
}

// MARK: - Internal helper

extension ViewOutput {

    /// Transform the content, returning a new ViewOutput.
    private func transformContent(_ transform: (StyledText) -> StyledText) -> ViewOutput {
        ViewOutput(transform(content))
    }
}
