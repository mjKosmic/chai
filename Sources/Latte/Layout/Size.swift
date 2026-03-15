/// Functions for enforcing minimum and maximum dimensions on a block of text.

// MARK: - enforceWidth

/// Ensures every line in a string is at least `width` visible terminal columns.
///
/// Lines shorter than `width` are padded with spaces according to `alignment`.
/// Lines already at or wider than `width` are returned unchanged — this
/// function only enforces a *minimum* width, never truncates. Use
/// ``truncateToVisibleWidth(_:maxWidth:)`` to cap width.
///
/// ```swift
/// enforceWidth("Hi\nHello!", 8)
/// // "Hi      "  ← padded to 8
/// // "Hello!  "  ← padded to 8
///
/// enforceWidth("Hi", 8, alignment: .right)
/// // "      Hi"
/// ```
///
/// - Parameters:
///   - text: The string to process. May contain `\n`-separated lines.
///   - width: The minimum number of visible columns per line.
///   - alignment: How to distribute padding. Defaults to `.left`.
/// - Returns: The string with every line padded to at least `width` columns.
public func enforceWidth(
    _ text: String,
    _ width: Int,
    alignment: HorizontalAlignment = .left
) -> String {
    let lines = splitLines(text)
    return lines
        .map { alignLine($0, width: width, alignment) }
        .joined(separator: "\n")
}

// MARK: - enforceHeight

/// Ensures a string block has at least `height` lines.
///
/// When the content has fewer than `height` lines, blank lines are added
/// according to `alignment`. The standard presets behave as:
/// - `.top` — blank lines appended at the bottom.
/// - `.middle` — blank lines split evenly above and below (odd remainder goes below).
/// - `.bottom` — blank lines prepended at the top.
///
/// More generally, any `VerticalAlignment` created via
/// `VerticalAlignment(fraction:)` is supported. The `fraction` describes
/// how much of the vertical padding should go *above* the content:
/// - `0.0` — all extra lines are added below (equivalent to `.top`).
/// - `0.5` — padding is split evenly above and below (equivalent to `.middle`).
/// - `1.0` — all extra lines are added above (equivalent to `.bottom`).
/// - other values between `0.0` and `1.0` place the content at an arbitrary
///   vertical position within the padded block.
///
/// When the content already has `height` or more lines, it is returned
/// unchanged — this function only enforces a *minimum* height, never
/// truncates.
///
/// Blank lines are as wide as the widest content line.
///
/// ```swift
/// enforceHeight("Line 1\nLine 2", 4)
/// // "Line 1"
/// // "Line 2"
/// // "      "  ← blank
/// // "      "  ← blank
/// ```
///
/// - Parameters:
///   - text: The string to process. May contain `\n`-separated lines.
///   - height: The minimum number of lines.
///   - alignment: Where to place the content within the block. You can use
///     the presets (`.top`, `.middle`, `.bottom`) or a custom
///     `VerticalAlignment(fraction:)`. Defaults to `.top`.
/// - Returns: The string padded to at least `height` lines.
public func enforceHeight(
    _ text: String,
    _ height: Int,
    alignment: VerticalAlignment = .top
) -> String {
    var lines = splitLines(text)
    let shortage = max(0, height - lines.count)
    guard shortage > 0 else { return text }

    let contentWidth = maxVisibleWidth(of: lines)
    let blankLine = String(repeating: " ", count: contentWidth)

    let topPad = Int(Double(shortage) * alignment.fraction)
    let bottomPad = shortage - topPad
    lines = Array(repeating: blankLine, count: topPad) + lines
        + Array(repeating: blankLine, count: bottomPad)

    return lines.joined(separator: "\n")
}

// MARK: - clampWidth

/// Truncates each line in a string to at most `maxWidth` visible terminal columns.
///
/// Lines shorter than or equal to `maxWidth` are returned unchanged. Lines wider
/// than `maxWidth` are truncated using ``truncateToVisibleWidth(_:maxWidth:)``,
/// which preserves ANSI escape sequences and handles wide characters correctly.
///
/// This is the maximum-width counterpart to ``enforceWidth(_:_:alignment:)``.
///
/// ```swift
/// clampWidth("Hello, World!", 5)
/// // "Hello"
///
/// clampWidth("Hi\nHello, World!", 8)
/// // "Hi"
/// // "Hello, W"
/// ```
///
/// - Parameters:
///   - text: The string to process. May contain `\n`-separated lines.
///   - maxWidth: The maximum number of visible columns per line.
/// - Returns: The string with every line truncated to at most `maxWidth` columns.
public func clampWidth(
    _ text: String,
    _ maxWidth: Int
) -> String {
    let lines = splitLines(text)
    return lines
        .map { truncateToVisibleWidth($0, maxWidth: maxWidth) }
        .joined(separator: "\n")
}

// MARK: - clampHeight

/// Drops lines beyond `maxHeight` from a string block.
///
/// When the content has more than `maxHeight` lines, only the first `maxHeight`
/// lines are kept (content is anchored to the top). When the content already has
/// `maxHeight` or fewer lines, it is returned unchanged.
///
/// This is the maximum-height counterpart to ``enforceHeight(_:_:alignment:)``.
///
/// ```swift
/// clampHeight("A\nB\nC\nD", 2)
/// // "A"
/// // "B"
/// ```
///
/// - Parameters:
///   - text: The string to process. May contain `\n`-separated lines.
///   - maxHeight: The maximum number of lines to keep.
/// - Returns: The string with at most `maxHeight` lines.
public func clampHeight(
    _ text: String,
    _ maxHeight: Int
) -> String {
    guard maxHeight > 0 else { return "" }
    let lines = splitLines(text)
    guard lines.count > maxHeight else { return text }
    return lines.prefix(maxHeight).joined(separator: "\n")
}

// MARK: - clamp

/// Caps both the width and height of a string block.
///
/// Equivalent to calling ``clampWidth(_:_:)`` followed by
/// ``clampHeight(_:_:)``.
///
/// ```swift
/// clamp("Hello, World!\nSecond line\nThird line", maxWidth: 8, maxHeight: 2)
/// // "Hello, W"
/// // "Second l"
/// ```
///
/// - Parameters:
///   - text: The string to process. May contain `\n`-separated lines.
///   - maxWidth: The maximum number of visible columns per line.
///   - maxHeight: The maximum number of lines to keep.
/// - Returns: The string clamped to at most `maxWidth` columns and `maxHeight` lines.
public func clamp(
    _ text: String,
    maxWidth: Int,
    maxHeight: Int
) -> String {
    clampHeight(clampWidth(text, maxWidth), maxHeight)
}
