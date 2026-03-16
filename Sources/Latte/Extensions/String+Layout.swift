/// Chainable String extensions that wrap Latte's free functions.
///
/// These extensions provide an alternative to nested function calls, turning:
///
/// ```swift
/// margin(border(pad(content, 1, 2), .rounded), top: 1, left: 2)
/// ```
///
/// into:
///
/// ```swift
/// content.padded(1, 2).bordered(.rounded).margined(top: 1, left: 2)
/// ```
///
/// Both styles are equivalent and always available. The free functions remain
/// the canonical API; these extensions are purely syntactic sugar.

extension String {

    // MARK: - Padding

    /// Adds interior padding around this text block.
    ///
    /// Wraps ``pad(_:top:right:bottom:left:fill:)``.
    public func padded(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0,
        fill: Character = " "
    ) -> String {
        pad(self, top: top, right: right, bottom: bottom, left: left, fill: fill)
    }

    /// Adds equal padding on all four sides.
    ///
    /// Wraps ``pad(_:_:fill:)``.
    public func padded(_ all: Int, fill: Character = " ") -> String {
        pad(self, all, fill: fill)
    }

    /// Adds padding using the two-value CSS shorthand: vertical, horizontal.
    ///
    /// Wraps ``pad(_:_:_:fill:)``.
    public func padded(_ vertical: Int, _ horizontal: Int, fill: Character = " ") -> String {
        pad(self, vertical, horizontal, fill: fill)
    }

    /// Adds padding using the three-value CSS shorthand: top, sides, bottom.
    ///
    /// Wraps ``pad(_:_:_:_:fill:)``.
    public func padded(_ top: Int, _ sides: Int, _ bottom: Int, fill: Character = " ") -> String {
        pad(self, top, sides, bottom, fill: fill)
    }

    // MARK: - Margin

    /// Adds exterior margin around this text block.
    ///
    /// Wraps ``margin(_:top:right:bottom:left:fill:)``.
    public func margined(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0,
        fill: Character = " "
    ) -> String {
        margin(self, top: top, right: right, bottom: bottom, left: left, fill: fill)
    }

    /// Adds equal margin on all four sides.
    ///
    /// Wraps ``margin(_:_:fill:)``.
    public func margined(_ all: Int, fill: Character = " ") -> String {
        margin(self, all, fill: fill)
    }

    /// Adds margin using the two-value CSS shorthand: vertical, horizontal.
    ///
    /// Wraps ``margin(_:_:_:fill:)``.
    public func margined(_ vertical: Int, _ horizontal: Int, fill: Character = " ") -> String {
        margin(self, vertical, horizontal, fill: fill)
    }

    /// Adds margin using the three-value CSS shorthand: top, sides, bottom.
    ///
    /// Wraps ``margin(_:_:_:_:fill:)``.
    public func margined(_ top: Int, _ sides: Int, _ bottom: Int, fill: Character = " ") -> String {
        margin(self, top, sides, bottom, fill: fill)
    }

    // MARK: - Border

    /// Draws a border around this text block.
    ///
    /// Wraps ``border(_:_:top:right:bottom:left:borderStyle:topStyle:bottomStyle:leftStyle:rightStyle:)``.
    ///
    /// ```swift
    /// // Latte-only: raw ANSI escape codes
    /// "Hello".bordered(.rounded, borderStyle: { "\u{1B}[36m\($0)\u{1B}[0m" })
    ///
    /// // With Spices (import Spices) — Style.render(_:) is (String) -> String
    /// import Spices
    /// let cyan = Style().foreground(.ansi(.cyan))
    /// let red  = Style().foreground(.ansi(.red))
    /// let blue = Style().foreground(.ansi(.blue))
    /// "Hello".bordered(.rounded, borderStyle: cyan.render)
    /// "Hello".bordered(.rounded, topStyle: red.render, bottomStyle: blue.render)
    /// ```
    public func bordered(
        _ style: Border = .rounded,
        top: Bool = true,
        right: Bool = true,
        bottom: Bool = true,
        left: Bool = true,
        borderStyle: (@Sendable (String) -> String)? = nil,
        topStyle: (@Sendable (String) -> String)? = nil,
        bottomStyle: (@Sendable (String) -> String)? = nil,
        leftStyle: (@Sendable (String) -> String)? = nil,
        rightStyle: (@Sendable (String) -> String)? = nil
    ) -> String {
        border(self, style, top: top, right: right, bottom: bottom, left: left,
               borderStyle: borderStyle, topStyle: topStyle, bottomStyle: bottomStyle,
               leftStyle: leftStyle, rightStyle: rightStyle)
    }

