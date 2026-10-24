// MARK: - Word wrapping (phase-3 A1)

// The A1 wrapping rules (UPGRADE.md "Phase 3 — Stage A") live here, in Chai,
// because they operate on Chai's ``StyledText`` segment model. Latte has its
// own string-level wrapper (`Sources/Latte/Layout/Wrap.swift`) that works on
// ANSI-embedded `String`s and resets/re-opens SGR styles across wrapped lines;
// the dependency direction (Latte imports Chai) forbids reusing it here.
// (The eager path retired in phase-4 P4b: `Wrap.swift` remains a public String
// utility for `String.wrapped()`, and the engine only uses this file.)

extension StyledText {
    /// Word-wraps this styled text to fit within `width` display columns,
    /// applying the phase-3 A1 pinned wrapping rules.
    ///
    /// ## Rules (pinned by `TextWrappingTests`)
    ///
    /// - Hard breaks: an explicit `\n` in the content is always honored and
    ///   resets the column; each hard line is wrapped independently.
    /// - Whitespace breaks: a space (or tab) is a break opportunity. When a
    ///   break happens at whitespace, the whitespace is **consumed** — it is
    ///   never carried to the next line's start. Interior whitespace runs are
    ///   preserved when no break happens at them.
    /// - Hyphen breaks: breaking is allowed *after* a hyphen; the hyphen stays
    ///   on the first line and nothing is inserted.
    /// - CJK: each CJK/wide character (display width 2) is its own break unit,
    ///   so a run of CJK characters wraps character-by-character whenever the
    ///   next character would overflow.
    /// - Char-level fallback: a non-CJK word (a run bounded by whitespace,
    ///   hyphens, or CJK characters) wider than `width` breaks
    ///   character-by-character (display-width aware), but only when it cannot
    ///   fit on the current line even after a break — i.e. the word alone
    ///   overflows `width`.
    /// - Greedy accumulation: characters accumulate into the current line
    ///   while they fit; the last break opportunity before the overflow
    ///   determines the break. Once a break has happened and the current line
    ///   is empty, a word wider than `width` immediately uses char-level
    ///   fallback.
    /// - Styles preserved exactly: when a break splits a segment, both parts
    ///   keep the segment's style; adjacent same-style characters coalesce
    ///   into one segment, but no style is ever invented or merged with a
    ///   different style.
    ///
    /// ## Degenerate proposals and content
    ///
    /// `width <= 0` returns the content **unchanged** (the caller treats a
    /// non-positive width context as unusable). A character wider than `width` on
    /// an empty line (a single CJK character at `width == 1`) is kept on its
    /// line anyway — the line overflows the available width and the buffer clips it.
    /// Content with no visible character (empty or whitespace-only, including
    /// newline-only content) wraps to an empty ``StyledText`` and measures
    /// 0×0, consistent with the existing empty-content semantics. Otherwise
    /// every hard line is preserved — including an explicit blank line from
    /// `\n\n` or a trailing `\n` — so a hard `\n` is always honored and the
    /// blank-line semantics match the unwrapped ideal (`lineCount()`).
    ///
    /// Measurement and allocation must resolve with this SAME function so the
    /// reported line count matches the painted rows — the phase-4 query is a
    /// pure report the allocator sizes rects from (see UPGRADE.md, "Phase 4").
    func wrappedToWidth(_ width: Int) -> StyledText {
        guard width > 0, !segments.isEmpty else { return self }

        // Whitespace-only (or newline-only) content has no visible rows: wrap
        // to empty and measure 0×0. This is the only case in which hard lines
        // are dropped — every hard line of content with a visible character is
        // preserved below.
        guard segments.contains(where: { segment in
            segment.text.contains { !isBreakWhitespace($0) && $0 != "\n" }
        }) else { return StyledText() }

        var wrappedLines: [[(Character, TextAttributes)]] = []

        // Split on hard newlines: `\n` is a hard break that always resets the
        // column; each hard line wraps independently. An empty hard line is
        // preserved as a blank output line (a hard `\n` is always honored).
        var hardLine: [(Character, TextAttributes)] = []
        for segment in segments {
            for char in segment.text {
                if char == "\n" {
                    wrapHardLine(hardLine, width: width, into: &wrappedLines)
                    hardLine = []
                } else {
                    hardLine.append((char, segment.style))
                }
            }
        }
        wrapHardLine(hardLine, width: width, into: &wrappedLines)

        var result = StyledText()
        for (lineIndex, line) in wrappedLines.enumerated() {
            if lineIndex > 0 { result.append("\n") }
            result += collapsedLine(line)
        }
        return result
    }
}

