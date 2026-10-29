// MARK: - CellColor

/// Terminal colors for cell rendering: ANSI 16, 256-color palette, or 24-bit RGB.
public enum CellColor: Sendable, Equatable, Hashable {
    case black, red, green, yellow, blue, magenta, cyan, white
    case brightBlack, brightRed, brightGreen, brightYellow
    case brightBlue, brightMagenta, brightCyan, brightWhite
    case palette(UInt8)
    case rgb(UInt8, UInt8, UInt8)

    /// SGR parameter string for this color in foreground or background position.
    func sgrParams(foreground: Bool) -> String {
        let base: Int = foreground ? 30 : 40
        let brightBase: Int = foreground ? 90 : 100
        switch self {
        case .black:         return "\(base + 0)"
        case .red:           return "\(base + 1)"
        case .green:         return "\(base + 2)"
        case .yellow:        return "\(base + 3)"
        case .blue:          return "\(base + 4)"
        case .magenta:       return "\(base + 5)"
        case .cyan:          return "\(base + 6)"
        case .white:         return "\(base + 7)"
        case .brightBlack:   return "\(brightBase + 0)"
        case .brightRed:     return "\(brightBase + 1)"
        case .brightGreen:   return "\(brightBase + 2)"
        case .brightYellow:  return "\(brightBase + 3)"
        case .brightBlue:    return "\(brightBase + 4)"
        case .brightMagenta: return "\(brightBase + 5)"
        case .brightCyan:    return "\(brightBase + 6)"
        case .brightWhite:   return "\(brightBase + 7)"
        case .palette(let n):
            return foreground ? "38;5;\(n)" : "48;5;\(n)"
        case .rgb(let r, let g, let b):
            return foreground ? "38;2;\(r);\(g);\(b)" : "48;2;\(r);\(g);\(b)"
        }
    }

    /// SGR parameter string for this color in underline position (SGR 58).
    ///
    /// Named ANSI colors are emitted as extended palette indices 0–15, the
    /// same encoding the style renderer uses.
    func underlineSGRParams() -> String {
        switch self {
        case .palette(let n):
            return "58;5;\(n)"
        case .rgb(let r, let g, let b):
            return "58;2;\(r);\(g);\(b)"
        default:
            return "58;5;\(ansiIndex ?? 0)"
        }
    }

    /// Palette index for the named ANSI colors.
    private var ansiIndex: Int? {
        switch self {
        case .black:         return 0
        case .red:           return 1
        case .green:         return 2
        case .yellow:        return 3
        case .blue:          return 4
        case .magenta:       return 5
        case .cyan:          return 6
        case .white:         return 7
        case .brightBlack:   return 8
        case .brightRed:     return 9
        case .brightGreen:   return 10
        case .brightYellow:  return 11
        case .brightBlue:    return 12
        case .brightMagenta: return 13
        case .brightCyan:    return 14
        case .brightWhite:   return 15
        case .palette, .rgb: return nil
        }
    }
}

// MARK: - Cell

/// A single terminal cell representing one display column.
///
/// Each cell occupies one column, except:
/// - Continuation cells (width: 0) are placeholders for the second column of wide characters.
/// - Wide cells (width: 2) occupy 2 columns; the next cell must be a continuation.
///
/// Decoration is carried structurally: ``underlineStyle`` and
/// ``underlineColor`` preserve extended underline variants that the
/// ``Attributes`` bit set cannot express.
public struct Cell: Sendable, Equatable {
    public var character: Character
    public var width: Int8
    public var foreground: CellColor?
    public var background: CellColor?
    public var attributes: Attributes
    public var hyperlink: String?
    /// Underline variant. `.none` falls back to the `.underline` attribute bit.
    public var underlineStyle: UnderlineStyle
    /// Underline color (SGR 58). Painted only when an underline is present.
    public var underlineColor: CellColor?
    public var layer: Int8

    public init(
        character: Character = " ",
        width: Int8 = 1,
        foreground: CellColor? = nil,
        background: CellColor? = nil,
        attributes: Attributes = [],
        hyperlink: String? = nil,
        underlineStyle: UnderlineStyle = .none,
        underlineColor: CellColor? = nil,
        layer: Int8 = 0
    ) {
        self.character = character
        self.width = width
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
        self.hyperlink = hyperlink
        self.underlineStyle = underlineStyle
        self.underlineColor = underlineColor
        self.layer = layer
    }

