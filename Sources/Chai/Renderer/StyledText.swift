// MARK: - StyledText

/// Text divided into segments, each with its own style.
///
/// Replaces raw strings with embedded ANSI codes. Conforms to
/// `ExpressibleByStringLiteral` (plain text, default style) and
/// `ExpressibleByStringInterpolation` (mix styled and plain segments).
public struct StyledText: Sendable, Equatable {

    /// Individual styled text segments.
    public var segments: [Segment]

    /// A contiguous text span with uniform styling.
    public struct Segment: Sendable, Equatable {
        public var text: String
        public var style: TextAttributes

        public init(_ text: String, style: TextAttributes = .default) {
            self.text = text
            self.style = style
        }
    }

    /// Create empty styled text.
    public init() {
        self.segments = []
    }

    /// Create styled text from a single string and style.
    public init(_ text: String, style: TextAttributes = .default) {
        self.segments = text.isEmpty ? [] : [Segment(text, style: style)]
    }

    /// Append a segment.
    public mutating func append(_ text: String, style: TextAttributes = .default) {
        guard !text.isEmpty else { return }
        segments.append(Segment(text, style: style))
    }

    /// The concatenated plain text of all segments, without styling.
    public var plainText: String {
        segments.map(\.text).joined()
    }

    /// Whether this styled text contains no visible content.
    public var isEmpty: Bool {
        segments.allSatisfy { $0.text.isEmpty }
    }

    /// Count lines (number of \n characters + 1, or 0 if empty).
    public func lineCount() -> Int {
        if isEmpty { return 0 }
        var count = 1
        for segment in segments {
            for char in segment.text where char == "\n" {
                count += 1
            }
        }
        return count
    }

    /// The total display-column width of all segments, measured using
    /// terminal display widths (wide characters count as 2, zero-width as 0).
    ///
    /// Unlike `plainText.count`, this correctly handles CJK / emoji / wide characters.
    public var columnWidth: Int {
        var width = 0
        for segment in segments {
            for char in segment.text {
                width += displayWidth(of: char)
            }
        }
        return width
    }

    /// The maximum display-column width across all lines.
    ///
    /// Lines are delimited by `\n`. Each line's width is the sum of its
    /// characters' display widths, so CJK / emoji / wide characters count as
    /// 2 columns and zero-width characters as 0. Empty content measures 0.
    internal var maxLineWidth: Int {
        var maxWidth = 0
        var currentWidth = 0
        for segment in segments {
            for char in segment.text {
                if char == "\n" {
                    maxWidth = max(maxWidth, currentWidth)
                    currentWidth = 0
                } else {
                    currentWidth += displayWidth(of: char)
                }
            }
        }
        return max(maxWidth, currentWidth)
    }

    /// Concatenate two StyledText values.
    public static func + (lhs: StyledText, rhs: StyledText) -> StyledText {
        var result = lhs
        result.segments.append(contentsOf: rhs.segments)
        return result
    }

    /// Append another StyledText in place.
    public static func += (lhs: inout StyledText, rhs: StyledText) {
        lhs.segments.append(contentsOf: rhs.segments)
    }
}

// MARK: - ExpressibleByStringLiteral

extension StyledText: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) {
        self.init(value)
    }
}

// MARK: - ExpressibleByStringInterpolation

extension StyledText: ExpressibleByStringInterpolation {

    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        var result: StyledText

        public init(literalCapacity: Int, interpolationCount: Int) {
            result = StyledText()
            result.segments.reserveCapacity(interpolationCount + 1)
        }

        public mutating func appendLiteral(_ literal: String) {
            guard !literal.isEmpty else { return }
            result.segments.append(Segment(literal, style: .default))
        }

        public mutating func appendInterpolation(_ value: StyledText) {
            result.segments.append(contentsOf: value.segments)
        }

        public mutating func appendInterpolation(_ value: String) {
            guard !value.isEmpty else { return }
            result.segments.append(Segment(value, style: .default))
        }

