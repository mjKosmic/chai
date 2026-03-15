/// The set of characters used to draw a rectangular border.
///
/// Each field is a single terminal-column string. All built-in presets use
/// single Unicode characters, so width calculations remain exact. If you define
/// a custom `Border`, ensure every character is exactly one terminal column wide.
///
/// ```swift
/// // Use a built-in preset
/// let style = Border.rounded
///
/// // Define a custom border
/// let myBorder = Border(
///     top: "~", bottom: "~", left: "!", right: "!",
///     topLeft: "*", topRight: "*", bottomLeft: "*", bottomRight: "*"
/// )
/// ```
///
/// Apply a border to a string with ``border(_:_:top:right:bottom:left:)``.
public struct Border: Sendable, Equatable {

    // MARK: - Edge characters

    /// Character repeated across the top edge.
    public var top: String

    /// Character repeated across the bottom edge.
    public var bottom: String

    /// Character placed on the left edge of each content line.
    public var left: String

    /// Character placed on the right edge of each content line.
    public var right: String

    // MARK: - Corner characters

    /// Top-left corner character.
    public var topLeft: String

    /// Top-right corner character.
    public var topRight: String

    /// Bottom-left corner character.
    public var bottomLeft: String

    /// Bottom-right corner character.
    public var bottomRight: String

    // MARK: - Initializer

    /// Creates a border with explicit characters for every edge and corner.
    public init(
        top: String, bottom: String,
        left: String, right: String,
        topLeft: String, topRight: String,
        bottomLeft: String, bottomRight: String
    ) {
        self.top = top
        self.bottom = bottom
        self.left = left
        self.right = right
        self.topLeft = topLeft
        self.topRight = topRight
        self.bottomLeft = bottomLeft
        self.bottomRight = bottomRight
    }
}

// MARK: - Built-in presets

extension Border {

    /// A standard single-line border using light box-drawing characters.
    ///
    /// ```
    /// ┌──────┐
    /// │ text │
    /// └──────┘
    /// ```
    public static let normal = Border(
        top: "─", bottom: "─", left: "│", right: "│",
        topLeft: "┌", topRight: "┐", bottomLeft: "└", bottomRight: "┘"
    )

    /// A border with rounded corners.
    ///
    /// ```
    /// ╭──────╮
    /// │ text │
    /// ╰──────╯
    /// ```
    public static let rounded = Border(
        top: "─", bottom: "─", left: "│", right: "│",
        topLeft: "╭", topRight: "╮", bottomLeft: "╰", bottomRight: "╯"
    )

    /// A border using heavy box-drawing characters.
    ///
    /// ```
    /// ┏━━━━━━┓
    /// ┃ text ┃
    /// ┗━━━━━━┛
    /// ```
    public static let thick = Border(
        top: "━", bottom: "━", left: "┃", right: "┃",
        topLeft: "┏", topRight: "┓", bottomLeft: "┗", bottomRight: "┛"
    )

    /// A border using double-line box-drawing characters.
    ///
    /// ```
    /// ╔══════╗
    /// ║ text ║
    /// ╚══════╝
    /// ```
    public static let double = Border(
        top: "═", bottom: "═", left: "║", right: "║",
        topLeft: "╔", topRight: "╗", bottomLeft: "╚", bottomRight: "╝"
    )

    /// A border using ASCII-only characters.
    ///
    /// ```
    /// +------+
    /// | text |
    /// +------+
    /// ```
    public static let ascii = Border(
        top: "-", bottom: "-", left: "|", right: "|",
        topLeft: "+", topRight: "+", bottomLeft: "+", bottomRight: "+"
    )

    /// An invisible border that reserves the same space as `normal` without
    /// drawing any visible lines.
    ///
    /// Useful for maintaining consistent dimensions when toggling borders.
    public static let hidden = Border(
        top: " ", bottom: " ", left: " ", right: " ",
        topLeft: " ", topRight: " ", bottomLeft: " ", bottomRight: " "
    )
}
