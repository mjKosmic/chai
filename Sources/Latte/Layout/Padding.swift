/// Functions for adding interior spacing (padding) around a block of text.
///
/// Padding is applied *inside* any border. Call ``pad(_:top:right:bottom:left:)``
/// before ``border(_:_:top:right:bottom:left:)`` to create space between the
/// border and the content.
///
/// All variants produce a rectangular block: content lines are first padded to
/// the width of the widest line, then left/right space is appended, and
/// top/bottom blank lines are added at the full block width.

// MARK: - Canonical form (named parameters)

/// Adds interior padding around a block of text.
///
/// ```swift
/// pad("Hello", top: 1, right: 2, bottom: 1, left: 2)
/// // "      "          ← 2 (left) + 5 (content) + 2 (right) = 9 cols
/// // "  Hello  "
/// // "      "
///
/// pad("Hi", left: 3, fill: ".")
/// // "...Hi"
/// ```
///
/// - Parameters:
///   - text: The string to pad. May contain `\n`-separated lines.
///   - top: Blank lines added above the content. Defaults to `0`.
///   - right: Space columns added to the right of each line. Defaults to `0`.
///   - bottom: Blank lines added below the content. Defaults to `0`.
///   - left: Space columns added to the left of each line. Defaults to `0`.
///   - fill: The character used for padding. Defaults to `" "` (space).
///     Must occupy exactly 1 terminal column; wide (CJK) or zero-width
///     characters produce incorrect visible widths.
/// - Returns: The padded string, with lines joined by `\n`.
public func pad(
    _ text: String,
    top: Int = 0,
    right: Int = 0,
    bottom: Int = 0,
    left: Int = 0,
    fill: Character = " "
) -> String {
    precondition(displayWidth(of: fill) == 1, "pad: fill must be a single-column character (displayWidth == 1)")
    let lines = splitLines(text)
    let contentWidth = maxVisibleWidth(of: lines)

    // Pad each content line to contentWidth, then wrap with left/right fill.
    let paddedLines = lines.map { line -> String in
        let uniform = padLineRight(line, toWidth: contentWidth, fill: fill)
        return String(repeating: fill, count: left) + uniform + String(repeating: fill, count: right)
    }

    // Blank lines span the full block width.
    let totalWidth = left + contentWidth + right
    let blankLine = String(repeating: fill, count: totalWidth)
    let topLines = Array(repeating: blankLine, count: top)
    let bottomLines = Array(repeating: blankLine, count: bottom)

    return (topLines + paddedLines + bottomLines).joined(separator: "\n")
}

// MARK: - CSS-style shorthand overloads

/// Adds equal padding on all four sides.
///
/// ```swift
/// pad("Hi", 1)
/// // "    "  ← 1 + 2 + 1 = 4 cols
/// // " Hi "
/// // "    "
/// ```
///
/// - Parameters:
///   - text: The string to pad.
///   - all: Padding applied to every side.
///   - fill: The character used for padding. Defaults to `" "`.
/// - Returns: The padded string.
public func pad(_ text: String, _ all: Int, fill: Character = " ") -> String {
    pad(text, top: all, right: all, bottom: all, left: all, fill: fill)
}

/// Adds padding using the two-value CSS shorthand: vertical then horizontal.
///
/// ```swift
/// pad("Hi", 1, 2)
/// // "      "  ← 2 + 2 + 2 = 6 cols
/// // "  Hi  "
/// // "      "
/// ```
///
/// - Parameters:
///   - text: The string to pad.
///   - vertical: Padding for the top and bottom.
///   - horizontal: Padding for the left and right.
///   - fill: The character used for padding. Defaults to `" "`.
/// - Returns: The padded string.
public func pad(_ text: String, _ vertical: Int, _ horizontal: Int, fill: Character = " ") -> String {
    pad(text, top: vertical, right: horizontal, bottom: vertical, left: horizontal, fill: fill)
}

/// Adds padding using the three-value CSS shorthand: top, horizontal, bottom.
///
/// ```swift
/// pad("Hi", 1, 2, 0)
/// // "      "  ← top blank line
/// // "  Hi  "  ← 2 left + content + 2 right
/// ```
///
/// - Parameters:
///   - text: The string to pad.
///   - top: Padding for the top.
///   - sides: Padding for the left and right.
///   - bottom: Padding for the bottom.
///   - fill: The character used for padding. Defaults to `" "`.
/// - Returns: The padded string.
public func pad(_ text: String, _ top: Int, _ sides: Int, _ bottom: Int, fill: Character = " ") -> String {
    pad(text, top: top, right: sides, bottom: bottom, left: sides, fill: fill)
}
