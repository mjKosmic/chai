/// A composable terminal text style combining colors and attributes.
///
/// `Style` is a value type — mutating methods return a new copy, leaving
/// the original unchanged. Use the builder methods to construct styles:
///
/// ```swift
/// let warning = Style()
///     .foreground(.ansi(.yellow))
///     .bold()
///
/// let output = warning.render("Caution!")
/// // Produces: \e[33;1mCaution!\e[0m
/// ```
///
/// Styles can also be applied via the ``render(_:)`` method, which wraps
/// the given text in the appropriate ANSI escape sequences.
public struct Style: Sendable, Equatable {
    /// The foreground (text) color, or `nil` for the terminal default.
    public var foreground: Color?

    /// The background color, or `nil` for the terminal default.
    public var background: Color?

    /// Whether to render text in bold.
    public var isBold: Bool

    /// Whether to render text with reduced intensity.
    public var isDim: Bool

    /// Whether to render text in italic.
    public var isItalic: Bool

    /// Whether to render text with an underline.
    public var isUnderline: Bool

    /// Whether to render text with a strikethrough.
    public var isStrikethrough: Bool

    /// Whether to swap foreground and background colors.
    public var isReverse: Bool

    /// Whether to render blinking text (support varies by terminal).
    public var isBlink: Bool

    // MARK: - Initializer

    /// Creates a style with no attributes or colors set.
    public init(
        foreground: Color? = nil,
        background: Color? = nil,
        isBold: Bool = false,
        isDim: Bool = false,
        isItalic: Bool = false,
        isUnderline: Bool = false,
        isStrikethrough: Bool = false,
        isReverse: Bool = false,
        isBlink: Bool = false
    ) {
        self.foreground = foreground
        self.background = background
        self.isBold = isBold
        self.isDim = isDim
        self.isItalic = isItalic
        self.isUnderline = isUnderline
        self.isStrikethrough = isStrikethrough
        self.isReverse = isReverse
        self.isBlink = isBlink
    }

    // MARK: - Builder methods

    /// Returns a copy with the foreground color set.
    public func foreground(_ color: Color) -> Style {
        var copy = self
        copy.foreground = color
        return copy
    }

    /// Returns a copy with the background color set.
    public func background(_ color: Color) -> Style {
        var copy = self
        copy.background = color
        return copy
    }

    /// Returns a copy with bold enabled.
    public func bold() -> Style {
        var copy = self
        copy.isBold = true
        return copy
    }

    /// Returns a copy with dim enabled.
    public func dim() -> Style {
        var copy = self
        copy.isDim = true
        return copy
    }

    /// Returns a copy with italic enabled.
    public func italic() -> Style {
        var copy = self
        copy.isItalic = true
        return copy
    }

    /// Returns a copy with underline enabled.
    public func underline() -> Style {
        var copy = self
        copy.isUnderline = true
        return copy
    }

    /// Returns a copy with strikethrough enabled.
    public func strikethrough() -> Style {
        var copy = self
        copy.isStrikethrough = true
        return copy
    }

    /// Returns a copy with reverse video enabled.
    public func reverse() -> Style {
        var copy = self
        copy.isReverse = true
        return copy
    }

    /// Returns a copy with blink enabled.
    public func blink() -> Style {
        var copy = self
        copy.isBlink = true
        return copy
    }

    // MARK: - Rendering

    /// Wraps the given text in ANSI escape sequences for this style.
    ///
    /// If no attributes or colors are set, returns the text unchanged.
    ///
    /// - Parameter text: The string to style.
    /// - Returns: The styled string with ANSI escape codes.
    public func render(_ text: String) -> String {
        let params = sgrParameters()
        if params.isEmpty {
            return text
        }
        let sequence = params.joined(separator: ";")
        return "\u{1B}[\(sequence)m\(text)\u{1B}[0m"
    }

    /// Whether this style has any attributes or colors set.
    public var isEmpty: Bool {
        foreground == nil
            && background == nil
            && !isBold && !isDim && !isItalic && !isUnderline
            && !isStrikethrough && !isReverse && !isBlink
    }

    // MARK: - Internal

    /// Collects the SGR parameter codes for all enabled attributes and colors.
    private func sgrParameters() -> [String] {
        var params: [String] = []

        if let fg = foreground {
            params.append(fg.fgCode)
        }
        if let bg = background {
            params.append(bg.bgCode)
        }
        if isBold { params.append("1") }
        if isDim { params.append("2") }
        if isItalic { params.append("3") }
        if isUnderline { params.append("4") }
        if isBlink { params.append("5") }
        if isReverse { params.append("7") }
        if isStrikethrough { params.append("9") }

        return params
    }
}
