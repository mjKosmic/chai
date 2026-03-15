/// A terminal color specification.
///
/// Supports the three standard terminal color modes:
///
/// - **ANSI 16**: The classic 8 standard + 8 bright colors.
/// - **Extended 256**: The 256-color palette (indices 0–255).
/// - **True Color**: 24-bit RGB colors.
///
/// ```swift
/// let red = Color.ansi(.red)
/// let orange = Color.extended(208)
/// let custom = Color.trueColor(r: 255, g: 100, b: 50)
/// ```
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
