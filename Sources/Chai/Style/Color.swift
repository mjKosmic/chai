/// A terminal color specification.
///
/// Supports the three standard terminal color modes:
///
/// - **ANSI 16**: The classic 8 standard + 8 bright colors.
/// - **Extended 256**: The 256-color palette (indices 0–255).
/// - **True Color**: 24-bit RGB colors.
///
/// ```swift
/// let red = Color.ansi(.red)      // or just `.red`
/// let orange = Color.extended(208)
/// let custom = Color.trueColor(r: 255, g: 100, b: 50)
/// ```
///
/// The 16 standard ANSI colors are available as named values (``red``,
/// ``brightBlue``, ...), so the common case needs no ``ANSIColor`` wrapper.
public enum Color: Sendable, Equatable {
    /// One of the 16 standard ANSI colors.
    case ansi(ANSIColor)

    /// A color from the 256-color palette (0–255).
    case extended(UInt8)

    /// A 24-bit true color.
    case trueColor(r: UInt8, g: UInt8, b: UInt8)

    // MARK: - SGR Parameters

    /// The ANSI SGR parameter string for setting this color as the foreground.
    var fgCode: String {
        switch self {
        case .ansi(let color):
            return color.fgCode
        case .extended(let index):
            return "38;5;\(index)"
        case .trueColor(let r, let g, let b):
            return "38;2;\(r);\(g);\(b)"
        }
    }

    /// The ANSI SGR parameter string for setting this color as the background.
    var bgCode: String {
        switch self {
        case .ansi(let color):
            return color.bgCode
        case .extended(let index):
            return "48;5;\(index)"
        case .trueColor(let r, let g, let b):
            return "48;2;\(r);\(g);\(b)"
        }
    }

    /// The ANSI SGR parameter string for setting this color as the underline color (SGR 58).
    ///
    /// ANSI 16-color values are treated as extended palette indices 0–15.
    var ulCode: String {
        switch self {
        case .ansi(let color):
            return "58;5;\(color.rawValue)"
        case .extended(let index):
            return "58;5;\(index)"
        case .trueColor(let r, let g, let b):
            return "58;2;\(r);\(g);\(b)"
        }
    }
}

// MARK: - Named ANSI colors

extension Color {
    /// ANSI black (SGR 30).
    public static let black: Color = .ansi(.black)
    /// ANSI red (SGR 31).
    public static let red: Color = .ansi(.red)
    /// ANSI green (SGR 32).
    public static let green: Color = .ansi(.green)
    /// ANSI yellow (SGR 33).
    public static let yellow: Color = .ansi(.yellow)
    /// ANSI blue (SGR 34).
    public static let blue: Color = .ansi(.blue)
    /// ANSI magenta (SGR 35).
    public static let magenta: Color = .ansi(.magenta)
    /// ANSI cyan (SGR 36).
    public static let cyan: Color = .ansi(.cyan)
    /// ANSI white (SGR 37).
    public static let white: Color = .ansi(.white)
    /// Bright ANSI black (SGR 90), typically displayed as gray.
    public static let brightBlack: Color = .ansi(.brightBlack)
    /// Bright ANSI red (SGR 91).
    public static let brightRed: Color = .ansi(.brightRed)
    /// Bright ANSI green (SGR 92).
    public static let brightGreen: Color = .ansi(.brightGreen)
    /// Bright ANSI yellow (SGR 93).
    public static let brightYellow: Color = .ansi(.brightYellow)
    /// Bright ANSI blue (SGR 94).
    public static let brightBlue: Color = .ansi(.brightBlue)
    /// Bright ANSI magenta (SGR 95).
    public static let brightMagenta: Color = .ansi(.brightMagenta)
    /// Bright ANSI cyan (SGR 96).
    public static let brightCyan: Color = .ansi(.brightCyan)
    /// Bright ANSI white (SGR 97).
    public static let brightWhite: Color = .ansi(.brightWhite)
}

// MARK: - CellColor bridge

extension Color {
    /// Creates a color from the renderer's cell-level color value.
    ///
    /// `CellColor` is the representation the renderer stores in ``Cell`` and
    /// ``TextAttributes``; this bridge lets low-level cell-painting code use
    /// those values with the application styling APIs.
    ///
    /// - Parameter cellColor: The named, palette, or 24-bit cell color.
    public init(_ cellColor: CellColor) {
        switch cellColor {
        case .black:         self = .ansi(.black)
        case .red:           self = .ansi(.red)
        case .green:         self = .ansi(.green)
        case .yellow:        self = .ansi(.yellow)
        case .blue:          self = .ansi(.blue)
        case .magenta:       self = .ansi(.magenta)
        case .cyan:          self = .ansi(.cyan)
        case .white:         self = .ansi(.white)
        case .brightBlack:   self = .ansi(.brightBlack)
        case .brightRed:     self = .ansi(.brightRed)
        case .brightGreen:   self = .ansi(.brightGreen)
        case .brightYellow:  self = .ansi(.brightYellow)
        case .brightBlue:    self = .ansi(.brightBlue)
        case .brightMagenta: self = .ansi(.brightMagenta)
        case .brightCyan:    self = .ansi(.brightCyan)
        case .brightWhite:   self = .ansi(.brightWhite)
        case .palette(let index):        self = .extended(index)
        case .rgb(let r, let g, let b):  self = .trueColor(r: r, g: g, b: b)
        }
    }
}

