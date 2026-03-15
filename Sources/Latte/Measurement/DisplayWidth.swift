import Foundation

/// Utilities for measuring and truncating strings by their *visible* terminal
/// width, correctly handling ANSI escape sequences and wide (CJK) characters.
///
/// All layout operations in Latte use these functions internally, so strings
/// containing ANSI colour or decoration codes are handled correctly everywhere.

// MARK: - Public API

/// Returns the number of visible terminal columns in a string.
///
/// ANSI escape sequences (CSI, OSC, SS3, SS2, and simple two-byte sequences)
/// are skipped entirely and do not contribute to the width. Wide characters
/// such as CJK ideographs and fullwidth Latin letters are counted as **2**
/// columns; combining marks and format characters count as **0**.
///
/// - Parameter string: The string to measure.
/// - Returns: The number of visible terminal columns.
public func visibleWidth(of string: String) -> Int {
    var width = 0
    var iter = string.unicodeScalars.makeIterator()

    while let scalar = iter.next() {
        if scalar == TerminalScalar.escape {
            guard let next = iter.next() else { break }
            switch next {
            case "[": skipCSI(&iter)
            case "]": skipOSC(&iter)
            case "O", "N": let _ = iter.next() // SS3 / SS2: consume final byte
            default: break                     // Two-byte escape: second byte already consumed
            }
            continue
        }
        width += displayWidth(of: scalar)
    }
    return width
}

/// Returns the number of visible lines (newline-delimited rows) in a string.
///
/// An empty string returns `0`; a non-empty string with no newlines returns `1`.
///
/// - Parameter string: The string to measure.
/// - Returns: The number of lines.
public func height(of string: String) -> Int {
    if string.isEmpty { return 0 }
    return string.components(separatedBy: "\n").count
}

/// Returns the visible terminal dimensions of a string block.
///
/// Equivalent to calling ``visibleWidth(of:)`` on the widest line and
/// ``height(of:)`` on the whole string.
///
/// - Parameter string: The string to measure.
/// - Returns: A tuple of `(width, height)` in terminal columns and lines.
public func size(of string: String) -> (width: Int, height: Int) {
    let lines = string.components(separatedBy: "\n")
    let w = lines.map { visibleWidth(of: $0) }.max() ?? 0
    return (width: w, height: lines.count)
}

/// Returns the number of terminal columns a single character occupies.
///
/// - East Asian wide / fullwidth characters return **2**.
/// - Zero-width characters (combining marks, zero-width space, etc.) return **0**.
/// - All other printable characters return **1**.
///
/// - Parameter character: The character to measure.
/// - Returns: The terminal column width: 0, 1, or 2.
public func displayWidth(of character: Character) -> Int {
    guard let scalar = character.unicodeScalars.first else { return 0 }
    return displayWidth(of: scalar)
}

/// Returns the number of terminal columns a Unicode scalar occupies.
///
/// - Parameter scalar: The scalar to measure.
/// - Returns: The terminal column width: 0, 1, or 2.
public func displayWidth(of scalar: Unicode.Scalar) -> Int {
    let category = scalar.properties.generalCategory
    if category == .control { return 0 }
    if isZeroWidth(scalar, category: category) { return 0 }
    if isWide(scalar.value) { return 2 }
    return 1
}

/// Truncates a string to at most `maxWidth` visible terminal columns.
///
/// ANSI escape sequences are preserved and do not count toward the width.
/// If a wide (2-column) character would push the visible width past `maxWidth`,
/// it is omitted — the string is truncated just before it.
///
/// - Parameters:
///   - string: The string to truncate.
///   - maxWidth: The maximum number of visible terminal columns to allow.
/// - Returns: A string whose visible width is ≤ `maxWidth`.
public func truncateToVisibleWidth(_ string: String, maxWidth: Int) -> String {
    guard maxWidth > 0 else { return "" }

    var result = ""
    var width = 0
    var index = string.startIndex

    while index < string.endIndex {
        let char = string[index]

        if char.unicodeScalars.first == TerminalScalar.escape {
            let escEnd = skipANSISequence(in: string, from: index)
            result += string[index..<escEnd]
            index = escEnd
            continue
        }

        let charWidth = displayWidth(of: char)
        if width + charWidth > maxWidth { break }
        result.append(char)
        width += charWidth
        index = string.index(after: index)
    }

    return result
}

