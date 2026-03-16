// MARK: - UnderlineStyle

/// Underline style variants for terminal text.
///
/// Extended underline styles (`curly`, `dotted`, `dashed`) use SGR 4:n
/// subparameter syntax and are supported in Kitty, WezTerm, iTerm2, and VTE.
/// `double` uses SGR 21 and is supported in most modern terminals.
/// `single` uses the traditional SGR 4 and is universally supported.
public enum UnderlineStyle: Sendable, Equatable {
    /// No underline (default).
    case none
    /// Single underline — SGR 4, widely supported.
    case single
    /// Double underline — SGR 21, supported in most modern terminals.
    case double
    /// Curly (wavy) underline — SGR 4:3, Kitty, WezTerm, iTerm2, VTE.
    case curly
    /// Dotted underline — SGR 4:4, Kitty, WezTerm, iTerm2, VTE.
    case dotted
    /// Dashed underline — SGR 4:5, Kitty, WezTerm, iTerm2, VTE.
    case dashed

    /// The SGR parameter string for this underline style, or `nil` for `.none`.
    var sgrCode: String? {
        switch self {
        case .none:   return nil
        case .single: return "4"
        case .double: return "21"
        case .curly:  return "4:3"
        case .dotted: return "4:4"
        case .dashed: return "4:5"
        }
    }
}