        public mutating func appendInterpolation<T: CustomStringConvertible>(_ value: T) {
            let str = String(describing: value)
            guard !str.isEmpty else { return }
            result.segments.append(Segment(str, style: .default))
        }

        public mutating func appendInterpolation(_ value: String, style: TextAttributes) {
            guard !value.isEmpty else { return }
            result.segments.append(Segment(value, style: style))
        }

        public mutating func appendInterpolation(_ value: String, _ color: CellColor) {
            guard !value.isEmpty else { return }
            result.segments.append(Segment(value, style: TextAttributes(foreground: color)))
        }
    }

    public init(stringInterpolation: StringInterpolation) {
        self = stringInterpolation.result
    }
}

// MARK: - String styling extensions

extension String {
    /// Wrap this string in a StyledText with the given style.
    public func styled(_ style: TextAttributes) -> StyledText {
        StyledText(self, style: style)
    }

    /// Wrap this string in a StyledText with the given foreground color.
    public func fg(_ color: CellColor) -> StyledText {
        StyledText(self, style: TextAttributes(foreground: color))
    }

    /// Wrap this string in a StyledText with the given background color.
    public func bg(_ color: CellColor) -> StyledText {
        StyledText(self, style: TextAttributes(background: color))
    }

    /// Wrap this string in a bold StyledText.
    public func bold() -> StyledText {
        StyledText(self, style: TextAttributes(attributes: [.bold]))
    }

    /// Wrap this string in an italic StyledText.
    public func italic() -> StyledText {
        StyledText(self, style: TextAttributes(attributes: [.italic]))
    }

    /// Wrap this string in an underlined StyledText.
    public func underline() -> StyledText {
        StyledText(self, style: TextAttributes(attributes: [.underline]))
    }

    /// Wrap this string in a dim StyledText.
    public func dim() -> StyledText {
        StyledText(self, style: TextAttributes(attributes: [.dim]))
    }

    /// Wrap this string in a strikethrough StyledText.
    public func strikethrough() -> StyledText {
        StyledText(self, style: TextAttributes(attributes: [.strikethrough]))
    }
}

// MARK: - StyledText styling extensions (for chaining)

extension StyledText {
    /// Apply a style to all segments.
    public func styled(_ style: TextAttributes) -> StyledText {
        var copy = self
        copy.segments = copy.segments.map { seg in
            var merged = seg.style
            if style.foreground != nil { merged.foreground = style.foreground }
            if style.background != nil { merged.background = style.background }
            if !style.attributes.isEmpty { merged.attributes.formUnion(style.attributes) }
            if style.hyperlink != nil { merged.hyperlink = style.hyperlink }
            return Segment(seg.text, style: merged)
        }
        return copy
    }

    /// Apply a foreground color to all segments.
    public func fg(_ color: CellColor) -> StyledText {
        styled(TextAttributes(foreground: color))
    }

    /// Apply a background color to all segments.
    public func bg(_ color: CellColor) -> StyledText {
        styled(TextAttributes(background: color))
    }

    /// Apply bold to all segments.
    public func bold() -> StyledText {
        styled(TextAttributes(attributes: [.bold]))
    }

    /// Apply italic to all segments.
    public func italic() -> StyledText {
        styled(TextAttributes(attributes: [.italic]))
    }

    /// Apply underline to all segments.
    public func underline() -> StyledText {
        styled(TextAttributes(attributes: [.underline]))
    }

    /// Apply dim to all segments.
    public func dim() -> StyledText {
        styled(TextAttributes(attributes: [.dim]))
    }

    /// Apply strikethrough to all segments.
    public func strikethrough() -> StyledText {
        styled(TextAttributes(attributes: [.strikethrough]))
    }
}

// MARK: - Array joining

extension Array where Element == StyledText {
    /// Join an array of StyledText with a separator.
    public func joined(separator: StyledText = StyledText("\n")) -> StyledText {
        guard !isEmpty else { return StyledText() }
        var result = self[0]
        for element in self.dropFirst() {
            result = result + separator + element
        }
        return result
    }
}
