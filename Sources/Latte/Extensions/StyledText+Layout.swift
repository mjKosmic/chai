import Chai

/// Internal layout primitives for spatial manipulation of ``StyledText``.
///
/// These helpers support Latte's raster-level layout operations: the
/// `String`/`StyledText` extensions and the ``ViewOutput`` clamping helpers.
/// They are not part of the public API.

// MARK: - Line type

extension StyledText {

    /// A single line of styled text, represented as an array of segments.
    /// None of the segments contain `\n`.
    struct Line {
        var segments: [Segment]

        var isEmpty: Bool {
            segments.allSatisfy { $0.text.isEmpty }
        }

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

// MARK: - Line-level operations

extension StyledText.Line {

    /// Pad this line on the right with spaces to reach `targetWidth` columns.
    func paddedRight(toWidth targetWidth: Int) -> StyledText.Line {
        let shortage = targetWidth - columnWidth
        guard shortage > 0 else { return self }
        var copy = self
        copy.segments.append(StyledText.Segment(String(repeating: " ", count: shortage)))
        return copy
    }

    /// Align this line within `targetWidth` columns using the given alignment.
    func aligned(toWidth targetWidth: Int, _ alignment: HorizontalAlignment) -> StyledText.Line {
        let shortage = max(0, targetWidth - columnWidth)
        guard shortage > 0 else { return self }

        let leftPad = Int(Double(shortage) * alignment.fraction)
        let rightPad = shortage - leftPad

        var copy = self
        if leftPad > 0 {
            copy.segments.insert(StyledText.Segment(String(repeating: " ", count: leftPad)), at: 0)
        }
        if rightPad > 0 {
            copy.segments.append(StyledText.Segment(String(repeating: " ", count: rightPad)))
        }
        return copy
    }

    /// Truncate this line to at most `maxWidth` display columns.
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

// MARK: - StyledText spatial operations

extension StyledText {

    /// Enforce a minimum width: pad each line to `targetWidth` columns.
    func enforceWidth(_ targetWidth: Int, alignment: HorizontalAlignment = .left) -> StyledText {
        let lines = splitLines().map { $0.aligned(toWidth: targetWidth, alignment) }
        return StyledText.fromLines(lines)
    }

    /// Enforce a minimum height: add blank lines to reach `targetHeight`.
    func enforceHeight(_ targetHeight: Int, alignment: VerticalAlignment = .top) -> StyledText {
        var lines = splitLines()
        let shortage = max(0, targetHeight - lines.count)
        guard shortage > 0 else { return self }

        let topPad = Int(Double(shortage) * alignment.fraction)
        let bottomPad = shortage - topPad

        let contentWidth = lines.map(\.columnWidth).max() ?? 0
        let blankLine: Line
        if contentWidth > 0 {
            blankLine = Line(segments: [Segment(String(repeating: " ", count: contentWidth))])
        } else {
            blankLine = .empty
        }

        lines = Array(repeating: blankLine, count: topPad)
            + lines
            + Array(repeating: blankLine, count: bottomPad)

        return StyledText.fromLines(lines)
    }

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

    /// Pad content with blank space on all sides.
    func pad(top: Int = 0, right: Int = 0, bottom: Int = 0, left: Int = 0) -> StyledText {
        var lines = splitLines()
        let contentWidth = lines.map(\.columnWidth).max() ?? 0
        let totalWidth = contentWidth + left + right

        // Pad each content line with left/right spacing.
        if left > 0 || right > 0 {
            lines = lines.map { line in
                var padded = line.paddedRight(toWidth: contentWidth)
                if left > 0 {
                    padded.segments.insert(Segment(String(repeating: " ", count: left)), at: 0)
                }
                if right > 0 {
                    padded.segments.append(Segment(String(repeating: " ", count: right)))
                }
                return padded
            }
        }

        let blankLine = Line(segments: totalWidth > 0
            ? [Segment(String(repeating: " ", count: totalWidth))]
            : [])

        lines = Array(repeating: blankLine, count: top)
            + lines
            + Array(repeating: blankLine, count: bottom)

        return StyledText.fromLines(lines)
    }

    /// Draw a border around this content.
    func bordered(_ border: Border) -> StyledText {
        var lines = splitLines()
        let contentWidth = lines.map(\.columnWidth).max() ?? 0

        // Normalize all lines to the same width.
        lines = lines.map { $0.paddedRight(toWidth: contentWidth) }

        let topEdge = Line(segments: [
            Segment(border.topLeft + String(repeating: border.top, count: contentWidth) + border.topRight)
        ])

        let bottomEdge = Line(segments: [
            Segment(border.bottomLeft + String(repeating: border.bottom, count: contentWidth) + border.bottomRight)
        ])

        let wrappedLines = lines.map { line -> Line in
            var result = Line(segments: [])
            result.segments.append(Segment(border.left))
            result.segments.append(contentsOf: line.segments)
            result.segments.append(Segment(border.right))
            return result
        }

        return StyledText.fromLines([topEdge] + wrappedLines + [bottomEdge])
    }

    /// Join this StyledText beside another horizontally.
    func beside(_ other: StyledText, align: VerticalAlignment = .top) -> StyledText {
        var leftLines = splitLines()
        var rightLines = other.splitLines()

        let leftWidth = leftLines.map(\.columnWidth).max() ?? 0
        let maxHeight = max(leftLines.count, rightLines.count)

        // Pad left lines to uniform width.
        leftLines = leftLines.map { $0.paddedRight(toWidth: leftWidth) }

        // Extend shorter side to match height.
        let leftBlank = Line(segments: leftWidth > 0
            ? [Segment(String(repeating: " ", count: leftWidth))]
            : [])

        leftLines = Self.extendLines(leftLines, to: maxHeight, blank: leftBlank, alignment: align)
        rightLines = Self.extendLines(rightLines, to: maxHeight, blank: .empty, alignment: align)

        // Concatenate each row.
        var resultLines: [Line] = []
        for i in 0..<maxHeight {
            var combined = Line(segments: [])
            combined.segments.append(contentsOf: leftLines[i].segments)
            combined.segments.append(contentsOf: rightLines[i].segments)
            resultLines.append(combined)
        }

        return StyledText.fromLines(resultLines)
    }

    /// Stack this StyledText above another vertically.
    func above(_ other: StyledText, align: HorizontalAlignment = .left) -> StyledText {
        var topLines = splitLines()
        var bottomLines = other.splitLines()

        let maxWidth = max(
            topLines.map(\.columnWidth).max() ?? 0,
            bottomLines.map(\.columnWidth).max() ?? 0
        )

        topLines = topLines.map { $0.aligned(toWidth: maxWidth, align) }
        bottomLines = bottomLines.map { $0.aligned(toWidth: maxWidth, align) }

        return StyledText.fromLines(topLines + bottomLines)
    }

    /// Extend an array of lines to `targetCount` by inserting blank lines
    /// according to the vertical alignment.
    private static func extendLines(
        _ lines: [Line],
        to targetCount: Int,
        blank: Line,
        alignment: VerticalAlignment
    ) -> [Line] {
        let shortage = max(0, targetCount - lines.count)
        guard shortage > 0 else { return lines }

        let topPad = Int(Double(shortage) * alignment.fraction)
        let bottomPad = shortage - topPad

        return Array(repeating: blank, count: topPad)
            + lines
            + Array(repeating: blank, count: bottomPad)
    }
}
