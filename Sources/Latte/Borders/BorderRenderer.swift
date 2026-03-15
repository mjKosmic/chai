/// Draws a rectangular border around a block of text.

// MARK: - border

/// Draws a border around a string block using the given ``Border`` style.
///
/// The content is first normalised into a rectangular block (all lines padded
/// to the width of the widest line), then the chosen sides are drawn. Corners
/// appear only where two adjacent enabled sides meet.
///
/// ```swift
/// border("Hello\nWorld", .rounded)
/// // ╭───────╮
/// // │ Hello │
/// // │ World │
/// // ╰───────╯
///
/// // Top and bottom only (no side bars)
/// border("Hello", .normal, left: false, right: false)
/// // ─────
/// // Hello
/// // ─────
/// ```
///
/// - Parameters:
///   - text: The string to surround. May contain `\n`-separated lines.
///   - style: The ``Border`` to use. Defaults to ``Border/rounded``.
///   - top: Whether to draw the top edge. Defaults to `true`.
///   - right: Whether to draw the right edge. Defaults to `true`.
///   - bottom: Whether to draw the bottom edge. Defaults to `true`.
///   - left: Whether to draw the left edge. Defaults to `true`.
/// - Returns: The bordered string, with lines joined by `\n`.
public func border(
    _ text: String,
    _ style: Border = .rounded,
    top: Bool = true,
    right: Bool = true,
    bottom: Bool = true,
    left: Bool = true
) -> String {
    let lines = splitLines(text)
    let contentWidth = maxVisibleWidth(of: lines)

    // Normalise content into a uniform-width rectangular block.
    let uniformLines = lines.map { padLineRight($0, toWidth: contentWidth) }

    var result: [String] = []

    // Top edge
    if top {
        let bar = String(repeating: style.top, count: contentWidth)
        let tl = left ? style.topLeft : ""
        let tr = right ? style.topRight : ""
        result.append(tl + bar + tr)
    }

    // Content lines with optional left/right borders
    for line in uniformLines {
        let l = left ? style.left : ""
        let r = right ? style.right : ""
        result.append(l + line + r)
    }

    // Bottom edge
    if bottom {
        let bar = String(repeating: style.bottom, count: contentWidth)
        let bl = left ? style.bottomLeft : ""
        let br = right ? style.bottomRight : ""
        result.append(bl + bar + br)
    }

    return result.joined(separator: "\n")
}
