// MARK: - StyleFlag

/// A three-state boolean flag for style attributes.
///
/// Unlike a plain `Bool`, `StyleFlag` can represent an **unset** state —
/// meaning the attribute has not been explicitly specified. This is the key
/// building block for style inheritance: `.unset` properties are filled in from
/// a parent style, while `.on` and `.off` properties are always preserved.
///
/// ```swift
/// let base  = Style().bold()                       // isBold = .on
/// let child = Style().notBold()                    // isBold = .off
/// let result = child.inheriting(from: base)        // isBold stays .off — child wins
///
/// let other = Style()                              // isBold = .unset
/// let result2 = other.inheriting(from: base)      // isBold becomes .on — inherited
/// ```
public enum StyleFlag: Sendable, Equatable {
    /// The attribute has not been set — transparent to inheritance.
    case unset
    /// The attribute is explicitly enabled.
    case on
    /// The attribute is explicitly disabled (blocks inheritance of `.on` from a parent).
    case off
}

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
///
/// ## Style Inheritance
///
/// Use ``inheriting(from:)`` to fill in unset properties from a parent style.
/// Properties that are explicitly `.on` or `.off` on the child are never
/// overridden; only `.unset` properties are filled in from the parent.
///
/// ```swift
/// let base  = Style().foreground(.ansi(.blue)).bold()
/// let child = Style().foreground(.ansi(.red)).inheriting(from: base)
/// // child: foreground = red (own value), bold = on (inherited)
/// ```
public struct Style: Sendable, Equatable {
    /// The foreground (text) color, or `nil` for the terminal default.
    public var foreground: Color?

    /// The background color, or `nil` for the terminal default.
    public var background: Color?

    /// Whether to render text in bold.
    ///
    /// - `.unset` (default): no code emitted; transparent to inheritance.
    /// - `.on`: emits SGR 1 (bold).
    /// - `.off`: no code emitted; blocks inheritance of bold from a parent.
    public var isBold: StyleFlag

    /// Whether to render text with reduced intensity.
    ///
    /// - `.unset` (default): no code emitted; transparent to inheritance.
    /// - `.on`: emits SGR 2 (dim).
    /// - `.off`: no code emitted; blocks inheritance of dim from a parent.
    public var isDim: StyleFlag

    /// Whether to render text in italic.
    ///
    /// - `.unset` (default): no code emitted; transparent to inheritance.
    /// - `.on`: emits SGR 3 (italic).
    /// - `.off`: no code emitted; blocks inheritance of italic from a parent.
    public var isItalic: StyleFlag

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
    ///
    /// - `.unset` (default): no code emitted; transparent to inheritance.
    /// - `.on`: emits SGR 9 (strikethrough).
    /// - `.off`: no code emitted; blocks inheritance from a parent.
    public var isStrikethrough: StyleFlag

    /// Whether to swap foreground and background colors.
    ///
    /// - `.unset` (default): no code emitted; transparent to inheritance.
    /// - `.on`: emits SGR 7 (reverse video).
    /// - `.off`: no code emitted; blocks inheritance from a parent.
    public var isReverse: StyleFlag

    /// Whether to render blinking text (support varies by terminal).
    ///
    /// - `.unset` (default): no code emitted; transparent to inheritance.
    /// - `.on`: emits SGR 5 (blink).
    /// - `.off`: no code emitted; blocks inheritance from a parent.
    public var isBlink: StyleFlag

    /// An optional URL to wrap rendered text in an OSC 8 hyperlink sequence.
    ///
    /// Terminals that do not support OSC 8 silently ignore the sequences —
    /// the visible text is still displayed, so degradation is graceful.
    /// Hyperlink sequences are omitted when rendering at `.noColor` profile
    /// (non-TTY output).
    public var hyperlink: String?

    // MARK: - Initializer

    /// Creates a style with no attributes or colors set.
    ///
    /// Boolean parameters are provided for backward compatibility — passing
    /// `true` for any attribute sets the corresponding ``StyleFlag`` to `.on`.
    /// The default of `false` maps to `.unset` (not set), which is transparent
    /// to style inheritance. Use ``notBold()``, ``notItalic()``, etc. to
    /// explicitly set a flag to `.off`.
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
        self.isBold = isBold ? .on : .unset
        self.isDim = isDim ? .on : .unset
        self.isItalic = isItalic ? .on : .unset
        self.underlineStyle = isUnderline ? .single : .none
        self.underlineColor = nil
        self.isStrikethrough = isStrikethrough ? .on : .unset
        self.isReverse = isReverse ? .on : .unset
        self.isBlink = isBlink ? .on : .unset
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

    // MARK: Bold