// MARK: - Terminal control scalar constants

enum TerminalScalar {
    static let escape: Unicode.Scalar = "\u{1B}"
    static let bel: Unicode.Scalar = "\u{07}"
    static let csiFinalRange = Unicode.Scalar("@")...Unicode.Scalar("~")
}

// MARK: - Zero-width detection

private func isZeroWidth(_ scalar: Unicode.Scalar, category: Unicode.GeneralCategory) -> Bool {
    switch category {
    case .nonspacingMark, .enclosingMark:
        return true
    case .format:
        return scalar.properties.isDefaultIgnorableCodePoint
    default:
        return false
    }
}

// MARK: - Wide character detection

/// Returns `true` for East Asian Wide (W) and Fullwidth (F) characters.
///
/// Ranges derived from Unicode 15.1 East Asian Width data.
private func isWide(_ v: UInt32) -> Bool {
    if v >= 0x1100 && v <= 0x115F { return true }  // Hangul Jamo
    if v >= 0xD7B0 && v <= 0xD7FF { return true }  // Hangul Jamo Extended-B
    if v >= 0x2E80 && v <= 0x3247 { return true }  // CJK Radicals Supplement .. Enclosed CJK
    if v >= 0x3250 && v <= 0x4DBF { return true }  // Enclosed CJK ideographs subset
    if v >= 0x4E00 && v <= 0xA4CF { return true }  // CJK Unified Ideographs + more
    if v >= 0xAC00 && v <= 0xD7A3 { return true }  // Hangul Syllables
    if v >= 0xF900 && v <= 0xFAFF { return true }  // CJK Compatibility Ideographs
    if v >= 0xFE30 && v <= 0xFE6F { return true }  // CJK Compatibility Forms
    if v >= 0xFF01 && v <= 0xFF60 { return true }  // Fullwidth Latin / punctuation
    if v >= 0xFFE0 && v <= 0xFFE6 { return true }  // Fullwidth currency signs
    if v >= 0x20000 && v <= 0x2FFFD { return true } // CJK Extension B–F
    if v >= 0x30000 && v <= 0x3FFFD { return true } // CJK Extension G–I
    return false
}

// MARK: - Iterator-based ANSI sequence skippers

/// Advances the iterator past a CSI sequence (`ESC[` … final byte).
private func skipCSI(_ iter: inout String.UnicodeScalarView.Iterator) {
    while let s = iter.next() {
        if TerminalScalar.csiFinalRange.contains(s) { return }
    }
}

/// Advances the iterator past an OSC sequence (`ESC]` … BEL or `ESC\`).
private func skipOSC(_ iter: inout String.UnicodeScalarView.Iterator) {
    while let s = iter.next() {
        if s == TerminalScalar.bel { return }
        if s == TerminalScalar.escape {
            guard let next = iter.next() else { return }
            if next == Unicode.Scalar("\\") { return }
            continue
        }
    }
}

// MARK: - Index-based ANSI sequence skipper (for truncation)

/// Starting at `start` (which points to an ESC character), returns the index
/// immediately past the complete escape sequence.
func skipANSISequence(in string: String, from start: String.Index) -> String.Index {
    var i = string.index(after: start)
    guard i < string.endIndex else { return i }

    let next = string[i]

    if next == "[" {
        i = string.index(after: i)
        while i < string.endIndex {
            let scalar = string[i].unicodeScalars.first ?? "\0"
            i = string.index(after: i)
            if TerminalScalar.csiFinalRange.contains(scalar) { return i }
        }
        return i
    }

    if next == "]" {
        i = string.index(after: i)
        while i < string.endIndex {
            let scalar = string[i].unicodeScalars.first
            if scalar == TerminalScalar.bel {
                return string.index(after: i)
            }
            if scalar == TerminalScalar.escape {
                i = string.index(after: i)
                if i < string.endIndex && string[i].unicodeScalars.first == Unicode.Scalar("\\") {
                    i = string.index(after: i)
                    return i
                }
                continue
            }
            i = string.index(after: i)
        }
        return i
    }

    if next == "O" || next == "N" {
        i = string.index(after: i)
        if i < string.endIndex { i = string.index(after: i) }
        return i
    }

    return string.index(after: i)
}
