/// Functions for placing a string block within a fixed-size whitespace canvas.

// MARK: - place

/// Places a string block within a `width × height` whitespace canvas.
///
/// This is equivalent to calling ``placeHorizontal(width:_:_:)`` followed by
/// ``placeVertical(height:_:_:)``.
///
/// ```swift
/// place(width: 20, height: 5, horizontal: .center, vertical: .middle, "Hi")
/// // "                    "  ← blank
/// // "                    "  ← blank
/// // "         Hi         "  ← centered
/// // "                    "  ← blank
/// // "                    "  ← blank
/// ```
///
/// - Parameters:
///   - width: The total column width of the canvas.
///   - height: The total line count of the canvas.
///   - horizontal: How the content is aligned horizontally.
///   - vertical: How the content is aligned vertically.
///   - content: The string block to place.
/// - Returns: The placed string, with rows separated by `\n`.
public func place(
    width: Int,
    height: Int,
    horizontal: HorizontalAlignment,
    vertical: VerticalAlignment,
    _ content: String
) -> String {
    let h = placeHorizontal(width: width, horizontal, content)
    return placeVertical(height: height, vertical, h)
}

// MARK: - placeHorizontal

/// Places a string block within a fixed-width horizontal canvas.
///
/// Each line is padded (or already at the target width) according to
/// `alignment`. Lines wider than `width` are not truncated.
///
/// ```swift
/// placeHorizontal(width: 10, .right, "Hi")
/// // "        Hi"
/// ```
///
/// - Parameters:
///   - width: The target column width.
///   - alignment: How the content is aligned within `width`.
///   - content: The string block to place.
/// - Returns: The horizontally placed string.
public func placeHorizontal(
    width: Int,
    _ alignment: HorizontalAlignment,
    _ content: String
) -> String {
    align(content, width: width, alignment)
}

// MARK: - placeVertical

/// Places a string block within a fixed-height vertical canvas.
///
/// Blank lines (as wide as the widest content line) are added above, below,
/// or on both sides of the content according to `alignment`. If the content
/// already has `height` or more lines, it is returned unchanged.
///
/// ```swift
/// placeVertical(height: 5, .bottom, "Line 1\nLine 2")
/// // "      "  ← blank
/// // "      "  ← blank
/// // "      "  ← blank
/// // "Line 1"
/// // "Line 2"
/// ```
///
/// - Parameters:
///   - height: The target line count.
///   - alignment: How the content is aligned within `height`.
///   - content: The string block to place.
/// - Returns: The vertically placed string.
public func placeVertical(
    height: Int,
    _ alignment: VerticalAlignment,
    _ content: String
) -> String {
    enforceHeight(content, height, alignment: alignment)
}