/// Wrap one hard line (no embedded `\n`) into one or more wrapped lines,
/// appending them to `lines`. An empty hard line (from `\n\n` or a trailing
/// `\n`) appends a single empty line, so hard breaks are honored exactly.
private func wrapHardLine(
    _ chars: [(Character, TextAttributes)],
    width: Int,
    into lines: inout [[(Character, TextAttributes)]]
) {
    // `cur` holds the committed content of the current line, EXCLUDING the
    // pending whitespace run (`pending`). Keeping the run separate is what
    // makes whitespace consumption at a break exact: a break opportunity at a
    // whitespace is recorded as "the line before the run", and taking the
    // break drops the run entirely — it never starts the next line (rules 1–2).
    var cur: [(Character, TextAttributes)] = []
    var curWidth = 0
    var pending: [(Character, TextAttributes)] = []
    var pendingWidth = 0
    // The last break opportunity: an index into `cur` (the line content up to
    // that point), plus whether the break is at whitespace (the run after the
    // index is consumed) or after a kept character (hyphen / CJK).
    var breakIndex: Int?
    var breakConsumes = false

    var index = 0
    while index < chars.count {
        let char = chars[index].0
        let style = chars[index].1
        let charWidth = displayWidth(of: char)

        if isBreakWhitespace(char) {
            pending.append((char, style))
            pendingWidth += charWidth
            if !cur.isEmpty {
                // Break opportunity at the current line boundary. A whitespace
                // run on an EMPTY line is not a usable break point — breaking
                // there would emit a spurious empty line for a hard line that
                // has content (blank lines come only from empty hard lines).
                breakIndex = cur.count
                breakConsumes = true
            }
            index += 1
            continue
        }

        let candidate = curWidth + pendingWidth + charWidth
        if candidate <= width || cur.isEmpty {
            // A leading whitespace run that cannot fit together with this
            // character is indentation, not content: drop it so a line never
            // exceeds `width` merely to carry whitespace, and no visible
            // character is pushed past the right edge. (Whitespace-only
            // content never reaches here — it wraps to empty before wrapping
            // begins; interior runs on a non-empty line are preserved.)
            if cur.isEmpty && pendingWidth > 0 && candidate > width {
                pending = []
                pendingWidth = 0
            }
            // The character fits on the current line — commit the pending
            // whitespace run and the character. When the line is empty the
            // character is placed even if it alone exceeds `width` (a CJK
            // character at width 1): degenerate — the line overflows the
            // available width and the buffer clips it (rule: CJK needs no fallback).
            if !pending.isEmpty {
                cur.append(contentsOf: pending)
                curWidth += pendingWidth
                pending = []
                pendingWidth = 0
            }
            cur.append((char, style))
            curWidth += charWidth
            if isHyphenBreak(char) || charWidth == 2 {
                // Hyphens and CJK/wide characters are break opportunities
                // after themselves: the character stays on the line.
                breakIndex = cur.count
                breakConsumes = false
            }
            index += 1
            continue
        }

        // Overflow: the character does not fit. The last break opportunity
        // before the overflow determines the break (rule 6).
        if let bIndex = breakIndex {
            // The line is everything up to the break opportunity; the
            // characters committed after it continue the next line.
            lines.append(Array(cur[0..<bIndex]))
            var remainder = Array(cur[bIndex...])
            if breakConsumes {
                // Whitespace break: consume the whitespace run the break
                // happened at — it must not start the next line (rules 1–2).
                while let first = remainder.first, isBreakWhitespace(first.0) {
                    remainder.removeFirst()
                }
            }
            cur = remainder
            curWidth = remainder.reduce(0) { $0 + displayWidth(of: $1.0) }
            pending = []
            pendingWidth = 0
            breakIndex = nil
            // Do NOT advance `index`: reprocess the overflowing character on
            // the fresh line.
        } else {
            // No usable break opportunity: hard-break at the overflow point.
            // `cur` is non-empty here (an empty line always takes the
            // character above). The line keeps its trailing pending whitespace
            // — it was never the site of a break.
            lines.append(cur + pending)
            cur = []
            curWidth = 0
            pending = []
            pendingWidth = 0
            breakIndex = nil
        }
    }

    // Flush the final line, preserving any trailing pending whitespace
    // (interior whitespace runs are preserved when no break happens at them)
    // — trimmed to what fits, so a trailing run cannot push the line past
    // `width`.
    lines.append(cur + fittedTrailingWhitespace(pending, curWidth: curWidth, width: width))
}

/// Keep only the leading portion of a trailing whitespace run that fits within
/// `width` after the visible content (`curWidth`). Trimming is display-width
/// aware; a run that fits entirely is preserved.
private func fittedTrailingWhitespace(
    _ pending: [(Character, TextAttributes)],
    curWidth: Int,
    width: Int
) -> [(Character, TextAttributes)] {
    var remaining = max(0, width - curWidth)
    var result: [(Character, TextAttributes)] = []
    for item in pending {
        let itemWidth = displayWidth(of: item.0)
        guard itemWidth <= remaining else { break }
        result.append(item)
        remaining -= itemWidth
    }
    return result
}

/// Collapse a wrapped line's per-character stream back into styled segments.
///
/// Adjacent characters with the same style coalesce into one segment. A
/// segment split across a break keeps its style on both parts — the wrapped
/// output is never re-styled and no style is ever merged with a different
/// style (rule 6).
private func collapsedLine(_ line: [(Character, TextAttributes)]) -> StyledText {
    var result = StyledText()
    var run = ""
    var runStyle = TextAttributes.default
    var hasRun = false
    for (char, style) in line {
        if hasRun && style != runStyle {
            result.append(run, style: runStyle)
            run = ""
        }
        run.append(char)
        runStyle = style
        hasRun = true
    }
    if hasRun {
        result.append(run, style: runStyle)
    }
    return result
}

/// Whether a character is break whitespace: a space or a tab (rule 2).
private func isBreakWhitespace(_ char: Character) -> Bool {
    char == " " || char == "\t"
}

/// Whether a character is a hyphen break opportunity (rule 3).
private func isHyphenBreak(_ char: Character) -> Bool {
    char == "-"
}
