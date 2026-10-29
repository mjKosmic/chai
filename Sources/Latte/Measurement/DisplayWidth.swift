// MARK: - Display width

/// Returns the number of terminal columns a single character occupies.
///
/// - East Asian wide / fullwidth characters return **2**.
/// - Zero-width characters (combining marks, zero-width space, etc.) return **0**.
/// - All other printable characters return **1**.
///
/// - Parameter character: The character to measure.
/// - Returns: The terminal column width: 0, 1, or 2.
func displayWidth(of character: Character) -> Int {
    guard let scalar = character.unicodeScalars.first else { return 0 }
    return displayWidth(of: scalar)
}

/// Returns the number of terminal columns a Unicode scalar occupies.
///
/// - Parameter scalar: The scalar to measure.
/// - Returns: The terminal column width: 0, 1, or 2.
func displayWidth(of scalar: Unicode.Scalar) -> Int {
    let category = scalar.properties.generalCategory
    if category == .control { return 0 }
    if isZeroWidth(scalar, category: category) { return 0 }
    if isWide(scalar.value) { return 2 }
    return 1
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
