/// Standard 256-color terminal palette as RGB tuples.
///
/// Indices 0–7: standard ANSI colors.
/// Indices 8–15: bright ANSI colors.
/// Indices 16–231: 6×6×6 color cube.
/// Indices 232–255: grayscale ramp.
enum ColorPalette {

    /// The RGB values for all 256 palette entries.
    static let rgb: [(r: UInt8, g: UInt8, b: UInt8)] = {
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        palette.reserveCapacity(256)

        // 0–15: Standard and bright ANSI colors
        let ansi16: [(UInt8, UInt8, UInt8)] = [
            (0,   0,   0),    // 0  black
            (128, 0,   0),    // 1  red
            (0,   128, 0),    // 2  green
            (128, 128, 0),    // 3  yellow
            (0,   0,   128),  // 4  blue
            (128, 0,   128),  // 5  magenta
            (0,   128, 128),  // 6  cyan
            (192, 192, 192),  // 7  white
            (128, 128, 128),  // 8  bright black (gray)
            (255, 0,   0),    // 9  bright red
            (0,   255, 0),    // 10 bright green
            (255, 255, 0),    // 11 bright yellow
            (0,   0,   255),  // 12 bright blue
            (255, 0,   255),  // 13 bright magenta
            (0,   255, 255),  // 14 bright cyan
            (255, 255, 255),  // 15 bright white
        ]
        for c in ansi16 {
            palette.append((r: c.0, g: c.1, b: c.2))
        }

        // 16–231: 6×6×6 color cube
        let cubeValues: [UInt8] = [0, 95, 135, 175, 215, 255]
        for ri in 0..<6 {
            for gi in 0..<6 {
                for bi in 0..<6 {
                    palette.append((r: cubeValues[ri], g: cubeValues[gi], b: cubeValues[bi]))
                }
            }
        }

        // 232–255: grayscale ramp
        for i in 0..<24 {
            let v = UInt8(8 + 10 * i)
            palette.append((r: v, g: v, b: v))
        }

        return palette
    }()
}
