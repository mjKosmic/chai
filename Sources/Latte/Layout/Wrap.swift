/// Functions for word-wrapping text to a target column width.
///
/// Wrapping is ANSI-aware: escape sequences are preserved and do not count
/// toward visible width. When a styled run of text is split across lines,
/// active SGR styles are closed with a reset (`ESC[0m`) at the end of the
/// wrapped line and re-opened at the start of the next line.

// MARK: - wrap

/// Word-wraps a string to fit within `width` visible terminal columns.
///
/// Existing newlines are preserved — each input line is wrapped independently.
/// Lines that already fit within `width` are returned unchanged.
///
/// When a line exceeds `width`, the function breaks at the last occurrence of
/// `breakCharacter` before the overflow point. If no break character is found,
/// the line is hard-broken at the column limit.
///
/// ```swift
/// wrap("Hello, World! This is a test.", width: 14)
/// // "Hello, World!"
/// // "This is a"
/// // "test."
///
/// wrap("one-two-three-four", width: 8, breakCharacter: "-")
/// // "one-two"
/// // "three"
/// // "four"
/// ```
///
/// - Parameters:
///   - text: The string to wrap. May contain `\n`-separated lines and ANSI
///     escape sequences.
///   - width: The maximum number of visible columns per output line.
///   - breakCharacter: The character to break on. Defaults to `" "` (space).
///     When breaking at this character, the character itself is consumed
///     (removed from output) at the break point.
/// - Returns: The wrapped string, with lines joined by `\n`.
public func wrap(
    _ text: String,
    width: Int,
    breakCharacter: Character = " "
) -> String {
    guard width > 0 else { return "" }
    let lines = splitLines(text)
    return lines
        .map { wrapSingleLine($0, width: width, breakChar: breakCharacter) }
        .joined(separator: "\n")
}

// MARK: - Single-line wrapping

/// Wraps a single line (no embedded newlines) to `width` visible columns.
private func wrapSingleLine(
    _ line: String,
    width: Int,
    breakChar: Character
) -> String {
    guard visibleWidth(of: line) > width else { return line }

    let breakCharWidth = displayWidth(of: breakChar)
    var outputLines: [String] = []

    // Position tracking within the original `line` string.
    var segmentStart = line.startIndex  // start of the current output line's content
    var currentWidth = 0                // visible width accumulated for current output line

    // Break-point tracking: the most recent break character seen on this line.
    var lastBreak: String.Index? = nil
    var widthAtLastBreak = 0

    // ANSI SGR style tracking for carry-over across wrapped lines.
    var activeStyles: [String] = []
    var stylesAtSegmentStart: [String] = []
    var stylesAtLastBreak: [String] = []

    var i = line.startIndex
    while i < line.endIndex {
        let char = line[i]

        // ANSI escape sequences: skip and track SGR styles.
        if char.unicodeScalars.first == TerminalScalar.escape {
            let escEnd = skipANSISequence(in: line, from: i)
            let seq = String(line[i..<escEnd])
            trackSGR(&activeStyles, seq)
            i = escEnd
            continue
        }

        let cw = displayWidth(of: char)

        // Would this character push us past the width limit?
        if currentWidth + cw > width && currentWidth > 0 {
            if let bp = lastBreak {
                // Soft wrap: break at the last break character.
                let content = String(line[segmentStart..<bp])
                var wrappedLine = stylesAtSegmentStart.joined() + content
                if !stylesAtLastBreak.isEmpty {
                    wrappedLine += "\u{1B}[0m"
                }
                outputLines.append(wrappedLine)

                // The new segment starts after the break character.
                segmentStart = line.index(after: bp)
                stylesAtSegmentStart = stylesAtLastBreak
                currentWidth = currentWidth - widthAtLastBreak - breakCharWidth
                lastBreak = nil
            } else {
                // Hard wrap: no break character found on this line segment.
                let content = String(line[segmentStart..<i])
                var wrappedLine = stylesAtSegmentStart.joined() + content
                if !activeStyles.isEmpty {
                    wrappedLine += "\u{1B}[0m"
                }
                outputLines.append(wrappedLine)

                segmentStart = i
                stylesAtSegmentStart = activeStyles
                currentWidth = 0
            }
        }

        // Record break-character positions.
        if char == breakChar {
            lastBreak = i
            widthAtLastBreak = currentWidth
            stylesAtLastBreak = activeStyles
        }

        currentWidth += cw
        i = line.index(after: i)
    }

    // Flush the remaining content.
    if segmentStart < line.endIndex {
        let remainder = String(line[segmentStart...])
        let finalLine = stylesAtSegmentStart.joined() + remainder
        outputLines.append(finalLine)
    }

    return outputLines.joined(separator: "\n")
}

// MARK: - SGR style tracking

/// Updates the list of active SGR style sequences based on a new ANSI sequence.
///
/// Only CSI SGR sequences (`ESC[…m`) are tracked. A reset code (`0` or empty
/// parameters) clears all previously accumulated styles.
private func trackSGR(_ activeStyles: inout [String], _ sequence: String) {
    // Only track CSI SGR sequences: ESC [ <params> m
    guard sequence.hasPrefix("\u{1B}[") && sequence.hasSuffix("m") else { return }

    let params = sequence.dropFirst(2).dropLast() // strip "ESC[" and "m"

    // Check for reset: empty params (\e[m), bare zero (\e[0m),
    // or a compound sequence containing zero (\e[0;1m).
    let isReset = params.isEmpty
        || params == "0"
        || params.split(separator: ";").contains(where: { $0 == "0" })

    if isReset {
        activeStyles.removeAll()
    }

    // Accumulate non-bare-reset sequences. A compound like \e[0;1;31m is
    // kept verbatim — the terminal applies codes left-to-right, so the
    // reset happens first, then the styles are set.
    if !params.isEmpty && params != "0" {
        activeStyles.append(sequence)
    }
}
