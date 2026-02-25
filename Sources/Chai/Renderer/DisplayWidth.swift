/// Utilities for measuring and truncating strings by their *visible* terminal
/// width, correctly handling ANSI escape sequences and wide (CJK) characters.

// MARK: - Terminal control scalar constants

/// Named constants for terminal control scalars used in ANSI sequence parsing,
/// replacing raw hex values with self-documenting identifiers.
private enum TerminalScalar {
    /// ESC (U+001B) — introduces all ANSI escape sequences.
    static let escape: Unicode.Scalar = "\u{1B}"
    /// BEL (U+0007) — terminates OSC sequences.
    static let bel: Unicode.Scalar = "\u{07}"
    /// CSI final byte range per ECMA-48: `@` (U+0040) through `~` (U+007E).
    static let csiFinalRange = Unicode.Scalar("@")...Unicode.Scalar("~")
}

// MARK: - Display width of a single character

/// Returns the number of terminal columns a character occupies.
///
/// - East Asian wide / fullwidth characters return **2**.
/// - Zero-width characters (combining marks, zero-width space, etc.) return **0**.
/// - All other printable characters return **1**.
///
/// This approximates POSIX `wcwidth(3)` using Swift's built-in Unicode scalar
/// properties and a compact set of East Asian Width range checks.
func displayWidth(of character: Character) -> Int {
    // Use the first scalar to decide width — combining scalars that follow
    // do not add columns.
    guard let scalar = character.unicodeScalars.first else { return 0 }
    return displayWidth(of: scalar)
}

/// Returns the number of terminal columns a Unicode scalar occupies.
func displayWidth(of scalar: Unicode.Scalar) -> Int {
    let category = scalar.properties.generalCategory

    // Control characters (C0, DEL, C1) are non-printing.
    if category == .control { return 0 }

    // Zero-width characters (combining marks, format characters).
    if isZeroWidth(scalar, category: category) { return 0 }

    // East Asian Wide / Fullwidth characters occupy 2 columns.
    if isWide(scalar.value) { return 2 }

    return 1
}

// MARK: - Zero-width detection

/// Returns `true` for Unicode scalars that occupy zero terminal columns.
///
/// Uses Swift's `Unicode.Scalar.Properties` instead of manual hex ranges:
/// - **Combining marks** (`.nonspacingMark`, `.enclosingMark`): diacriticals,
///   variation selectors, combining half marks.
/// - **Default-ignorable format characters**: zero-width space, joiners,
///   word joiner, soft hyphen, BOM.
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

/// Returns `true` for East Asian Wide (W) and Fullwidth (F) characters that
/// occupy two terminal columns.
///
/// The ranges below are derived from Unicode 15.1 East Asian Width data and
/// match the behaviour of `wcwidth(3)` on modern systems. Swift's standard
/// library does not expose the East Asian Width property, so explicit range
/// checks are required here.
private func isWide(_ v: UInt32) -> Bool {
    // Hangul Jamo (initial consonants)
    if v >= 0x1100 && v <= 0x115F { return true }
    // Hangul Jamo Extended-B (final consonants, rare)
    if v >= 0xD7B0 && v <= 0xD7FF { return true }

    // CJK Radicals Supplement .. Enclosed CJK Letters and Months
    if v >= 0x2E80 && v <= 0x3247 { return true }
    // Enclosed CJK ideographs (parenthesised/circled) — subset that is wide
    if v >= 0x3250 && v <= 0x4DBF { return true }
    // CJK Unified Ideographs + Yi + Lisu + other blocks
    if v >= 0x4E00 && v <= 0xA4CF { return true }
    // Hangul Syllables
    if v >= 0xAC00 && v <= 0xD7A3 { return true }

    // CJK Compatibility Ideographs
    if v >= 0xF900 && v <= 0xFAFF { return true }
    // CJK Compatibility Forms + Small Form Variants
    if v >= 0xFE30 && v <= 0xFE6F { return true }
    // Fullwidth Latin letters, Fullwidth punctuation, Halfwidth Katakana etc.
    // Fullwidth forms: U+FF01..U+FF60  (letters, digits, punctuation)
    if v >= 0xFF01 && v <= 0xFF60 { return true }
    // Fullwidth cent/pound/yen/won signs
    if v >= 0xFFE0 && v <= 0xFFE6 { return true }

    // CJK Unified Ideographs Extension B..F and Supplement
    if v >= 0x20000 && v <= 0x2FFFD { return true }
    // CJK Unified Ideographs Extension G..I
    if v >= 0x30000 && v <= 0x3FFFD { return true }

    return false
}

