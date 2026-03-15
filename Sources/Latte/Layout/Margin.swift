/// Functions for adding exterior spacing (margin) around a block of text.
///
/// Margin is applied *outside* any border. Call ``margin(_:top:right:bottom:left:)``
/// after ``border(_:_:top:right:bottom:left:)`` to create space around the
/// bordered block.
///
/// Unlike padding, margin is semantically *exterior* space. When a styling
/// layer (such as Spices) applies a background colour, padding space inherits
/// the background while margin space does not. Within Latte itself both
/// produce whitespace, but keeping them as independent implementations lets
/// higher-level libraries distinguish the two.
///
/// Compose them in this order: padding → border → margin:
///
/// ```swift
/// margin(border(pad(content, 1, 2), .rounded), top: 1, left: 2)
/// ```

// MARK: - Canonical form (named parameters)

/// Adds exterior margin around a block of text.
///
/// ```swift
/// margin("Hello", top: 1, left: 4)
/// // ""           ← 1 blank line (top)
/// // "    Hello"  ← 4 spaces (left)
///
/// margin("Hi", left: 3, fill: ".")
/// // "...Hi"
/// ```
///
/// - Parameters:
///   - text: The string to apply margin to. May contain `\n`-separated lines.
///   - top: Blank lines added above the block. Defaults to `0`.
///   - right: Space columns added to the right of each line. Defaults to `0`.
///   - bottom: Blank lines added below the block. Defaults to `0`.
///   - left: Space columns added to the left of each line. Defaults to `0`.
///   - fill: The character used for margin space. Defaults to `" "` (space).
///     Must occupy exactly 1 terminal column; wide (CJK) or zero-width
///     characters produce incorrect visible widths.
/// - Returns: The string with margin applied, lines joined by `\n`.
public func margin(
    _ text: String,
    top: Int = 0,
    right: Int = 0,
    bottom: Int = 0,
    left: Int = 0,
    fill: Character = " "
) -> String {
    precondition(displayWidth(of: fill) == 1, "margin: fill must be a single-column character (displayWidth == 1)")
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

/// Adds equal margin on all four sides.
///
/// - Parameters:
///   - text: The string to apply margin to.
///   - all: Margin applied to every side.
///   - fill: The character used for margin space. Defaults to `" "`.
/// - Returns: The string with margin applied.
public func margin(_ text: String, _ all: Int, fill: Character = " ") -> String {
    margin(text, top: all, right: all, bottom: all, left: all, fill: fill)
}

/// Adds margin using the two-value CSS shorthand: vertical then horizontal.
///
/// - Parameters:
///   - text: The string to apply margin to.
///   - vertical: Margin for the top and bottom.
///   - horizontal: Margin for the left and right.
///   - fill: The character used for margin space. Defaults to `" "`.
/// - Returns: The string with margin applied.
public func margin(_ text: String, _ vertical: Int, _ horizontal: Int, fill: Character = " ") -> String {
    margin(text, top: vertical, right: horizontal, bottom: vertical, left: horizontal, fill: fill)
}

/// Adds margin using the three-value CSS shorthand: top, horizontal, bottom.
///
/// - Parameters:
///   - text: The string to apply margin to.
///   - top: Margin for the top.
///   - sides: Margin for the left and right.
///   - bottom: Margin for the bottom.
///   - fill: The character used for margin space. Defaults to `" "`.
/// - Returns: The string with margin applied.
public func margin(_ text: String, _ top: Int, _ sides: Int, _ bottom: Int, fill: Character = " ") -> String {
    margin(text, top: top, right: sides, bottom: bottom, left: sides, fill: fill)
}
