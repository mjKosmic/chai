// MARK: - HSL Conversion Helpers (internal)

extension Color {

    /// Converts this color to normalized RGB components (each in 0.0–1.0).
    func toRGBDouble() -> (r: Double, g: Double, b: Double) {
        let (r8, g8, b8) = toRGB()
        return (Double(r8) / 255.0, Double(g8) / 255.0, Double(b8) / 255.0)
    }

    /// Converts this color to HSL components.
    ///
    /// - Returns: `(h: 0–360, s: 0–1, l: 0–1)`
    func toHSL() -> (h: Double, s: Double, l: Double) {
        let (r, g, b) = toRGBDouble()
        let cMax = max(r, g, b)
        let cMin = min(r, g, b)
        let delta = cMax - cMin

        let l = (cMax + cMin) / 2.0

        let s: Double
        if delta == 0 {
            s = 0
        } else {
            s = delta / (1.0 - abs(2.0 * l - 1.0))
        }

        let h: Double
        if delta == 0 {
            h = 0
        } else if cMax == r {
            let segment = (g - b) / delta
            let shift = segment < 0 ? 6.0 : 0.0
            h = 60.0 * (segment + shift)
        } else if cMax == g {
            h = 60.0 * ((b - r) / delta + 2.0)
        } else {
            h = 60.0 * ((r - g) / delta + 4.0)
        }

        return (h: h, s: s, l: l)
    }
}

