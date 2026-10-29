// MARK: - Line type

extension StyledText {

    /// A single line of styled text, represented as an array of segments.
    /// No segment contains `\n`.
    struct Line {
        var segments: [Segment]

        /// The display-column width of this line.
        var columnWidth: Int {
            var width = 0
            for segment in segments {
                for char in segment.text {
                    width += displayWidth(of: char)
                }
            }
            return width
        }

        /// An empty line.
        static let empty = Line(segments: [])
    }
}

// MARK: - Line splitting and reconstruction

extension StyledText {

    /// Split this StyledText into lines at `\n` boundaries.
    ///
    /// Each returned ``Line`` contains segments with no newline characters.
    /// A segment that spans multiple lines is split into separate segments
    /// distributed across the appropriate lines.
    func splitLines() -> [Line] {
        guard !segments.isEmpty else { return [.empty] }

        var lines: [Line] = [Line(segments: [])]

        for segment in segments {
            let parts = segment.text.split(separator: "\n", omittingEmptySubsequences: false)
            for (i, part) in parts.enumerated() {
                if i > 0 {
                    lines.append(Line(segments: []))
                }
                let text = String(part)
                if !text.isEmpty {
                    lines[lines.count - 1].segments.append(Segment(text, style: segment.style))
                }
            }
        }

        return lines
    }

    /// Reconstruct a StyledText from an array of lines, joining with `\n`.
    static func fromLines(_ lines: [Line]) -> StyledText {
        guard !lines.isEmpty else { return StyledText() }

        var result = StyledText()
        for (i, line) in lines.enumerated() {
            if i > 0 {
                result.append("\n")
            }
            result.segments.append(contentsOf: line.segments)
        }
        return result
    }
}

// MARK: - Line-level truncation

extension StyledText.Line {

    /// Truncate this line to at most `maxWidth` display columns.
    ///
    /// A wide character that would straddle the boundary is dropped whole, so
    /// the result never contains half a glyph.
    func truncated(toWidth maxWidth: Int) -> StyledText.Line {
        guard maxWidth > 0 else { return .empty }
        guard columnWidth > maxWidth else { return self }

        var remaining = maxWidth
        var result: [StyledText.Segment] = []

        for segment in segments {
            if remaining <= 0 { break }

            var truncatedText = ""
            for char in segment.text {
                let w = displayWidth(of: char)
                if w > remaining { break }
                truncatedText.append(char)
                remaining -= w
            }

            if !truncatedText.isEmpty {
                result.append(StyledText.Segment(truncatedText, style: segment.style))
            }
        }

        return StyledText.Line(segments: result)
    }
}

// MARK: - Raster clamping

extension StyledText {

    /// Truncate each line to at most `maxWidth` display columns.
    func clampWidth(_ maxWidth: Int) -> StyledText {
        let lines = splitLines().map { $0.truncated(toWidth: maxWidth) }
        return StyledText.fromLines(lines)
    }

    /// Keep only the first `maxHeight` lines.
    func clampHeight(_ maxHeight: Int) -> StyledText {
        guard maxHeight > 0 else { return StyledText() }
        let lines = splitLines()
        guard lines.count > maxHeight else { return self }
        return StyledText.fromLines(Array(lines.prefix(maxHeight)))
    }
}