// MARK: - Convenience initializers

extension Color {
    /// Creates a color from a hex string (e.g. `"#FF6B35"` or `"FF6B35"`).
    ///
    /// Returns `nil` if the string is not a valid 6-digit hex color.
    public static func hex(_ value: String) -> Color? {
        var hex = value
        if hex.hasPrefix("#") {
            hex = String(hex.dropFirst())
        }
        guard hex.count == 6, let rgb = UInt32(hex, radix: 16) else {
            return nil
        }
        return .trueColor(
            r: UInt8((rgb >> 16) & 0xFF),
            g: UInt8((rgb >> 8) & 0xFF),
            b: UInt8(rgb & 0xFF)
        )
    }
}

// MARK: - Color Profile Downsampling

extension Color {

    /// Returns the best representation of this color within the given profile.
    ///
    /// - ``ColorProfile/trueColor``: Returns `self` unchanged.
    /// - ``ColorProfile/ansi256``: Converts to the nearest 256-palette entry.
    /// - ``ColorProfile/ansi``: Converts to the nearest of the 16 ANSI colors.
    /// - ``ColorProfile/noColor``: Returns `nil` (color should be omitted).
    ///
    /// Nearest-color selection uses squared Euclidean distance in RGB space.
    ///
    /// ```swift
    /// let color = Color.trueColor(r: 200, g: 50, b: 50)
    /// color.downsampled(to: .ansi256) // nearest 256-palette entry
    /// color.downsampled(to: .ansi)    // nearest ANSI 16 color
    /// color.downsampled(to: .noColor) // nil
    /// ```
    public func downsampled(to profile: ColorProfile) -> Color? {
        switch profile {
        case .noColor:
            return nil
        case .trueColor:
            return self
        case .ansi256:
            return nearestPaletteColor(searchRange: 0..<256)
        case .ansi:
            return nearestPaletteColor(searchRange: 0..<16)
        }
    }

    /// Converts this color to its RGB components.
    func toRGB() -> (r: UInt8, g: UInt8, b: UInt8) {
        switch self {
        case .trueColor(let r, let g, let b):
            return (r, g, b)
        case .ansi(let color):
            return ColorPalette.rgb[Int(color.rawValue)]
        case .extended(let index):
            return ColorPalette.rgb[Int(index)]
        }
    }

    /// Finds the nearest color in the palette within the given index range.
    private func nearestPaletteColor(searchRange: Range<Int>) -> Color {
        let (r, g, b) = toRGB()
        let ri = Int(r), gi = Int(g), bi = Int(b)

        var bestIndex = searchRange.lowerBound
        var bestDistance = Int.max

        for i in searchRange {
            let entry = ColorPalette.rgb[i]
            let dr = ri - Int(entry.r)
            let dg = gi - Int(entry.g)
            let db = bi - Int(entry.b)
            let distance = dr * dr + dg * dg + db * db
            if distance < bestDistance {
                bestDistance = distance
                bestIndex = i
                if distance == 0 { break }
            }
        }

        if searchRange == 0..<16 {
            return .ansi(ANSIColor(rawValue: UInt8(bestIndex)) ?? .black)
        }
        return .extended(UInt8(bestIndex))
    }
}

// MARK: - ANSIColor

/// The 16 standard ANSI terminal colors.
///
/// These are the most widely supported colors across terminals.
public enum ANSIColor: UInt8, Sendable, CaseIterable {
    case black = 0
    case red = 1
    case green = 2
    case yellow = 3
    case blue = 4
    case magenta = 5
    case cyan = 6
    case white = 7
    case brightBlack = 8
    case brightRed = 9
    case brightGreen = 10
    case brightYellow = 11
    case brightBlue = 12
    case brightMagenta = 13
    case brightCyan = 14
    case brightWhite = 15

    /// The ANSI SGR parameter for this color as a foreground color.
    var fgCode: String {
        if rawValue < 8 {
            return "\(30 + Int(rawValue))"
        } else {
            return "\(90 + Int(rawValue) - 8)"
        }
    }

    /// The ANSI SGR parameter for this color as a background color.
    var bgCode: String {
        if rawValue < 8 {
            return "\(40 + Int(rawValue))"
        } else {
            return "\(100 + Int(rawValue) - 8)"
        }
    }
}