/// Converts HSL components back to a `.trueColor` Color value.
///
/// - Parameters:
///   - h: Hue in degrees (0–360).
///   - s: Saturation (0–1).
///   - l: Lightness (0–1).
private func hslToColor(h: Double, s: Double, l: Double) -> Color {
    let c = (1.0 - abs(2.0 * l - 1.0)) * s
    let x = c * (1.0 - abs((h / 60.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
    let m = l - c / 2.0

    let r1, g1, b1: Double
    switch h {
    case 0.0..<60.0:
        (r1, g1, b1) = (c, x, 0)
    case 60.0..<120.0:
        (r1, g1, b1) = (x, c, 0)
    case 120.0..<180.0:
        (r1, g1, b1) = (0, c, x)
    case 180.0..<240.0:
        (r1, g1, b1) = (0, x, c)
    case 240.0..<300.0:
        (r1, g1, b1) = (x, 0, c)
    default:
        (r1, g1, b1) = (c, 0, x)
    }

    let clamp = { (v: Double) -> UInt8 in UInt8(min(255, max(0, Int((v + m) * 255.0 + 0.5)))) }
    return .trueColor(r: clamp(r1), g: clamp(g1), b: clamp(b1))
}

// MARK: - Color Math Utilities

/// Returns a darker version of the color by reducing its HSL lightness
/// by `amount` (clamped to the range 0.0–1.0).
///
/// `.ansi` and `.extended` colors are first converted to their TrueColor
/// RGB equivalents (using the standard 256-palette RGB table) before the
/// HSL operation is applied. The result is always a `.trueColor` value.
///
/// ```swift
/// let dim = darken(.trueColor(r: 200, g: 100, b: 50), 0.2)
/// ```
///
/// - Parameters:
///   - color: The base color. Non-TrueColor values are converted internally.
///   - amount: The fraction by which to reduce lightness. Clamped to 0.0–1.0
///     before use, so negative values and values above 1.0 are safe.
/// - Returns: A `.trueColor` value with the same hue and saturation but
///   reduced lightness.
public func darken(_ color: Color, _ amount: Double) -> Color {
    let amount = max(0.0, min(1.0, amount))
    var (h, s, l) = color.toHSL()
    l = max(0.0, l - amount)
    return hslToColor(h: h, s: s, l: l)
}

/// Returns a lighter version of the color by increasing its HSL lightness
/// by `amount` (clamped to the range 0.0–1.0).
///
/// `.ansi` and `.extended` colors are first converted to their TrueColor
/// RGB equivalents before the HSL operation is applied. The result is always
/// a `.trueColor` value.
///
/// ```swift
/// let bright = lighten(.ansi(.blue), 0.3)
/// ```
///
/// - Parameters:
///   - color: The base color. Non-TrueColor values are converted internally.
///   - amount: The fraction by which to increase lightness. Clamped to 0.0–1.0
///     before use, so negative values and values above 1.0 are safe.
/// - Returns: A `.trueColor` value with the same hue and saturation but
///   increased lightness.
public func lighten(_ color: Color, _ amount: Double) -> Color {
    let amount = max(0.0, min(1.0, amount))
    var (h, s, l) = color.toHSL()
    l = min(1.0, l + amount)
    return hslToColor(h: h, s: s, l: l)
}

/// Returns the complementary color by rotating its hue by 180°.
///
/// `.ansi` and `.extended` colors are first converted to their TrueColor
/// RGB equivalents before the rotation is applied. The result is always a
/// `.trueColor` value.
///
/// ```swift
/// let comp = complementary(.trueColor(r: 255, g: 0, b: 0))  // cyan
/// ```
///
/// - Parameter color: The base color. Non-TrueColor values are converted internally.
/// - Returns: A `.trueColor` value with the hue rotated by 180°.
public func complementary(_ color: Color) -> Color {
    var (h, s, l) = color.toHSL()
    h = (h + 180.0).truncatingRemainder(dividingBy: 360.0)
    return hslToColor(h: h, s: s, l: l)
}

/// Blends `from` and `to` by factor `t` in gamma-encoded sRGB space.
///
/// Component-wise linear interpolation is applied directly on the
/// gamma-encoded 8-bit channel values (i.e. the stored `r`, `g`, `b` bytes),
/// which matches common terminal and CSS colour-mixing conventions.
/// This is **not** the same as linear-light (linearised) blending, which would
/// require gamma-decoding before interpolating and re-encoding after.
///
/// `t = 0.0` returns a color equal to `from`; `t = 1.0` returns a color equal
/// to `to`. Values outside 0.0–1.0 are clamped.
///
/// All color variants (`.ansi`, `.extended`, `.trueColor`) are supported;
/// non-TrueColor inputs are first converted to their RGB equivalents.
/// The result is always a `.trueColor` value.
///
/// ```swift
/// let mid = blend(.ansi(.red), .ansi(.blue), t: 0.5)
/// ```
///
/// - Parameters:
///   - from: The start color (`t = 0`).
///   - to: The end color (`t = 1`).
///   - t: The blend factor (0.0–1.0; clamped).
/// - Returns: A `.trueColor` interpolated between `from` and `to`.
public func blend(_ from: Color, _ to: Color, t: Double) -> Color {
    let t = max(0.0, min(1.0, t))
    let (r1, g1, b1) = from.toRGBDouble()
    let (r2, g2, b2) = to.toRGBDouble()
    let r = r1 + (r2 - r1) * t
    let g = g1 + (g2 - g1) * t
    let b = b1 + (b2 - b1) * t
    let clamp = { (v: Double) -> UInt8 in UInt8(min(255, max(0, Int(v * 255.0 + 0.5)))) }
    return .trueColor(r: clamp(r), g: clamp(g), b: clamp(b))
}

// MARK: - Gradient Generation

/// Returns an array of `count` colors that blend linearly from `start` to `end`.
///
/// The interpolation is performed by linearly interpolating the stored sRGB
/// channel values (identical to ``blend(_:_:t:)``). All color variants are
/// supported for `start` and `end`; results are always `.trueColor` values.
///
/// Special cases:
/// - `count ≤ 0`: returns `[]`.
/// - `count == 1`: returns `[start]` (as a `.trueColor` value).
/// - `count == 2`: returns `[start, end]` (both as `.trueColor` values).
///
/// ```swift
/// let ramp = gradient(from: .ansi(.red), to: .ansi(.blue), steps: 5)
/// // 5 .trueColor values progressing from red to blue
/// ```
///
/// - Parameters:
///   - start: The color at index 0.
///   - end: The color at the last index.
///   - count: The number of color stops to generate.
/// - Returns: An array of `.trueColor` values of length `count`.
public func gradient(from start: Color, to end: Color, steps count: Int) -> [Color] {
    guard count > 0 else { return [] }
    guard count > 1 else { return [blend(start, end, t: 0.0)] }
    return (0..<count).map { i in
        let t = Double(i) / Double(count - 1)
        return blend(start, end, t: t)
    }
}

/// Returns a `width × height` grid of colors blending across two dimensions.
///
/// Colors are bilinearly interpolated from the four corner colors:
/// - Top row: `topLeft` → `topRight`
/// - Bottom row: `bottomLeft` → `bottomRight`
/// - Each column blends from top to bottom.
///
/// All color variants are supported for the corners; results are always
/// `.trueColor` values.
///
/// The returned array contains `height` rows, each of which contains
/// `width` colors. An empty array is returned if either dimension is ≤ 0.
///
/// ```swift
/// let grid = gradient2D(
///     width: 4, height: 3,
///     topLeft: .ansi(.red),    topRight: .ansi(.blue),
///     bottomLeft: .ansi(.green), bottomRight: .ansi(.yellow)
/// )
/// // grid[row][col] — height rows of width colors
/// ```
///
/// - Parameters:
///   - width: The number of columns.
///   - height: The number of rows.
///   - topLeft: Color at grid position (0, 0).
///   - topRight: Color at grid position (0, width-1).
///   - bottomLeft: Color at grid position (height-1, 0).
///   - bottomRight: Color at grid position (height-1, width-1).
/// - Returns: A 2D array `[row][col]` of `.trueColor` values.
public func gradient2D(
    width: Int,
    height: Int,
    topLeft: Color,
    topRight: Color,
    bottomLeft: Color,
    bottomRight: Color
) -> [[Color]] {
    guard width > 0, height > 0 else { return [] }

    return (0..<height).map { row in
        let ty = height == 1 ? 0.0 : Double(row) / Double(height - 1)
        // Interpolate left and right edges vertically
        let left  = blend(topLeft, bottomLeft, t: ty)
        let right = blend(topRight, bottomRight, t: ty)
        // Interpolate along the row
        return (0..<width).map { col in
            let tx = width == 1 ? 0.0 : Double(col) / Double(width - 1)
            return blend(left, right, t: tx)
        }
    }
}
