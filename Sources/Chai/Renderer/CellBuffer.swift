// MARK: - CellChange

/// A single changed position in a cell diff.
public struct CellChange: Sendable, Equatable {
    public let col: Int
    public let row: Int

    public init(col: Int, row: Int) {
        self.col = col
        self.row = row
    }
}

// MARK: - CellDiff

/// Result of diffing two CellBuffers.
public struct CellDiff: Sendable, Equatable {
    /// Changed cell positions to be re-rendered.
    public var changes: [CellChange]

    /// True if the old buffer had more rows that need erasing.
    public var eraseBelow: Bool

    public init(changes: [CellChange] = [], eraseBelow: Bool = false) {
        self.changes = changes
        self.eraseBelow = eraseBelow
    }
}

// MARK: - CellBuffer

/// A 2D grid of cells representing terminal screen content.
///
/// Supports both alt-screen (fixed terminal size) and inline
/// (content-sized) rendering. Enforces wide character invariants.
public struct CellBuffer: Sendable, Equatable {

    /// Buffer width in display columns.
    public private(set) var width: Int

    /// Buffer height in rows.
    public private(set) var height: Int

    /// Row-major storage: cells[row * width + col].
    private var cells: [Cell]

    /// Create a buffer filled with the given cell.
    public init(width: Int, height: Int, fill: Cell = .empty) {
        self.width = max(width, 0)
        self.height = max(height, 0)
        self.cells = Array(repeating: fill, count: self.width * self.height)
    }

    // MARK: - Access

    /// Get a cell at (col, row). Returns `.empty` if out of bounds.
    public subscript(col: Int, row: Int) -> Cell {
        guard row >= 0, row < height, col >= 0, col < width else { return .empty }
        return cells[row * width + col]
    }

    /// Set a cell with wide character invariant enforcement.
    public mutating func set(col: Int, row: Int, _ cell: Cell) {
        guard row >= 0, row < height, col >= 0, col < width else { return }

        let idx = row * width + col
        let oldCell = cells[idx]

        // Clean up the old cell's relationships before overwriting.

        // If the old cell was a wide primary (width 2), clear its continuation.
        if oldCell.width == 2 && col + 1 < width {
            cells[idx + 1] = .empty
        }

        // If the old cell was a continuation (width 0), clear its primary.
        if oldCell.width == 0 && col > 0 {
            let primaryIdx = row * width + (col - 1)
            if cells[primaryIdx].width == 2 {
                cells[primaryIdx] = .empty
            }
        }

        // Handle the new cell.
        if cell.width == 2 {
            // Wide character: clip if at last column.
            if col + 1 >= width {
                // Can't fit — place a space instead.
                cells[idx] = .empty
                return
            }
            cells[idx] = cell
            // Auto-create continuation at col+1.
            // First clean up what's at col+1 if it's a wide primary.
            let nextIdx = idx + 1
            let nextOld = cells[nextIdx]
            if nextOld.width == 2 && col + 2 < width {
                cells[nextIdx + 1] = .empty
            }
            cells[nextIdx] = .wideContinuation
        } else {
            cells[idx] = cell
        }
    }

    // MARK: - Layout

    /// Layout styled text into the buffer, starting at (col, row).
    ///
    /// - Parameters:
    ///   - text: The styled text to write.
    ///   - startCol: Starting column (default 0).
    ///   - startRow: Starting row (default 0).
    ///   - wrapping: When `true` (default), characters that overflow the right
    ///     edge are wrapped onto the next row. When `false`, overflow characters
    ///     are **truncated** — skipped until the next explicit `\n`. Use `false`
    ///     when the buffer height was sized by ``StyledText/lineCount()`` (i.e.
    ///     inline-mode rendering) to prevent wrapped content from stealing rows
    ///     that are allocated for subsequent logical lines.
    public mutating func write(
        _ text: StyledText,
        at startCol: Int = 0,
        row startRow: Int = 0,
        wrapping: Bool = true
    ) {
        var col = startCol
        var row = startRow

        for segment in text.segments {
            let style = segment.style
            for char in segment.text {
                if char == "\n" {
                    col = 0
                    row += 1
                    if row >= height { return }
                    continue
                }

                let charWidth = displayWidth(of: char)

                // Skip zero-width characters (combining marks).
                if charWidth == 0 { continue }

                // Check if character fits on current line.
                if col + charWidth > width {
                    if wrapping {
                        // Wrap to next line.
                        col = 0
                        row += 1
                        if row >= height { return }
                    } else {
                        // Truncate: skip this character and the rest of the
                        // line until the next explicit newline.
                        continue
                    }
                }

                let cell = Cell(
                    character: char,
                    width: Int8(charWidth),
                    foreground: style.foreground,
                    background: style.background,
                    attributes: style.attributes,
                    hyperlink: style.hyperlink
                )

                set(col: col, row: row, cell)
                col += charWidth
            }
        }
    }

    // MARK: - Resize and clear

    /// Resize the buffer. Existing content is discarded.
    public mutating func resize(width: Int, height: Int) {
        self.width = max(width, 0)
        self.height = max(height, 0)
        self.cells = Array(repeating: .empty, count: self.width * self.height)
    }

    /// Clear all cells.
    public mutating func clear() {
        cells = Array(repeating: .empty, count: width * height)
    }

    // MARK: - Diffing

    /// Compare against another buffer, identifying changed positions.
    ///
    /// Handles mismatched sizes:
    /// - Missing old cells are treated as empty.
    /// - Extra old rows signal `eraseBelow: true`.
    public func diff(against old: CellBuffer) -> CellDiff {
        var changes: [CellChange] = []
        let eraseBelow = old.height > height

        for row in 0..<height {
            for col in 0..<width {
                let newCell = self[col, row]
                let oldCell = old[col, row]
                if newCell != oldCell {
                    changes.append(CellChange(col: col, row: row))
                }
            }
        }

        return CellDiff(changes: changes, eraseBelow: eraseBelow)
    }
}

// MARK: - Layout function

/// Layout styled text into a cell buffer with the given dimensions.
///
/// - Parameters:
///   - text: The styled text to lay out.
///   - width: Buffer width in columns.
///   - height: Buffer height in rows.
///   - wrapping: When `true` (default), content that overflows the right edge
///     is wrapped onto the next row. Pass `false` for inline rendering where
///     buffer height is derived from ``StyledText/lineCount()``.
public func layout(_ text: StyledText, width: Int, height: Int, wrapping: Bool = true) -> CellBuffer {
    var buffer = CellBuffer(width: width, height: height)
    buffer.write(text, wrapping: wrapping)
    return buffer
}
