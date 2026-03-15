/// Expands tab characters into spaces, respecting column-aware tab stops.
///
/// Each `\t` is replaced with enough spaces to advance to the next tab stop.
/// Tab stops occur at every `tabWidth` columns (0, 4, 8, 12, … for the
/// default width of 4). This means a tab at column 1 inserts 3 spaces
/// (advancing to column 4), while a tab at column 0 inserts 4.
///
/// ANSI escape sequences are preserved and do not affect column tracking,
/// so styled text is handled correctly.
///
/// Each line's tab stops are independent — a newline resets the column to 0.
///
/// ```swift
/// expandTabs("\tHello")
/// // "    Hello"          — tab at col 0 → 4 spaces
///
/// expandTabs("ab\tcd")
/// // "ab  cd"             — tab at col 2 → 2 spaces (next stop at 4)
///
/// expandTabs("ab\tcd", tabWidth: 8)
/// // "ab      cd"         — tab at col 2 → 6 spaces (next stop at 8)
/// ```
///
/// - Parameters:
///   - text: The string to process. May contain `\n`-separated lines.
///   - tabWidth: The number of columns between tab stops. Defaults to `4`.
///              Values less than 1 are treated as 1.
/// - Returns: The string with all tabs replaced by the appropriate number of spaces.
public func expandTabs(_ text: String, tabWidth: Int = 4) -> String {
    let effectiveTabWidth = max(1, tabWidth)
    let lines = splitLines(text)
    return lines.map { expandTabsInLine($0, tabWidth: effectiveTabWidth) }
        .joined(separator: "\n")
}

/// Expands tabs in a single line, tracking visible column position.
private func expandTabsInLine(_ line: String, tabWidth: Int) -> String {
    var result = ""
    var column = 0
    var scalars = line.unicodeScalars[...]

    while let scalar = scalars.first {
        // Handle ANSI escape sequences — copy verbatim, don't advance column.
        if scalar == "\u{1B}" {
            let seq = consumeANSISequence(from: &scalars)
            result += seq
            continue
        }

        // Handle tab — replace with spaces to next tab stop.
        if scalar == "\t" {
            let spacesNeeded = tabWidth - (column % tabWidth)
            result += String(repeating: " ", count: spacesNeeded)
            column += spacesNeeded
            scalars = scalars.dropFirst()
            continue
        }

        // Regular character — append and advance column by display width.
        let char = Character(scalar)
        result.append(char)
        column += displayWidth(of: char)
        scalars = scalars.dropFirst()
    }

    return result
}

/// Consumes a complete ANSI escape sequence from the front of `scalars`
/// and returns it as a String.
private func consumeANSISequence(
    from scalars: inout Substring.UnicodeScalarView
) -> String {
    var seq = String(scalars.first!)  // ESC
    scalars = scalars.dropFirst()

    guard let next = scalars.first else { return seq }
    seq.unicodeScalars.append(next)
    scalars = scalars.dropFirst()

    switch next {
    case "[":
        // CSI sequence: consume until final byte in @–~
        let finalRange = Unicode.Scalar("@")...Unicode.Scalar("~")
        while let s = scalars.first {
            seq.unicodeScalars.append(s)
            scalars = scalars.dropFirst()
            if finalRange.contains(s) { break }
        }
    case "]":
        // OSC sequence: consume until BEL or ESC\
        while let s = scalars.first {
            seq.unicodeScalars.append(s)
            scalars = scalars.dropFirst()
            if s == "\u{07}" { break }
            if s == "\u{1B}" {
                if let next = scalars.first, next == "\\" {
                    seq.unicodeScalars.append(next)
                    scalars = scalars.dropFirst()
                    break
                }
            }
        }
    case "O", "N":
        // SS3 / SS2: consume one more byte
        if let s = scalars.first {
            seq.unicodeScalars.append(s)
            scalars = scalars.dropFirst()
        }
    default:
        break  // Two-byte escape: already consumed
    }

    return seq
}
