/// Draws a rectangular border around a block of text.

// MARK: - border

/// Draws a border around a string block using the given ``Border`` style.
///
/// The content is first normalised into a rectangular block (all lines padded
/// to the width of the widest line), then the chosen sides are drawn. Corners
/// appear only where two adjacent enabled sides meet.
///
/// Border characters can optionally be styled using ``Style`` parameters.
/// Per-side styles override the shared `borderStyle` for that side; corners
/// inherit the style of their horizontal edge (top or bottom). Content inside
/// the border is never styled.
///
/// ```swift
/// // Unstyled
/// border("Hello\nWorld", .rounded)
/// // ╭───────╮
/// // │ Hello │
/// // │ World │
/// // ╰───────╯
///
/// // Uniform cyan border
/// border("Hello", .rounded, borderStyle: Style().foreground(.ansi(.cyan)))
///
/// // Per-side styling
/// border("Hello", .rounded,
///     topStyle:    Style().foreground(.ansi(.red)),
///     bottomStyle: Style().foreground(.ansi(.blue)))
///
/// // Terminal-capability-safe: detect once, pass everywhere
/// let profile = ColorProfile.detect()
/// border("Hello", .rounded,
///     borderStyle: Style().foreground(.trueColor(r: 120, g: 80, b: 255)),
///     profile: profile)
/// ```
///
/// - Parameters:
///   - text: The string to surround. May contain `\n`-separated lines.
///   - style: The ``Border`` to use. Defaults to ``Border/rounded``.
///   - top: Whether to draw the top edge. Defaults to `true`.
///   - right: Whether to draw the right edge. Defaults to `true`.
///   - bottom: Whether to draw the bottom edge. Defaults to `true`.
///   - left: Whether to draw the left edge. Defaults to `true`.
///   - borderStyle: ``Style`` applied to all border characters. Per-side
///     styles override this when provided. Defaults to `nil` (unstyled).
///   - topStyle: ``Style`` for the top edge and top corners. Overrides
///     `borderStyle` for those characters.
///   - bottomStyle: ``Style`` for the bottom edge and bottom corners. Overrides
///     `borderStyle` for those characters.
///   - leftStyle: ``Style`` for the left edge on content lines. Overrides
///     `borderStyle` for those characters.
///   - rightStyle: ``Style`` for the right edge on content lines. Overrides
///     `borderStyle` for those characters.
///   - profile: The ``ColorProfile`` used when rendering border styles.
///     Colors are downsampled to fit the terminal's capability. Defaults to
///     `.trueColor` for backward compatibility — pass `ColorProfile.detect()`
///     to enable terminal-safe color rendering.
/// - Returns: The bordered string, with lines joined by `\n`.
public func border(
    _ text: String,
    _ style: Border = .rounded,
    top: Bool = true,
    right: Bool = true,
    bottom: Bool = true,
    left: Bool = true,
    borderStyle: Style? = nil,
    topStyle: Style? = nil,
    bottomStyle: Style? = nil,
    leftStyle: Style? = nil,
    rightStyle: Style? = nil,
    profile: ColorProfile = .trueColor
) -> String {
    let lines = splitLines(text)
    let contentWidth = maxVisibleWidth(of: lines)

    // Normalise content into a uniform-width rectangular block.
    let uniformLines = lines.map { padLineRight($0, toWidth: contentWidth) }

    // Resolve effective styling per position.
    let effectiveTop    = topStyle    ?? borderStyle
    let effectiveBottom = bottomStyle ?? borderStyle
    let effectiveLeft   = leftStyle   ?? borderStyle
    let effectiveRight  = rightStyle  ?? borderStyle

    var result: [String] = []

    // Top edge
    if top {
        let bar = applyBorderStyle(String(repeating: style.top, count: contentWidth), effectiveTop, profile)
        let tl = left  ? applyBorderStyle(style.topLeft,  effectiveTop, profile) : ""
        let tr = right ? applyBorderStyle(style.topRight, effectiveTop, profile) : ""
        result.append(tl + bar + tr)
    }

    // Content lines with optional left/right borders
    for line in uniformLines {
        let l = left  ? applyBorderStyle(style.left,  effectiveLeft,  profile) : ""
        let r = right ? applyBorderStyle(style.right, effectiveRight, profile) : ""
        result.append(l + line + r)
    }

    // Bottom edge
    if bottom {
        let bar = applyBorderStyle(String(repeating: style.bottom, count: contentWidth), effectiveBottom, profile)
        let bl = left  ? applyBorderStyle(style.bottomLeft,  effectiveBottom, profile) : ""
        let br = right ? applyBorderStyle(style.bottomRight, effectiveBottom, profile) : ""
        result.append(bl + bar + br)
    }

    return result.joined(separator: "\n")
}

// MARK: - Private

/// Applies an optional ``Style`` to a border string segment using the given color profile.
private func applyBorderStyle(_ text: String, _ style: Style?, _ profile: ColorProfile) -> String {
    guard let style else { return text }
    return style.render(text, profile: profile)
}
