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

    /// The wrap-vs-truncate write policy applied by ``write(_:at:row:wrapping:)``
    /// when the caller passes no explicit `wrapping:` argument.
    ///
    /// `false` (the default) truncates characters that overflow the right
    /// edge; `true` wraps them onto the next row. Truncate is the
    /// behavior-preserving default: the engine's leaf rasterizer
    /// (``ViewOutput/_embed(into:at:)``) and the parity harness
    /// construct buffers without an explicit policy and pin **truncation** on
    /// them (inline-mode semantics). The renderer and the free
    /// ``layout(_:width:height:wrapping:)`` function always pass an explicit
    /// policy, so this default only affects direct `write(_:)` calls.
    private let wrapsOverflow: Bool

    /// The rect new writes are currently clipped to, in buffer coordinates.
    ///
    /// `nil` means the whole buffer. This is the hard-box contract's scissor:
    /// ``embed(_:at:)`` intersects it on every descent, and ``set(col:row:_:)``
    /// refuses writes outside it. Invariant repair (clearing a stale
    /// wide-character partner) may still touch a neighbouring cell so the
    /// buffer never holds half a wide glyph.
    private var clipRect: ViewRect?

    /// Create a buffer filled with the given cell.
    ///
    /// - Parameters:
    ///   - width: Buffer width in display columns.
    ///   - height: Buffer height in rows.
    ///   - fill: The cell every position starts as. Defaults to ``Cell/empty``.
    ///   - wrapping: The buffer's wrap-vs-truncate write policy
    ///     (see ``wrapsOverflow``). Defaults to `false` (truncate).
    public init(width: Int, height: Int, fill: Cell = .empty, wrapping: Bool = false) {
        self.width = max(width, 0)
        self.height = max(height, 0)
        self.cells = Array(repeating: fill, count: self.width * self.height)
        self.wrapsOverflow = wrapping
        self.clipRect = nil
    }

    // MARK: - Access

    /// Get a cell at (col, row). Returns `.empty` if out of bounds.
    public subscript(col: Int, row: Int) -> Cell {
        guard row >= 0, row < height, col >= 0, col < width else { return .empty }
        return cells[row * width + col]
    }

    /// Set a cell with wide character invariant enforcement.
    ///
    /// Writes outside the buffer or outside the active ``clipRect`` are
    /// dropped. A wide character whose second column falls outside the active
    /// clip is dropped as a whole (a blank cell is left in its place), so a
    /// clipped write never splits a glyph.
    public mutating func set(col: Int, row: Int, _ cell: Cell) {
        guard row >= 0, row < height, col >= 0, col < width else { return }

        // Hard-box scissor: no new content may land outside the allocation.
        let rightEdge: Int
        if let clip = clipRect {
            guard col >= clip.origin.col,
                  row >= clip.origin.row,
                  col < clip.origin.col + clip.size.width,
                  row < clip.origin.row + clip.size.height
            else { return }
            rightEdge = min(width, clip.origin.col + clip.size.width)
        } else {
            rightEdge = width
        }

        let idx = row * width + col
        let oldCell = cells[idx]

        // Clean up the old cell's relationships before overwriting.
        //
        // Cleanup may touch a neighbouring cell just outside the clip: a
        // wide glyph partially covered by a clipped write must not survive as
        // half a glyph. That is invariant repair, not painting outside the box.

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
            // Wide character: clip if it would cross the clip's right edge.
            if col + 1 >= rightEdge {
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
    ///   - wrapping: When `true`, characters that overflow the right edge are
    ///     wrapped onto the next row. When `false`, overflow characters are
    ///     **truncated** — skipped until the next explicit `\n`. When `nil`
    ///     (default), the buffer's construction-time policy
    ///     (``init(width:height:fill:wrapping:)``) is used.
    public mutating func write(
        _ text: StyledText,
        at startCol: Int = 0,
        row startRow: Int = 0,
        wrapping: Bool? = nil
    ) {
        let shouldWrap = wrapping ?? wrapsOverflow
        var col = startCol
        var row = startRow

        for segment in text.segments {
            let style = segment.style
            for char in segment.text {
                if char == "\n" {
                    // Reset to the column this write began at, so multi-line
                    // content rendered at a column offset keeps every line
                    // aligned.
                    col = startCol
                    row += 1
                    if row >= height { return }
                    continue
                }

                let charWidth = displayWidth(of: char)

                // Skip zero-width characters (combining marks).
                if charWidth == 0 { continue }

                // Check if character fits on current line.
                if col + charWidth > width {
                    if shouldWrap {
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
                    hyperlink: style.hyperlink,
                    underlineStyle: style.underlineStyle,
                    underlineColor: style.underlineColor
                )

                set(col: col, row: row, cell)
                col += charWidth
            }
        }
    }

    // MARK: - Hard-box embedding

    /// Embed a view under the hard-box contract.
    ///
    /// The active clip becomes the intersection of the current clip and
    /// `rect` for the duration of the call, so neither `view` nor any of its
    /// descendants can write outside the allocation. Containers call this for
    /// every child; the renderer calls it for the root. The previous clip is
    /// restored afterwards, so sibling allocations are independent.
    public mutating func embed(_ view: any View, at rect: ViewRect) {
        let previous = clipRect
        clipRect = previous?.intersection(rect) ?? rect
        view._embed(into: &self, at: rect)
        clipRect = previous
    }

    // MARK: - Resize and clear

    /// Resize the buffer. Existing content is discarded.
    ///
    /// An active hard-box clip is preserved and intersected with the new
    /// bounds, so a view that resizes the buffer from inside its `_embed`
    /// cannot use the resize to escape its allocation.
    public mutating func resize(width: Int, height: Int) {
        self.width = max(width, 0)
        self.height = max(height, 0)
        self.cells = Array(repeating: .empty, count: self.width * self.height)
        if let clip = clipRect {
            clipRect = clip.intersection(
                ViewRect(size: ViewSize(width: self.width, height: self.height))
            )
        }
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