// MARK: - Style

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

    /// The underline style to apply. Defaults to `.none`.
    ///
    /// For a simple single underline, prefer the ``underline()`` builder or set
    /// ``isUnderline`` to `true` — both map to `UnderlineStyle.single`.
    public var underlineStyle: UnderlineStyle

    /// Whether to render text with a single underline.
    ///
    /// This is a compatibility shim backed by ``underlineStyle``:
    /// - Getting: returns `true` only when `underlineStyle == .single`.
    /// - Setting `true`: equivalent to `underlineStyle = .single`.
    /// - Setting `false`: equivalent to `underlineStyle = .none`.
    ///
    /// For extended underline styles (curly, dotted, dashed), set
    /// ``underlineStyle`` directly or use the ``underlineStyle(_:)`` builder.
    public var isUnderline: Bool {
        get { underlineStyle == .single }
        set { underlineStyle = newValue ? .single : .none }
    }

    /// The color of the underline, independent of the foreground color.
    ///
    /// Emits SGR 58 (underline color). Only meaningful when ``underlineStyle``
    /// is not `.none`. When `nil` (the default), the underline uses the
    /// foreground color.
    public var underlineColor: Color?

    /// Whether to render text with a strikethrough.
    public var isStrikethrough: Bool

    /// Whether to swap foreground and background colors.
    public var isReverse: Bool

    /// Whether to render blinking text (support varies by terminal).
    public var isBlink: Bool

    /// An optional URL to wrap rendered text in an OSC 8 hyperlink sequence.
    ///
    /// Terminals that do not support OSC 8 silently ignore the sequences —
    /// the visible text is still displayed, so degradation is graceful.
    /// Hyperlink sequences are omitted when rendering at `.noColor` profile
    /// (non-TTY output).
    public var hyperlink: String?

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
        self.underlineStyle = isUnderline ? .single : .none
        self.underlineColor = nil
        self.isStrikethrough = isStrikethrough
        self.isReverse = isReverse
        self.isBlink = isBlink
        self.hyperlink = nil
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

    /// Returns a copy with single underline enabled.
    ///
    /// This is the backward-compatible builder for `isUnderline`. It is
    /// equivalent to `.underlineStyle(.single)`.
    public func underline() -> Style {
        var copy = self
        copy.underlineStyle = .single
        return copy
    }

    /// Returns a copy with the given underline style applied.
    public func underlineStyle(_ style: UnderlineStyle) -> Style {
        var copy = self
        copy.underlineStyle = style
        return copy
    }

    /// Returns a copy with the underline color set.
    ///
    /// Emits SGR 58 (underline color). Only meaningful when an underline
    /// style is also set. This color is independent of the foreground color.
    public func underlineColor(_ color: Color) -> Style {
        var copy = self
        copy.underlineColor = color
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

    /// Returns a copy with an OSC 8 hyperlink URL set.
    ///
    /// The rendered text will be wrapped in OSC 8 sequences:
    /// `ESC]8;;<url>ESC\\<styled-text>ESC]8;;ESC\\`
    ///
    /// Terminals that do not support OSC 8 ignore the sequences and display
    /// the visible text only. Hyperlinks are omitted when rendering at the
    /// `.noColor` profile.
    ///
    /// - Parameter url: The target URL for the hyperlink.
    public func hyperlink(_ url: String) -> Style {
        var copy = self
        copy.hyperlink = url
        return copy
    }

    // MARK: - Rendering

    /// Wraps the given text in ANSI escape sequences for this style.
    ///
    /// Colors are automatically downsampled to match the given terminal
    /// ``ColorProfile``. When `profile` is ``ColorProfile/noColor``, all
    /// styling is stripped and the raw text is returned (hyperlinks are also
    /// omitted, since non-TTY output should not contain escape sequences).
    ///
    /// The default profile of ``ColorProfile/trueColor`` preserves full
    /// backward compatibility — existing callers that omit `profile` get
    /// identical output to the previous API.
    ///
    /// ```swift
    /// let style = Style().foreground(.trueColor(r: 255, g: 100, b: 50)).bold()
    ///
    /// // Full color (default)
    /// style.render("Warning!")
    ///
    /// // Auto-detect terminal capability and downsample colors automatically
    /// let profile = ColorProfile.detect()
    /// style.render("Warning!", profile: profile)
    ///
    /// // Force plain text (e.g. for file output)
    /// style.render("Warning!", profile: .noColor)  // "Warning!"
    /// ```
    ///
    /// - Parameters:
    ///   - text: The string to style.
    ///   - profile: The terminal color profile to target. Defaults to
    ///     ``ColorProfile/trueColor``.
    /// - Returns: The styled string with ANSI escape codes, or the raw text
    ///   when the profile is ``ColorProfile/noColor``.
    public func render(_ text: String, profile: ColorProfile = .trueColor) -> String {
        if profile == .noColor { return text }

        let params = sgrParameters(profile: profile)
        let styled: String
        if params.isEmpty {
            styled = text
        } else {
            let sequence = params.joined(separator: ";")
            styled = "\u{1B}[\(sequence)m\(text)\u{1B}[0m"
        }

        guard let url = hyperlink else { return styled }
        // OSC 8 hyperlink: ESC]8;;<url>ST<styled-text>ESC]8;;ST
        // where ST (String Terminator) = ESC\
        let st = "\u{1B}\\"
        return "\u{1B}]8;;\(url)\(st)\(styled)\u{1B}]8;;\(st)"
    }

    /// Wraps the given text in ANSI escape sequences for this style using the
    /// full ``ColorProfile/trueColor`` profile.
    ///
    /// This overload exists so that `style.render` can be used directly as a
    /// `(String) -> String` closure — for example, as a border styling function:
    ///
    /// ```swift
    /// import Spices
    /// import Latte
    ///
    /// let cyan = Style().foreground(.ansi(.cyan))
    /// border("Hello", .rounded, borderStyle: cyan.render)
    /// ```
    ///
    /// It is equivalent to calling `render(_:profile:)` with the default
    /// ``ColorProfile/trueColor`` profile.
    ///
    /// - Parameter text: The string to style.
    /// - Returns: The styled string with ANSI escape codes.
    public func render(_ text: String) -> String {
        render(text, profile: .trueColor)
    }

    /// Whether this style has any attributes or colors set.
    public var isEmpty: Bool {
        foreground == nil
            && background == nil
            && !isBold && !isDim && !isItalic
            && underlineStyle == .none
            && underlineColor == nil
            && !isStrikethrough && !isReverse && !isBlink
            && hyperlink == nil
    }

    // MARK: - Internal

    /// Collects the SGR parameter codes for all enabled attributes and colors,
    /// downsampling colors to the given profile.
    private func sgrParameters(profile: ColorProfile = .trueColor) -> [String] {
        var params: [String] = []

        if let fg = foreground?.downsampled(to: profile) {
            params.append(fg.fgCode)
        }
        if let bg = background?.downsampled(to: profile) {
            params.append(bg.bgCode)
        }
        if isBold { params.append("1") }
        if isDim { params.append("2") }
        if isItalic { params.append("3") }
        if let code = underlineStyle.sgrCode { params.append(code) }
        if isBlink { params.append("5") }
        if isReverse { params.append("7") }
        if isStrikethrough { params.append("9") }
        if let ulColor = underlineColor?.downsampled(to: profile) {
            params.append(ulColor.ulCode)
        }

        return params
    }
}
