import Chai
import Latte

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

// MARK: - Style → TextAttributes / StyledText

extension Style {
    /// Convert this ``Style`` to an equivalent ``TextAttributes`` for use with ``StyledText``.
    ///
    /// Only `.on` ``StyleFlag`` values emit attribute bits; `.off` and `.unset`
    /// produce no output (they do not emit disable codes).
    public var textAttributes: TextAttributes {
        var attrs: CellAttributes = []
        if isBold          == .on { attrs.insert(.bold) }
        if isDim           == .on { attrs.insert(.dim) }
        if isItalic        == .on { attrs.insert(.italic) }
        if underlineStyle  != .none { attrs.insert(.underline) }
        if isBlink         == .on { attrs.insert(.blink) }
        if isReverse       == .on { attrs.insert(.reverse) }
        if isStrikethrough == .on { attrs.insert(.strikethrough) }
        return TextAttributes(
            foreground: foreground?.cellColor,
            background: background?.cellColor,
            attributes: attrs,
            hyperlink:  hyperlink
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
