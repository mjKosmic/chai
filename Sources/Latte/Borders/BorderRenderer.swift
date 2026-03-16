/// Draws a rectangular border around a block of text.

// MARK: - border

/// Draws a border around a string block using the given ``Border`` style.
///
/// The content is first normalised into a rectangular block (all lines padded
/// to the width of the widest line), then the chosen sides are drawn. Corners
/// appear only where two adjacent enabled sides meet.
///
/// Border characters can optionally be styled using closure parameters. Each
/// closure receives a border character string and returns the styled version.
/// This design keeps Latte dependency-free while allowing any styling system
/// (such as Spices' `Style.render`) to be plugged in:
///
/// ```swift
/// // Unstyled (unchanged from previous API)
/// border("Hello\nWorld", .rounded)
/// // ╭───────╮
/// // │ Hello │
/// // │ World │
/// // ╰───────╯
///
/// // Uniform cyan border (Latte-only, manual ANSI)
/// border("Hello", .rounded, borderStyle: { "\u{1B}[36m\($0)\u{1B}[0m" })
///
/// // With Spices (import Spices) — Style.render(_:) is (String) -> String
/// import Spices
/// let cyan = Style().foreground(.ansi(.cyan))
/// border("Hello", .rounded, borderStyle: cyan.render)
///
/// // Per-side styling
/// let red  = Style().foreground(.ansi(.red))
/// let blue = Style().foreground(.ansi(.blue))
/// border("Hello", .rounded, topStyle: red.render, bottomStyle: blue.render)
/// ```
///
/// - Parameters:
///   - text: The string to surround. May contain `\n`-separated lines.
///   - style: The ``Border`` to use. Defaults to ``Border/rounded``.
///   - top: Whether to draw the top edge. Defaults to `true`.
///   - right: Whether to draw the right edge. Defaults to `true`.
///   - bottom: Whether to draw the bottom edge. Defaults to `true`.
///   - left: Whether to draw the left edge. Defaults to `true`.
///   - borderStyle: Styling closure applied to all border characters.
///     Per-side styles override this when provided. Defaults to `nil`.
///   - topStyle: Styling closure for the top edge. Overrides `borderStyle`
///     for the top bar and top corners.
///   - bottomStyle: Styling closure for the bottom edge. Overrides
///     `borderStyle` for the bottom bar and bottom corners.
///   - leftStyle: Styling closure for the left edge. Overrides `borderStyle`
///     for left-side characters on content lines.
///   - rightStyle: Styling closure for the right edge. Overrides `borderStyle`
///     for right-side characters on content lines.
/// - Returns: The bordered string, with lines joined by `\n`.
public func border(
    _ text: String,
    _ style: Border = .rounded,
    top: Bool = true,
    right: Bool = true,
    bottom: Bool = true,
    left: Bool = true,
    borderStyle: (@Sendable (String) -> String)? = nil,
    topStyle: (@Sendable (String) -> String)? = nil,
    bottomStyle: (@Sendable (String) -> String)? = nil,
    leftStyle: (@Sendable (String) -> String)? = nil,
    rightStyle: (@Sendable (String) -> String)? = nil
) -> String {
    let lines = splitLines(text)
    let contentWidth = maxVisibleWidth(of: lines)

    // Normalise content into a uniform-width rectangular block.
    let uniformLines = lines.map { padLineRight($0, toWidth: contentWidth) }

    // Resolve effective styling closures per position.
    let effectiveTop = topStyle ?? borderStyle
    let effectiveBottom = bottomStyle ?? borderStyle
    let effectiveLeft = leftStyle ?? borderStyle
    let effectiveRight = rightStyle ?? borderStyle

    var result: [String] = []

    // Top edge
    if top {
        let bar = applyBorderStyle(String(repeating: style.top, count: contentWidth), effectiveTop)
        let tl = left ? applyBorderStyle(style.topLeft, effectiveTop) : ""
        let tr = right ? applyBorderStyle(style.topRight, effectiveTop) : ""
        result.append(tl + bar + tr)
    }

    // Content lines with optional left/right borders
    for line in uniformLines {
        let l = left ? applyBorderStyle(style.left, effectiveLeft) : ""
        let r = right ? applyBorderStyle(style.right, effectiveRight) : ""
        result.append(l + line + r)
    }

    // Bottom edge
    if bottom {
        let bar = applyBorderStyle(String(repeating: style.bottom, count: contentWidth), effectiveBottom)
        let bl = left ? applyBorderStyle(style.bottomLeft, effectiveBottom) : ""
        let br = right ? applyBorderStyle(style.bottomRight, effectiveBottom) : ""
        result.append(bl + bar + br)
    }

    return result.joined(separator: "\n")
}

// MARK: - Private

/// Applies an optional styling closure to a border string segment.
private func applyBorderStyle(_ text: String, _ style: (@Sendable (String) -> String)?) -> String {
    guard let style else { return text }
    return style(text)
}
