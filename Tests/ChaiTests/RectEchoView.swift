import Chai

// MARK: - Rect-echo test consumer (test-local only)

/// A test-local allocation consumer: reports `min(available.width ?? 12, 12)`
/// wide (height 1) and paints `W:<rect.width>` at its allocated rect's origin.
///
/// A test-local consumer that observes its allocated rect: the render pass
/// receives no remembered query value, so what a child can observe is the
/// **rect it was allocated**. Tests use it to pin that containers hand children
/// their allocated rects (frames: the fixed/passed width; stacks: the child's
/// own report), not the container's rect.
/// (Duplicated in the LatteTests target, which cannot see this file.)
struct RectEchoView: View {
    var body: ViewOutput { ViewOutput("") }

    func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: min(available.width ?? 12, 12), height: 1)
    }

    func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        buffer.write(StyledText("W:\(rect.size.width)"), at: rect.origin.col, row: rect.origin.row)
    }
}