    // MARK: - Alignment

    /// Aligns each line within a fixed column width.
    ///
    /// Wraps ``align(_:width:_:)``.
    public func aligned(width: Int, _ alignment: HorizontalAlignment = .left) -> String {
        align(self, width: width, alignment)
    }

    // MARK: - Size enforcement

    /// Ensures every line is at least `width` visible columns.
    ///
    /// Wraps ``enforceWidth(_:_:alignment:)``.
    public func enforced(
        width: Int,
        alignment: HorizontalAlignment = .left
    ) -> String {
        enforceWidth(self, width, alignment: alignment)
    }

    /// Ensures this text block has at least `height` lines.
    ///
    /// Wraps ``enforceHeight(_:_:alignment:)``.
    public func enforced(
        height: Int,
        alignment: VerticalAlignment = .top
    ) -> String {
        enforceHeight(self, height, alignment: alignment)
    }

    // MARK: - Clamping

    /// Truncates each line to at most `width` visible columns.
    ///
    /// Wraps ``clampWidth(_:_:)``.
    public func clamped(width: Int) -> String {
        clampWidth(self, width)
    }

    /// Drops lines beyond `height`.
    ///
    /// Wraps ``clampHeight(_:_:)``.
    public func clamped(height: Int) -> String {
        clampHeight(self, height)
    }

    /// Caps both width and height.
    ///
    /// Wraps ``clamp(_:maxWidth:maxHeight:)``.
    public func clamped(maxWidth: Int, maxHeight: Int) -> String {
        clamp(self, maxWidth: maxWidth, maxHeight: maxHeight)
    }

    // MARK: - Placement

    /// Places this text block within a fixed-size canvas.
    ///
    /// Wraps ``place(width:height:horizontal:vertical:_:)``.
    public func placed(
        width: Int,
        height: Int,
        horizontal: HorizontalAlignment,
        vertical: VerticalAlignment
    ) -> String {
        place(width: width, height: height, horizontal: horizontal, vertical: vertical, self)
    }

    /// Places this text block within a fixed-width horizontal canvas.
    ///
    /// Wraps ``placeHorizontal(width:_:_:)``.
    public func placedHorizontally(
        width: Int,
        _ alignment: HorizontalAlignment
    ) -> String {
        placeHorizontal(width: width, alignment, self)
    }

    /// Places this text block within a fixed-height vertical canvas.
    ///
    /// Wraps ``placeVertical(height:_:_:)``.
    public func placedVertically(
        height: Int,
        _ alignment: VerticalAlignment
    ) -> String {
        placeVertical(height: height, alignment, self)
    }

    // MARK: - Truncation

    /// Truncates this string to at most `maxWidth` visible terminal columns.
    ///
    /// Wraps ``truncateToVisibleWidth(_:maxWidth:)``.
    public func truncated(toVisibleWidth maxWidth: Int) -> String {
        truncateToVisibleWidth(self, maxWidth: maxWidth)
    }

    // MARK: - Wrapping

    /// Word-wraps this text to fit within `width` visible columns.
    ///
    /// Wraps ``wrap(_:width:breakCharacter:)``.
    public func wrapped(width: Int, breakCharacter: Character = " ") -> String {
        wrap(self, width: width, breakCharacter: breakCharacter)
    }

    // MARK: - Utilities

    /// Expands tab characters into spaces respecting column-aware tab stops.
    ///
    /// Wraps ``expandTabs(_:tabWidth:)``.
    public func tabsExpanded(tabWidth: Int = 4) -> String {
        expandTabs(self, tabWidth: tabWidth)
    }

    /// Returns the first line of this text block.
    ///
    /// Wraps ``inline(_:)``.
    public func inlined() -> String {
        inline(self)
    }
}
