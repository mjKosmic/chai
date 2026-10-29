/// Horizontal and vertical alignment options used by the layout containers.
///
/// Both types are fraction-based structs: `0.0` means flush-start (left / top),
/// `1.0` means flush-end (right / bottom), and `0.5` means centred. Any value
/// in between produces proportional placement, so you can position content at,
/// e.g., the 75 % mark without special-casing.
///
/// Common positions are available as static properties:
///
/// ```swift
/// HorizontalAlignment.left    // 0.0
/// HorizontalAlignment.center  // 0.5
/// HorizontalAlignment.right   // 1.0
///
/// VerticalAlignment.top       // 0.0
/// VerticalAlignment.middle    // 0.5
/// VerticalAlignment.bottom    // 1.0
/// ```
///
/// You can also create custom positions:
///
/// ```swift
/// let quarterRight = HorizontalAlignment(fraction: 0.25)
/// let threeQuartersDown = VerticalAlignment(fraction: 0.75)
/// ```

// MARK: - Alignment types

/// The horizontal position of content within an available width.
///
/// A `fraction` of `0.0` places content flush-left, `1.0` flush-right, and
/// `0.5` centred. Values between produce proportional placement.
public struct HorizontalAlignment: Sendable, Equatable, ExpressibleByFloatLiteral {

    /// The position as a fraction from `0.0` (left) to `1.0` (right).
    public let fraction: Double

    /// Creates an alignment at the given fractional position.
    ///
    /// Values are clamped to the `0.0 ... 1.0` range.
    public init(fraction: Double) {
        self.fraction = min(1, max(0, fraction))
    }

    public init(floatLiteral value: Double) {
        self.init(fraction: value)
    }

    /// Content is flush with the left edge; right side padded with spaces.
    public static let left = HorizontalAlignment(fraction: 0.0)

    /// Content is centred; excess space split evenly (odd remainder goes right).
    public static let center = HorizontalAlignment(fraction: 0.5)

    /// Content is flush with the right edge; left side padded with spaces.
    public static let right = HorizontalAlignment(fraction: 1.0)
}

/// The vertical position of content within an available height.
///
/// A `fraction` of `0.0` places content at the top, `1.0` at the bottom, and
/// `0.5` centred. Values between produce proportional placement.
public struct VerticalAlignment: Sendable, Equatable, ExpressibleByFloatLiteral {

    /// The position as a fraction from `0.0` (top) to `1.0` (bottom).
    public let fraction: Double

    /// Creates an alignment at the given fractional position.
    ///
    /// Values are clamped to the `0.0 ... 1.0` range.
    public init(fraction: Double) {
        self.fraction = min(1, max(0, fraction))
    }

    public init(floatLiteral value: Double) {
        self.init(fraction: value)
    }

    /// Content starts at the top; bottom padded with blank lines.
    public static let top = VerticalAlignment(fraction: 0.0)

    /// Content is centred; excess blank lines split evenly (odd remainder goes bottom).
    public static let middle = VerticalAlignment(fraction: 0.5)

    /// Content ends at the bottom; top padded with blank lines.
    public static let bottom = VerticalAlignment(fraction: 1.0)
}
