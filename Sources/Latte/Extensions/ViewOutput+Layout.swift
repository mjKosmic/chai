import Chai

// MARK: - ViewOutput raster helpers
//
// The modifier family lives on `View` (`.padded`, `.bordered`, `.frame`,
// `.beside`, `.above`, ...), so modifiers stay in the view tree and the simple
// path uses the String/StyledText helpers plus `ViewOutput(...)`.
//
// The two clamping helpers below are deliberately kept: they are *raster*
// operations on a fully-formed `ViewOutput`, not modifiers. They have no
// tree-based equivalent (a frame sets an exact size; allocation clips to a
// rect; neither truncates the raster content itself), and the simple path may
// use them without touching the layout engine.
//
// Terminal state is managed separately from views: alt screen via
// ``Program/Option/withAltScreen``, window title via
// ``Command/setWindowTitle(_:)``, and cursor via ``Model/cursor``.

extension ViewOutput {

    /// Truncate each line to at most `max` display columns.
    ///
    /// This is a raster helper: it transforms the styled content in place and
    /// never enters the layout engine. (Allocation already clips a view to
    /// its rect; this is for truncating the content itself.)
    ///
    /// - Parameter max: The maximum column width.
    public func clampedWidth(_ max: Int) -> ViewOutput {
        transformContent { $0.clampWidth(max) }
    }

    /// Keep only the first `max` lines.
    ///
    /// This is a raster helper: it transforms the styled content in place and
    /// never enters the layout engine.
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