    /// Returns a copy with bold explicitly enabled (sets flag to `.on`).
    public func bold() -> Style {
        var copy = self
        copy.isBold = .on
        return copy
    }

    /// Returns a copy with bold explicitly disabled (sets flag to `.off`).
    ///
    /// `.off` blocks inheritance of bold from a parent style. Use this when
    /// a child style must not be bold even if the parent is bold.
    public func notBold() -> Style {
        var copy = self
        copy.isBold = .off
        return copy
    }

    /// Returns a copy with bold reset to unset (transparent to inheritance).
    public func unsetBold() -> Style {
        var copy = self
        copy.isBold = .unset
        return copy
    }

    // MARK: Dim

    /// Returns a copy with dim explicitly enabled (sets flag to `.on`).
    public func dim() -> Style {
        var copy = self
        copy.isDim = .on
        return copy
    }

    /// Returns a copy with dim explicitly disabled (sets flag to `.off`).
    public func notDim() -> Style {
        var copy = self
        copy.isDim = .off
        return copy
    }

    /// Returns a copy with dim reset to unset (transparent to inheritance).
    public func unsetDim() -> Style {
        var copy = self
        copy.isDim = .unset
        return copy
    }

    // MARK: Italic

    /// Returns a copy with italic explicitly enabled (sets flag to `.on`).
    public func italic() -> Style {
        var copy = self
        copy.isItalic = .on
        return copy
    }

    /// Returns a copy with italic explicitly disabled (sets flag to `.off`).
    public func notItalic() -> Style {
        var copy = self
        copy.isItalic = .off
        return copy
    }

    /// Returns a copy with italic reset to unset (transparent to inheritance).
    public func unsetItalic() -> Style {
        var copy = self
        copy.isItalic = .unset
        return copy
    }

    // MARK: Underline

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

    // MARK: Strikethrough

    /// Returns a copy with strikethrough explicitly enabled (sets flag to `.on`).
    public func strikethrough() -> Style {
        var copy = self
        copy.isStrikethrough = .on
        return copy
    }

    /// Returns a copy with strikethrough explicitly disabled (sets flag to `.off`).
    public func notStrikethrough() -> Style {
        var copy = self
        copy.isStrikethrough = .off
        return copy
    }

    /// Returns a copy with strikethrough reset to unset (transparent to inheritance).
    public func unsetStrikethrough() -> Style {
        var copy = self
        copy.isStrikethrough = .unset
        return copy
    }

    // MARK: Reverse

    /// Returns a copy with reverse video explicitly enabled (sets flag to `.on`).
    public func reverse() -> Style {
        var copy = self
        copy.isReverse = .on
        return copy
    }

    /// Returns a copy with reverse video explicitly disabled (sets flag to `.off`).
    public func notReverse() -> Style {
        var copy = self
        copy.isReverse = .off
        return copy
    }

    /// Returns a copy with reverse reset to unset (transparent to inheritance).
    public func unsetReverse() -> Style {
        var copy = self
        copy.isReverse = .unset
        return copy
    }

    // MARK: Blink

    /// Returns a copy with blink explicitly enabled (sets flag to `.on`).
    public func blink() -> Style {
        var copy = self
        copy.isBlink = .on
        return copy
    }

    /// Returns a copy with blink explicitly disabled (sets flag to `.off`).
    public func notBlink() -> Style {
        var copy = self
        copy.isBlink = .off
        return copy
    }

    /// Returns a copy with blink reset to unset (transparent to inheritance).
    public func unsetBlink() -> Style {
        var copy = self
        copy.isBlink = .unset
        return copy
    }

    // MARK: Hyperlink

    /// Returns a copy with an OSC 8 hyperlink URL set.
    ///
    /// The rendered text will be wrapped in OSC 8 sequences:
    /// `ESC]8;;<url>ESC\\<styled-text>ESC]8;;ESC\\`
    ///
    /// Terminals that do not support OSC 8 ignore the sequences and display
    /// the visible text only. Hyperlinks are omitted when rendering at the
    /// `.noColor` profile.
    ///
    /// ASCII control characters (U+0000–U+001F and U+007F) are stripped from
    /// `url` at render time. They must not appear in a well-formed OSC sequence
    /// — any embedded `ESC`, `BEL`, or `ST` would prematurely terminate the
    /// OSC 8 sequence and could inject arbitrary escape sequences into the
    /// terminal stream.
    ///
    /// - Parameter url: The target URL for the hyperlink. Control characters
    ///   are silently removed before the sequence is emitted.
    public func hyperlink(_ url: String) -> Style {
        var copy = self
        copy.hyperlink = url
        return copy
    }

    // MARK: - Inheritance

