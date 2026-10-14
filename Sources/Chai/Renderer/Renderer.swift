import Foundation

/// A framerate-based, diff-driven terminal renderer using cell buffers.
///
/// The renderer maintains a pending view buffer and flushes it to the terminal
/// at a configurable frame rate (default 60 FPS). On each flush it lays out the
/// styled content into a ``CellBuffer``, diffs against the previous frame, and
/// only rewrites rows that contain changed cells.
///
/// ## How it works
///
/// 1. ``write(_:)`` stores the latest ``View`` tree in an internal buffer.
/// 2. A background `Task` ticks at `1/fps` seconds and calls ``flush()``.
/// 3. ``flush()`` measures the tree and renders it through the layout engine
///    into a ``CellBuffer``, diffs against ``lastBuffer``, and writes only
///    the changed rows.
///
/// The renderer is an actor to serialise all state mutations.
actor Renderer {

    // MARK: - Configuration

    static let defaultFPS = 60
    static let maxFPS = 120

    /// Fallback buffer width when terminal size is unknown.
    private static let fallbackWidth = 512

    // MARK: - State

    private let terminal: any TerminalOutput
    private let fps: Int

    /// The view tree queued for the next flush.
    ///
    /// Stored as an existential rather than resolved eagerly: ``flush()``
    /// lays the tree out through the phase-2 engine
    /// (``View/_sizeThatFits(_:)`` + ``View/_render(into:at:size:proposal:)``)
    /// into a ``CellBuffer``. `nil` (nothing written yet) renders as an empty
    /// view.
    private var pendingView: (any View)? = nil

    /// The cursor queued for the next flush (set separately from content).
    private var pendingCursor: Cursor?

    /// The cell buffer from the last rendered frame (used for diffing).
    private var lastBuffer = CellBuffer(width: 0, height: 0)

    /// Whether the alternate screen buffer is currently active.
    private(set) var altScreenActive: Bool = false

    /// Current terminal width (updated on WindowSizeMsg).
    private var termWidth: Int = 0
    /// Current terminal height (updated on WindowSizeMsg).
    private var termHeight: Int = 0

    /// Lines queued to be printed above the live view.
    private var queuedLines: [String] = []

    /// Whether the cursor is currently hidden.
    private var cursorHidden: Bool = false

    /// The cursor from the last rendered frame (for diffing).
    private var lastCursor: Cursor?

    /// The row where the terminal cursor is currently parked (0-based,
    /// relative to the top of the rendered content). Used to calculate
    /// movement deltas for cursor-only updates in normal (non-alt-screen) mode.
    private var cursorParkedRow: Int = 0

    /// The last applied window title (for diffing).
    private var lastWindowTitle: String?

    /// The background flush task.
    private var flushTask: Task<Void, Never>?

    // MARK: - Init

    init(terminal: any TerminalOutput, fps: Int = Renderer.defaultFPS) {
        self.terminal = terminal
        self.fps = min(max(fps, 1), Renderer.maxFPS)
    }

    // MARK: - Lifecycle

    /// Start the render loop.
    func start() {
        let interval = Duration.milliseconds(1000 / fps)
        flushTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                // Re-check after the sleep: cancellation is co-operative and
                // `try?` swallows the CancellationError thrown by `Task.sleep`.
                // Without this guard a cancelled task can still call flush()
                // once more, writing to the terminal *after* stop() has already
                // emitted its cleanup sequences (eraseEntireLine + ANSI.reset).
                guard !Task.isCancelled else { break }
                await self?.flush()
            }
        }
    }

    /// Stop the render loop and perform a final flush.
    func stop() {
        flushTask?.cancel()
        flushTask = nil
        flush()
        // Move cursor to start of last line, erase it, then reset all SGR
        // attributes so the shell prompt is not affected by any active styling
        // from the last rendered frame.
        terminal.write(ANSI.eraseEntireLine + "\r")
        terminal.write(ANSI.reset)
    }

    /// Stop immediately without a final flush.
    func kill() {
        flushTask?.cancel()
        flushTask = nil
        terminal.write(ANSI.eraseEntireLine + "\r")
        terminal.write(ANSI.reset)
    }

    // MARK: - View buffer

    /// Queue a new ``ViewOutput`` for rendering on the next tick.
    ///
    /// The renderer will diff the content against the previous frame on the
    /// next ``flush()``.
    func write(_ view: ViewOutput) {
        pendingView = view
    }

    /// Queue any ``View`` for rendering on the next tick.
    ///
    /// The view tree is stored as-is and laid out through the layout engine
    /// on the next ``flush()``. This enables the renderer to accept the
    /// model's ``body`` directly, regardless of its concrete type.
    func write<V: View>(_ view: V) {
        pendingView = view
    }

    /// Set the cursor to display on the next flush.
    ///
    /// When non-`nil`, the terminal cursor is shown at the specified position
    /// with the given shape. When `nil`, the cursor is hidden automatically
    /// in alternate-screen mode; in normal (inline) mode the cursor state is
    /// left unchanged.
    func setCursor(_ cursor: Cursor?) {
        pendingCursor = cursor
    }

    /// Force a full repaint on the next flush by clearing the last-render cache.
    func repaint() {
        lastBuffer = CellBuffer(width: 0, height: 0)
    }

    // MARK: - Flush

    /// Write the pending view to the terminal, diffing against the last frame.
    ///
    /// Cursor visibility is handled first, then content is laid out into a
    /// cell buffer, diffed against the previous frame, and changed rows are
    /// written. Finally the cursor is positioned.
    func flush() {
        // nil pendingView means nothing was written yet — render as an empty
        // view, matching the pre-M3 `ViewOutput("")` default.
        let view = pendingView ?? ViewOutput("")
        let cursor = pendingCursor

        // ── Cursor visibility ──────────────────────────────────────────────

        // When a cursor is specified the cursor must be visible.
        // In alt-screen mode with no cursor, the cursor is hidden
        // automatically. In normal mode with no cursor the state is unchanged.
        if cursor != nil {
            if cursorHidden {
                cursorHidden = false
                terminal.write(ANSI.showCursor)
            }
        } else if altScreenActive && !cursorHidden {
            cursorHidden = true
            terminal.write(ANSI.hideCursor)
        }

        // ── Build cell buffer through the layout engine ────────────────────

        let w = termWidth > 0 ? termWidth : Self.fallbackWidth
        let altScreenHeight = termHeight > 0 ? termHeight : 24

        // The fit proposal: measure the tree under the terminal offer. Inline
        // mode proposes width only (height stays ideal — the buffer is
        // content-sized, clamped below); alt-screen mode proposes the fixed
        // terminal size. The SAME value is passed to the root render call —
        // the fit/render value-equality contract (A0) — so a proposal-
        // consuming child at the root sees the fit proposal, not its assigned
        // (measured) size.
        let proposal = ProposedSize(width: w, height: altScreenActive ? altScreenHeight : nil)

        let measured = view._sizeThatFits(proposal)

        let bufferHeight: Int
        if measured.height == 0 {
            // Empty content: use a single-row buffer to maintain cursor
            // position tracking. The unrendered 1-row buffer is cell-identical
            // to the pre-M3 `" "` write because `Cell.empty` is a space cell,
            // so it won't produce visible output.
            bufferHeight = 1
        } else if altScreenActive {
            bufferHeight = altScreenHeight
        } else if termHeight > 0 {
            // Clamp to terminal height, taking suffix lines.
            bufferHeight = min(measured.height, termHeight)
        } else {
            bufferHeight = measured.height
        }

        // Inline mode truncates (buffer height is content-derived; wrapping
        // would steal rows allocated for subsequent logical lines); alt-screen
        // mode wraps. This is the renderer-level mode decision, expressed as
        // the buffer's construction-time write policy.
        var newBuffer = CellBuffer(width: w, height: bufferHeight, wrapping: altScreenActive)

        // Inline suffix clamp: when the measured height exceeds the terminal
        // height, today's `content.suffix(lines: termHeight)` is reproduced by
        // rendering the tree at a negative row origin — `bufferHeight -
        // measured.height` — with the full measured size. Early rows fall
        // above the buffer and are skipped by `CellBuffer.set(col:row:_:)`'s
        // bounds guards; the bottom `bufferHeight` rows land at buffer rows
        // 0…, byte-identical to the eager suffix. Alt screen renders from the
        // top (rows beyond the fixed height are dropped by the same guards).
        let origin: ViewOrigin
        if !altScreenActive && termHeight > 0 && measured.height > bufferHeight {
            origin = ViewOrigin(col: 0, row: bufferHeight - measured.height)
        } else {
            origin = .zero
        }

        view._render(into: &newBuffer, at: origin, size: measured, proposal: proposal)

        // ── Determine what needs updating ─────────────────────────────────

        let diff = newBuffer.diff(against: lastBuffer)
        let contentChanged = !diff.changes.isEmpty || diff.eraseBelow
        let cursorChanged = cursor != lastCursor

        guard contentChanged || cursorChanged else { return }

        var out = ""

        // ── Content diff and render ───────────────────────────────────────

        if contentChanged {
            // Move cursor back to the start of the previously rendered content.
            if altScreenActive {
                out += ANSI.cursorHome
            } else {
                if cursorParkedRow > 0 {
                    out += ANSI.cursorUp(cursorParkedRow)
                }
                out += "\r"
            }

            // Flush any queued print-above lines.
            let flushQueued = !queuedLines.isEmpty && !altScreenActive
            if flushQueued {
                for line in queuedLines {
                    var renderedLine = line
                    if termWidth > 0 {
                        renderedLine = truncateToVisibleWidth(renderedLine, maxWidth: termWidth)
                    }
                    out += renderedLine + ANSI.reset + ANSI.eraseLineRight + "\r\n"
                }
                queuedLines = []
            }

            // Determine which rows have changes.
            let changedRows = Set(diff.changes.map { $0.row })

            // When lastBuffer is 0×0 the screen state is unknown — stale content
            // may exist at any row, including rows that are blank in the new buffer
            // (e.g. vertical centering padding). Those blank rows diff as unchanged
            // (both sides are .empty), so without this flag they'd be skipped and
            // old content would ghost through. Forcing a full repaint ensures every
            // row gets eraseLineRight.
            let forceFullRepaint = lastBuffer.width == 0 && lastBuffer.height == 0

            // Paint each row, skipping unchanged ones.
            for row in 0..<newBuffer.height {
                let canSkip = !forceFullRepaint && !flushQueued && !changedRows.contains(row)

                if canSkip {
                    if row < newBuffer.height - 1 { out += "\n" }
                    continue
                }

                // On the very first render, reset to column 0.
                if row == 0 && lastBuffer.width == 0 { out += "\r" }

                let rendered = renderRow(newBuffer, row: row)
                out += rendered + ANSI.eraseLineRight

                if row < newBuffer.height - 1 { out += "\r\n" }
            }

            // Erase leftover rows from the previous frame.
            if diff.eraseBelow {
                out += ANSI.eraseScreenBelow
            }

            lastBuffer = newBuffer
        }

        // ── Cursor shape ────────────────────────────────────────────────────

        if let cursor = cursor {
            if cursor.shape != lastCursor?.shape || cursor.blink != lastCursor?.blink {
                out += ANSI.setCursorShape(cursor.shape, blink: cursor.blink)
            }
        }

        // ── Cursor positioning ──────────────────────────────────────────────

        let newLineCount = contentChanged ? newBuffer.height : lastBuffer.height

        let currentRow: Int
        if contentChanged {
            currentRow = max(newLineCount - 1, 0)
        } else {
            currentRow = cursorParkedRow
        }

        if let cursor = cursor {
            let targetRow = cursor.position.row
            if altScreenActive {
                out += ANSI.cursorPosition(row: targetRow + 1, col: cursor.position.col + 1)
            } else {
                let rowDiff = targetRow - currentRow
                if rowDiff < 0 { out += ANSI.cursorUp(-rowDiff) }
                else if rowDiff > 0 { out += ANSI.cursorDown(rowDiff) }
                out += ANSI.cursorColumn(cursor.position.col + 1)
            }
            cursorParkedRow = targetRow
        } else {
            // No cursor — park at the default position (start of last line).
            let targetRow = max(newLineCount - 1, 0)
            if altScreenActive {
                out += ANSI.cursorPosition(row: newLineCount, col: 1)
            } else if contentChanged {
                // After content painting we are already on the last line.
                out += "\r"
            } else {
                // Cursor-only update (cursor removed): move to last line.
                let rowDiff = targetRow - currentRow
                if rowDiff < 0 { out += ANSI.cursorUp(-rowDiff) }
                else if rowDiff > 0 { out += ANSI.cursorDown(rowDiff) }
                out += "\r"
            }
            cursorParkedRow = targetRow
        }

        lastCursor = cursor

        terminal.write(ANSI.beginSyncUpdate + out + ANSI.endSyncUpdate)
    }

    // MARK: - Row rendering

    /// Render all non-trailing-empty cells in a row as a terminal string.
    ///
    /// Batches consecutive cells with the same style to minimize SGR output.
    /// Continuation cells (width 0) are skipped. Trailing empty cells are omitted.
    private func renderRow(_ buffer: CellBuffer, row: Int) -> String {
        // Find the last column with a non-empty cell.
        var lastNonEmpty = -1
        for col in stride(from: buffer.width - 1, through: 0, by: -1) {
            if buffer[col, row] != .empty {
                lastNonEmpty = col
                break
            }
        }

        guard lastNonEmpty >= 0 else { return "" }

        var result = ""
        var col = 0
        while col <= lastNonEmpty {
            let cell = buffer[col, row]

            // Skip continuation cells.
            if cell.width == 0 {
                col += 1
                continue
            }

            // Build SGR for this cell's style.
            let sgr = cellSGR(cell)
            let hasHyperlink = cell.hyperlink != nil

            // Batch consecutive cells with the same style.
            var chars = String(cell.character)
            var nextCol = col + Int(cell.width)
            while nextCol <= lastNonEmpty {
                let next = buffer[nextCol, row]
                if next.width == 0 { nextCol += 1; continue }
                if cellSGR(next) != sgr || next.hyperlink != cell.hyperlink { break }
                chars += String(next.character)
                nextCol += Int(next.width)
            }

            // Emit hyperlink open if needed.
            if let url = cell.hyperlink {
                result += ANSI.osc8(url: url)
            }

            // Emit SGR + characters + reset.
            if sgr.isEmpty && !hasHyperlink {
                result += chars
            } else {
                if !sgr.isEmpty {
                    result += "\u{1B}[\(sgr)m"
                }
                result += chars
                if !sgr.isEmpty {
                    result += ANSI.reset
                }
                if hasHyperlink {
                    result += ANSI.osc8Reset
                }
            }

            col = nextCol
        }
        return result
    }

    /// Build the SGR parameter string for a cell's style.
    private func cellSGR(_ cell: Cell) -> String {
        var parts: [String] = []
        if let fg = cell.foreground { parts.append(fg.sgrParams(foreground: true)) }
        if let bg = cell.background { parts.append(bg.sgrParams(foreground: false)) }
        parts.append(contentsOf: cell.attributes.sgrCodes.map(String.init))
        return parts.joined(separator: ";")
    }

    // MARK: - Terminal size

    /// Update the known terminal dimensions (called on WindowSizeMsg).
    func setSize(width: Int, height: Int) {
        termWidth = width
        termHeight = height
        repaint()
    }

    // MARK: - Alternate screen

    func enterAltScreen() {
        guard !altScreenActive else { return }
        altScreenActive = true
        terminal.write(ANSI.enterAltScreen)
        terminal.write(ANSI.eraseEntireScreen)
        terminal.write(ANSI.cursorHome)
        cursorHidden = true
        terminal.write(ANSI.hideCursor)
        repaint()
    }

    func exitAltScreen() {
        guard altScreenActive else { return }
        altScreenActive = false
        terminal.write(ANSI.exitAltScreen)
        repaint()
    }

    // MARK: - Cursor

    func hideCursor() {
        cursorHidden = true
        terminal.write(ANSI.hideCursor)
    }

    func showCursor() {
        cursorHidden = false
        terminal.write(ANSI.showCursor)
    }

    // MARK: - Screen clear

    func clearScreen() {
        terminal.write(ANSI.eraseEntireScreen)
        terminal.write(ANSI.cursorHome)
        repaint()
    }

    // MARK: - Window title

    func setWindowTitle(_ title: String) {
        terminal.write(ANSI.setWindowTitle(title))
        lastWindowTitle = title
    }

    // MARK: - Print above view

    /// Queue a line to be printed above the live view on the next flush.
    func println(_ text: String) {
        guard !altScreenActive else { return }
        queuedLines.append(contentsOf: text.components(separatedBy: "\n"))
        repaint()
    }
}
