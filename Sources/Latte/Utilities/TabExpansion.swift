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
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    return lines.map { expandTabsInLine($0, tabWidth: effectiveTabWidth) }
        .joined(separator: "\n")
}

/// Expands tabs in a single line, tracking visible column position.
///
/// Iterates over grapheme clusters (via `String.Index`) to preserve
/// multi-scalar sequences such as emoji flags and ZWJ sequences.
/// ANSI escape sequences are detected by peeking at the first Unicode
/// scalar of each cluster and consumed verbatim via the scalar view.
private func expandTabsInLine(_ line: String, tabWidth: Int) -> String {
    var result = ""
    var column = 0
    var idx = line.startIndex

    while idx < line.endIndex {
        // Peek at the first Unicode scalar of the current grapheme cluster
        // to detect ANSI escape sequences and tab characters without
        // splitting the cluster.
        let firstScalar = line.unicodeScalars[idx]

        // Handle ANSI escape sequences — copy verbatim, don't advance column.
        if firstScalar == "\u{1B}" {
            var scalarSlice = line.unicodeScalars[idx...]
            let seq = consumeANSISequence(from: &scalarSlice)
            result += seq
            // scalarSlice.startIndex is a valid String.Index shared across views.
            idx = scalarSlice.startIndex
            continue
        }

        // Handle tab — replace with spaces to next tab stop.
        if firstScalar == "\t" {
            let spacesNeeded = tabWidth - (column % tabWidth)
            result += String(repeating: " ", count: spacesNeeded)
            column += spacesNeeded
            idx = line.index(after: idx)
            continue
        }

        // Regular character — use the full grapheme cluster so that
        // multi-scalar sequences (flags, combining marks, ZWJ emoji, …)
        // are preserved intact in the output and measured correctly.
        let char = line[idx]
        result.append(char)
        column += displayWidth(of: char)
        idx = line.index(after: idx)
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

// MARK: - String extension

extension String {
    /// Expands tab characters into spaces respecting column-aware tab stops.
    ///
    /// Wraps ``expandTabs(_:tabWidth:)``.
    public func tabsExpanded(tabWidth: Int = 4) -> String {
        expandTabs(self, tabWidth: tabWidth)
    }
}