    /// Returns a copy of this style with any `.unset` properties filled in from `parent`.
    ///
    /// Properties explicitly set on the receiver (`.on` or `.off` flags,
    /// non-nil colors, non-default underline style) are never overridden.
    /// Only properties that are at their default/unset state are inherited.
    ///
    /// ```swift
    /// let base  = Style().foreground(.ansi(.blue)).bold()
    /// let child = Style().foreground(.ansi(.red)).inheriting(from: base)
    /// // child: foreground = red (own value), bold = on (inherited)
    /// ```
    ///
    /// - Parameter parent: The style to inherit unset properties from.
    /// - Returns: A new style with unset properties filled in from `parent`.
    public func inheriting(from parent: Style) -> Style {
        var result = self
        // Colors: inherit if child has no color set
        if result.foreground == nil { result.foreground = parent.foreground }
        if result.background == nil { result.background = parent.background }
        // StyleFlag attributes: inherit if child's flag is .unset
        if result.isBold == .unset { result.isBold = parent.isBold }
        if result.isDim == .unset { result.isDim = parent.isDim }
        if result.isItalic == .unset { result.isItalic = parent.isItalic }
        if result.isStrikethrough == .unset { result.isStrikethrough = parent.isStrikethrough }
        if result.isReverse == .unset { result.isReverse = parent.isReverse }
        if result.isBlink == .unset { result.isBlink = parent.isBlink }
        // Underline: inherit if child has no underline style set
        if result.underlineStyle == .none { result.underlineStyle = parent.underlineStyle }
        // Underline color: inherit if child has none
        if result.underlineColor == nil { result.underlineColor = parent.underlineColor }
        // Hyperlink: inherit if child has none
        if result.hyperlink == nil { result.hyperlink = parent.hyperlink }
        return result
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
        // The URL is sanitized before interpolation: any ASCII control character
        // (U+0000–U+001F or U+007F) would prematurely terminate the OSC sequence
        // and could inject additional escape sequences into the terminal stream.
        let st = "\u{1B}\\"
        let safeURL = Style.sanitizeOSCParam(url)
        return "\u{1B}]8;;\(safeURL)\(st)\(styled)\u{1B}]8;;\(st)"
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

    /// Whether this style has no attributes, colors, or other properties set.
    ///
    /// A style is empty when every flag is `.unset`, all colors are `nil`,
    /// the underline style is `.none`, and no hyperlink is set. A style with
    /// any `.off` flag is **not** empty, since it carries explicit intent (it
    /// blocks inheritance of that attribute from a parent style).
    public var isEmpty: Bool {
        foreground == nil
            && background == nil
            && isBold == .unset
            && isDim == .unset
            && isItalic == .unset
            && underlineStyle == .none
            && underlineColor == nil
            && isStrikethrough == .unset
            && isReverse == .unset
            && isBlink == .unset
            && hyperlink == nil
    }

    // MARK: - Internal

    /// Strips ASCII control characters (U+0000–U+001F and U+007F) from an OSC
    /// parameter string.
    ///
    /// OSC sequences are terminated by `BEL` (U+0007) or `ST` (`ESC \`,
    /// U+001B U+005C). Any of those bytes — or any other C0 control character —
    /// embedded in the parameter field would break the sequence and could allow
    /// escape-sequence injection. Silently dropping them is the standard
    /// mitigation used by terminal libraries (e.g. lipgloss).
    private static func sanitizeOSCParam(_ value: String) -> String {
        String(value.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F })
    }

    /// Collects the SGR parameter codes for all enabled attributes and colors,
    /// downsampling colors to the given profile.
    ///
    /// Only `.on` flags emit SGR codes. `.off` and `.unset` flags emit no codes
    /// and therefore do not change the terminal’s existing rendering state;
    /// emit explicit reset/disable SGR parameters if you need to force defaults.
    private func sgrParameters(profile: ColorProfile = .trueColor) -> [String] {
        var params: [String] = []

        if let fg = foreground?.downsampled(to: profile) {
            params.append(fg.fgCode)
        }
        if let bg = background?.downsampled(to: profile) {
            params.append(bg.bgCode)
        }
        if isBold == .on { params.append("1") }
        if isDim == .on { params.append("2") }
        if isItalic == .on { params.append("3") }
        if let code = underlineStyle.sgrCode { params.append(code) }
        if isBlink == .on { params.append("5") }
        if isReverse == .on { params.append("7") }
        if isStrikethrough == .on { params.append("9") }
        if underlineStyle != .none,
           let ulColor = underlineColor?.downsampled(to: profile) {
            params.append(ulColor.ulCode)
        }

        return params
    }
}
