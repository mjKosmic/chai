
// MARK: - ANSIColor → CellColor

extension ANSIColor {
    /// The equivalent ``CellColor`` for this ANSI color.
    public var cellColor: CellColor {
        switch self {
        case .black:         return .black
        case .red:           return .red
        case .green:         return .green
        case .yellow:        return .yellow
        case .blue:          return .blue
        case .magenta:       return .magenta
        case .cyan:          return .cyan
        case .white:         return .white
        case .brightBlack:   return .brightBlack
        case .brightRed:     return .brightRed
        case .brightGreen:   return .brightGreen
        case .brightYellow:  return .brightYellow
        case .brightBlue:    return .brightBlue
        case .brightMagenta: return .brightMagenta
        case .brightCyan:    return .brightCyan
        case .brightWhite:   return .brightWhite
        }
    }
}

// MARK: - Color → CellColor

extension Color {
    /// The equivalent ``CellColor`` for this color.
    public var cellColor: CellColor {
        switch self {
        case .ansi(let c):                   return c.cellColor
        case .extended(let n):               return .palette(n)
        case .trueColor(let r, let g, let b): return .rgb(r, g, b)
        }
    }
}

// MARK: - Color → TextAttributes

extension TextAttributes {
    /// Creates text attributes from authoring colors.
    ///
    /// Both colors are converted through ``Color/cellColor``, so call sites use
    /// the same ``Color`` value as ``Style`` and the view style modifiers. The
    /// cell-level initializer stays available for renderer-facing code.
    ///
    /// - Parameters:
    ///   - foreground: The foreground color, or `nil` for the terminal default.
    ///   - background: The background color, or `nil` for the terminal default.
    ///   - attributes: Text decoration attributes.
    ///   - hyperlink: An optional OSC 8 hyperlink URL.
    public init(
        _ foreground: Color?,
        background: Color? = nil,
        attributes: Cell.Attributes = [],
        hyperlink: String? = nil
    ) {
        self.init(
            foreground: foreground?.cellColor,
            background: background?.cellColor,
            attributes: attributes,
            hyperlink: hyperlink
        )
    }
}

// MARK: - Style → TextAttributes / StyledText

extension Style {
    /// Convert this ``Style`` to an equivalent ``TextAttributes`` for use with ``StyledText``.
    ///
    /// Only `.on` ``StyleFlag`` values emit attribute bits; `.off` and `.unset`
    /// produce no output (they do not emit disable codes). Underline style and
    /// underline color are carried as structured decoration, so the cell path
    /// paints the same variant as ``render(_:profile:)``.
    public var textAttributes: TextAttributes {
        var attrs: Cell.Attributes = []
        if isBold          == .on { attrs.insert(.bold) }
        if isDim           == .on { attrs.insert(.dim) }
        if isItalic        == .on { attrs.insert(.italic) }
        if isBlink         == .on { attrs.insert(.blink) }
        if isReverse       == .on { attrs.insert(.reverse) }
        if isStrikethrough == .on { attrs.insert(.strikethrough) }
        return TextAttributes(
            foreground: foreground?.cellColor,
            background: background?.cellColor,
            attributes: attrs,
            hyperlink:  hyperlink,
            underlineStyle: underlineStyle,
            underlineColor: underlineStyle == .none ? nil : underlineColor?.cellColor
        )
    }

    /// Wrap `text` in a ``StyledText`` segment using this style.
    ///
    /// Use this instead of ``render(_:)`` when composing views for the
    /// cell-based renderer. Unlike `render`, no raw ANSI bytes are embedded
    /// in the string — styling is carried as structured ``TextAttributes`` metadata.
    public func styledText(_ text: String) -> StyledText {
        StyledText(text, style: textAttributes)
    }
}