// MARK: - Visible width measurement

/// Returns the number of visible terminal columns in a string, ignoring
/// ANSI escape sequences.
func visibleWidth(of string: String) -> Int {
    var width = 0
    var iter = string.unicodeScalars.makeIterator()

    while let scalar = iter.next() {
        // Detect the start of an ANSI escape sequence.
        if scalar == TerminalScalar.escape {
            guard let next = iter.next() else { break }
            if next == "[" {
                // CSI sequence: skip until final byte.
                skipCSI(&iter)
            } else if next == "]" {
                // OSC sequence: skip until ST or BEL.
                skipOSC(&iter)
            }
            // Other ESC sequences (e.g. SS3 "ESC O"): skip one byte.
            continue
        }
        width += displayWidth(of: scalar)
    }
    return width
}

// MARK: - ANSI-aware truncation

/// Truncate a string to at most `maxWidth` visible terminal columns,
/// preserving ANSI escape sequences and correctly measuring wide characters.
///
/// If a wide (2-column) character would push the visible width past
/// `maxWidth`, it is not included — the string is truncated just before it.
func truncateToVisibleWidth(_ string: String, maxWidth: Int) -> String {
    guard maxWidth > 0 else { return "" }

    var result = ""
    var width = 0
    var index = string.startIndex

    while index < string.endIndex {
        let char = string[index]

        // Check for ANSI escape sequences (start with ESC).
        if char.unicodeScalars.first == TerminalScalar.escape {
            let escEnd = skipANSISequence(in: string, from: index)
            // Append the entire escape sequence — it has zero visual width.
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

// MARK: - ANSI sequence skipping helpers

/// Advance the iterator past a CSI sequence (everything after `ESC[` up to
/// and including the final byte in `@`...`~`).
private func skipCSI(_ iter: inout String.UnicodeScalarView.Iterator) {
    while let s = iter.next() {
        if TerminalScalar.csiFinalRange.contains(s) { return }
    }
}

/// Advance the iterator past an OSC sequence (everything after `ESC]` up to
/// BEL or ST `ESC\`).
private func skipOSC(_ iter: inout String.UnicodeScalarView.Iterator) {
    while let s = iter.next() {
        if s == TerminalScalar.bel { return }
        if s == TerminalScalar.escape {
            // Possible ST (ESC + backslash)
            let _ = iter.next()
            return
        }
    }
}

/// Starting at `index` (which points to an ESC character), find the end of the
/// ANSI escape sequence and return the index *past* the sequence.
///
/// Handles CSI (`ESC[...`), OSC (`ESC]...`), and simple two-byte sequences.
private func skipANSISequence(in string: String, from start: String.Index) -> String.Index {
    var i = string.index(after: start) // skip ESC
    guard i < string.endIndex else { return i }

    let next = string[i]

    if next == "[" {
        // CSI: skip parameter/intermediate bytes until final byte (@...~).
        i = string.index(after: i)
        while i < string.endIndex {
            let scalar = string[i].unicodeScalars.first ?? "\0"
            i = string.index(after: i)
            if TerminalScalar.csiFinalRange.contains(scalar) { return i }
        }
        return i
    }

    if next == "]" {
        // OSC: skip until BEL or ST (ESC\).
        i = string.index(after: i)
        while i < string.endIndex {
            let scalar = string[i].unicodeScalars.first
            if scalar == TerminalScalar.bel {
                return string.index(after: i)
            }
            if scalar == TerminalScalar.escape {
                i = string.index(after: i) // skip ESC
                if i < string.endIndex {
                    i = string.index(after: i) // skip backslash
                }
                return i
            }
            i = string.index(after: i)
        }
        return i
    }

    // Simple two-byte escape (e.g. SS3 "ESC O x"): skip the next byte.
    return string.index(after: i)
}
