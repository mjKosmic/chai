import Foundation

/// Internal string-manipulation helpers shared across Latte modules.
///
/// These are implementation details — do not make them public.

// MARK: - Line splitting

/// Splits a string into lines on `\n`.
///
/// An empty string returns `[""]` (one empty line), matching the behaviour of
/// `String.components(separatedBy:)`.
func splitLines(_ string: String) -> [String] {
    return string.components(separatedBy: "\n")
}

// MARK: - Line width helpers

/// Returns the maximum visible terminal column width across all lines.
///
/// Returns `0` for an empty array or an array containing only empty strings.
func maxVisibleWidth(of lines: [String]) -> Int {
    return lines.map { visibleWidth(of: $0) }.max() ?? 0
}

// MARK: - Line padding

/// Pads a single line on its right side with a fill character until it reaches
/// `width` visible terminal columns.
///
/// If the line is already at or wider than `width`, it is returned unchanged.
/// ANSI escape sequences in the line are preserved and do not count toward
/// the visible width.
///
/// - Precondition: `fill` must occupy exactly 1 terminal column
///   (`displayWidth(of: fill) == 1`). Wide (CJK) or zero-width characters
///   will produce incorrect visible widths.
func padLineRight(_ line: String, toWidth width: Int, fill: Character = " ") -> String {
    let w = visibleWidth(of: line)
    guard w < width else { return line }
    return line + String(repeating: fill, count: width - w)
}

// MARK: - Single-line alignment

/// Aligns a single line within a fixed `width` by padding with spaces.
///
/// The alignment's `fraction` determines how the shortage is distributed:
/// `0.0` puts all padding on the right (left-align), `1.0` on the left
/// (right-align), and `0.5` splits evenly (centre).
///
/// Lines already wider than `width` are returned unchanged (no truncation).
func alignLine(_ line: String, width: Int, _ alignment: HorizontalAlignment) -> String {
    let lineWidth = visibleWidth(of: line)
    let shortage = max(0, width - lineWidth)
    guard shortage > 0 else { return line }

    let leftPad = Int(Double(shortage) * alignment.fraction)
    let rightPad = shortage - leftPad
    return String(repeating: " ", count: leftPad) + line + String(repeating: " ", count: rightPad)
}
