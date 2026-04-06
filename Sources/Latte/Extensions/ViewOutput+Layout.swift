import Chai

/// Fluent layout extensions for ``ViewOutput``.
///
/// Each method transforms the view's content while preserving terminal state
/// (``ViewOutput/altScreen``, ``ViewOutput/windowTitle``, ``ViewOutput/cursor``).

// MARK: - Sizing

extension ViewOutput {

    /// Enforce a minimum width, padding each line to `w` columns.
    ///
    /// Lines already wider than `w` are unchanged.
    ///
    /// - Parameters:
    ///   - w: The minimum column width.
    ///   - align: How content is aligned within the width. Defaults to `.left`.
    public func width(_ w: Int, align: HorizontalAlignment = .left) -> ViewOutput {
        transformContent { $0.enforceWidth(w, alignment: align) }
    }

    /// Enforce a minimum height, adding blank lines to reach `h` lines.
    ///
    /// Content with `h` or more lines is unchanged.
    ///
    /// - Parameters:
    ///   - h: The minimum line count.
    ///   - align: How content is aligned within the height. Defaults to `.top`.
    public func height(_ h: Int, align: VerticalAlignment = .top) -> ViewOutput {
        transformContent { $0.enforceHeight(h, alignment: align) }
    }

    /// Enforce both minimum width and height.
    ///
    /// - Parameters:
    ///   - width: The minimum column width.
    ///   - height: The minimum line count.
    public func size(width: Int, height: Int) -> ViewOutput {
        transformContent { $0.enforceWidth(width).enforceHeight(height) }
    }

    /// Enforce both minimum width and height with independent alignment on each axis.
    ///
    /// This is the alignment-aware counterpart to ``size(width:height:)``. The
    /// primary use case is centering a root view within the terminal dimensions
    /// received from ``WindowSizeMsg``:
    ///
    /// ```swift
    /// ViewOutput(content)
    ///     .frame(
    ///         width: termWidth,
    ///         height: termHeight,
    ///         horizontalAlignment: .center,
    ///         verticalAlignment: .middle
    ///     )
    /// ```
    ///
    /// Lines already wider than `width` or content already taller than `height`
    /// are unchanged — this enforces minimums, not maximums.
    ///
    /// - Parameters:
    ///   - width: The minimum column width.
    ///   - height: The minimum line count.
    ///   - horizontalAlignment: How to distribute horizontal padding. Defaults to `.left`.
    ///   - verticalAlignment: Where to place the content vertically. Defaults to `.top`.
    public func frame(
        width: Int,
        height: Int,
        horizontalAlignment: HorizontalAlignment = .left,
        verticalAlignment: VerticalAlignment = .top
    ) -> ViewOutput {
        transformContent {
            $0.enforceWidth(width, alignment: horizontalAlignment)
              .enforceHeight(height, alignment: verticalAlignment)
        }
    }

    /// Truncate each line to at most `max` display columns.
    ///
    /// - Parameter max: The maximum column width.
    public func clampedWidth(_ max: Int) -> ViewOutput {
        transformContent { $0.clampWidth(max) }
    }

    /// Keep only the first `max` lines.
    ///
    /// - Parameter max: The maximum line count.
    public func clampedHeight(_ max: Int) -> ViewOutput {
        transformContent { $0.clampHeight(max) }
    }
}

// MARK: - Spacing

extension ViewOutput {

    /// Add interior padding around the content.
    ///
    /// - Parameters:
    ///   - top: Lines of padding above the content.
    ///   - right: Columns of padding to the right.
    ///   - bottom: Lines of padding below the content.
    ///   - left: Columns of padding to the left.
    public func padded(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0
    ) -> ViewOutput {
        transformContent {
            $0.pad(
                top: max(0, top),
                right: max(0, right),
                bottom: max(0, bottom),
                left: max(0, left)
            )
        }
    }

    /// Add equal padding on all sides.
    ///
    /// - Parameter amount: The amount of padding on each side.
    public func padded(_ amount: Int) -> ViewOutput {
        padded(top: amount, right: amount, bottom: amount, left: amount)
    }

    /// Add padding with vertical and horizontal values (CSS-style 2-value).
    ///
    /// - Parameters:
    ///   - vertical: Lines of padding above and below.
    ///   - horizontal: Columns of padding left and right.
    public func padded(_ vertical: Int, _ horizontal: Int) -> ViewOutput {
        padded(top: vertical, right: horizontal, bottom: vertical, left: horizontal)
    }

    /// Add exterior margin around the content.
    ///
    /// Functionally identical to ``padded(top:right:bottom:left:)`` at the
    /// StyledText level. The distinction is semantic — margin is outside the
    /// border, padding is inside.
    ///
    /// - Parameters:
    ///   - top: Lines of margin above.
    ///   - right: Columns of margin to the right.
    ///   - bottom: Lines of margin below.
    ///   - left: Columns of margin to the left.
    public func margined(
        top: Int = 0,
        right: Int = 0,
        bottom: Int = 0,
        left: Int = 0
    ) -> ViewOutput {
        transformContent {
            $0.pad(
                top: max(0, top),
                right: max(0, right),
                bottom: max(0, bottom),
                left: max(0, left)
            )
        }
    }

    /// Add equal margin on all sides.
    ///
    /// - Parameter amount: The amount of margin on each side.
    public func margined(_ amount: Int) -> ViewOutput {
        margined(top: amount, right: amount, bottom: amount, left: amount)
    }

    /// Add margin with vertical and horizontal values (CSS-style 2-value).
    ///
    /// - Parameters:
    ///   - vertical: Lines of margin above and below.
    ///   - horizontal: Columns of margin left and right.
    public func margined(_ vertical: Int, _ horizontal: Int) -> ViewOutput {
        margined(top: vertical, right: horizontal, bottom: vertical, left: horizontal)
    }
}

// MARK: - Border

extension ViewOutput {

    /// Draw a border around the content.
    ///
    /// - Parameter style: The ``Border`` character set to use.
    public func bordered(_ style: Border) -> ViewOutput {
        transformContent { $0.bordered(style) }
    }
}

// MARK: - Composition

extension ViewOutput {

    /// Place another view to the right of this one.
    ///
    /// - Parameters:
    ///   - other: The view to place on the right.
    ///   - align: Vertical alignment when views have different heights.
    public func beside(_ other: ViewOutput, align: VerticalAlignment = .top) -> ViewOutput {
        transformContent { $0.beside(other.content, align: align) }
    }

    /// Place another view below this one.
    ///
    /// - Parameters:
    ///   - other: The view to place below.
    ///   - align: Horizontal alignment when views have different widths.
    public func above(_ other: ViewOutput, align: HorizontalAlignment = .left) -> ViewOutput {
        transformContent { $0.above(other.content, align: align) }
    }
}

// MARK: - Internal helper

extension ViewOutput {

    /// Transform the content, returning a new ViewOutput.
    private func transformContent(_ transform: (StyledText) -> StyledText) -> ViewOutput {
        ViewOutput(transform(content))
    }
}