    /// The underline decoration this cell paints.
    ///
    /// ``underlineStyle`` wins; otherwise the ``Attributes/underline`` bit means
    /// a single underline, so hand-built attribute sets keep their meaning.
    public var resolvedUnderlineStyle: UnderlineStyle {
        if underlineStyle != .none { return underlineStyle }
        return attributes.contains(.underline) ? .single : .none
    }

    /// An empty cell (space, width 1, default style).
    public static let empty = Cell()

    /// A placeholder for the second column of a wide character.
    public static let wideContinuation = Cell(character: " ", width: 0)

    /// Render this cell as a terminal-ready string.
    ///
    /// Continuation cells (width == 0) return empty string.
    /// Other cells emit SGR prefix (if styled), character, and SGR reset.
    public func render() -> String {
        guard width > 0 else { return "" }

        let sgr = sgrParameters

        var result = ""

        if let url = hyperlink {
            result += ANSI.osc8(url: url)
        }

        if !sgr.isEmpty {
            result += "\u{1B}[\(sgr.joined(separator: ";"))m"
        }

        result += String(character)

        if !sgr.isEmpty {
            result += ANSI.reset
        }

        if hyperlink != nil {
            result += ANSI.osc8Reset
        }

        return result
    }

    /// SGR parameters for this cell, in a stable order.
    ///
    /// ``render()`` and the renderer's row serializer both use this so a cell
    /// paints the same decoration on either path. The effective underline
    /// resolves ``underlineStyle`` against the ``Attributes/underline`` bit,
    /// and the underline color is emitted only when an underline is present.
    var sgrParameters: [String] {
        var parts: [String] = []
        if let fg = foreground { parts.append(fg.sgrParams(foreground: true)) }
        if let bg = background { parts.append(bg.sgrParams(foreground: false)) }

        let underline = resolvedUnderlineStyle
        let bitSet = attributes.contains(.underline)
        for code in attributes.sgrCodes where !(code == 4 && underline != .single) {
            parts.append(String(code))
        }
        if underline == .single && !bitSet {
            parts.append("4")
        } else if underline != .none && underline != .single, let code = underline.sgrCode {
            parts.append(code)
        }
        if underline != .none, let color = underlineColor {
            parts.append(color.underlineSGRParams())
        }
        return parts
    }
}

// MARK: - Cell.Attributes

extension Cell {
    /// Text decoration attributes as a bit set.
    public struct Attributes: OptionSet, Sendable, Equatable, Hashable {
        public let rawValue: UInt8

        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }

        public static let bold          = Attributes(rawValue: 1 << 0)
        public static let dim           = Attributes(rawValue: 1 << 1)
        public static let italic        = Attributes(rawValue: 1 << 2)
        public static let underline     = Attributes(rawValue: 1 << 3)
        public static let blink         = Attributes(rawValue: 1 << 4)
        public static let reverse       = Attributes(rawValue: 1 << 5)
        public static let strikethrough = Attributes(rawValue: 1 << 6)
        public static let hidden        = Attributes(rawValue: 1 << 7)

        /// SGR codes for all set attributes.
        var sgrCodes: [Int] {
            var codes: [Int] = []
            if contains(.bold)          { codes.append(1) }
            if contains(.dim)           { codes.append(2) }
            if contains(.italic)        { codes.append(3) }
            if contains(.underline)     { codes.append(4) }
            if contains(.blink)         { codes.append(5) }
            if contains(.reverse)       { codes.append(7) }
            if contains(.hidden)        { codes.append(8) }
            if contains(.strikethrough) { codes.append(9) }
            return codes
        }
    }
}

// MARK: - TextAttributes

/// Grouping of foreground color, background color, attributes, hyperlink, and
/// underline decoration applied to a run of text prior to layout.
public struct TextAttributes: Sendable, Equatable {
    public var foreground: CellColor?
    public var background: CellColor?
    public var attributes: Cell.Attributes
    public var hyperlink: String?
    /// Underline variant. `.none` falls back to the `.underline` attribute bit.
    public var underlineStyle: UnderlineStyle
    /// Underline color (SGR 58). Painted only when an underline is present.
    public var underlineColor: CellColor?

    public init(
        foreground: CellColor? = nil,
        background: CellColor? = nil,
        attributes: Cell.Attributes = [],
        hyperlink: String? = nil,
        underlineStyle: UnderlineStyle = .none,
        underlineColor: CellColor? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.attributes = attributes
        self.hyperlink = hyperlink
        self.underlineStyle = underlineStyle
        self.underlineColor = underlineColor
    }

    public static let `default` = TextAttributes()
}
