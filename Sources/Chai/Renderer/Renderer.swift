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
/// 1. ``write(_:)`` stores the latest ``ViewOutput`` in an internal buffer.
/// 2. A background `Task` ticks at `1/fps` seconds and calls ``flush()``.
/// 3. ``flush()`` builds a ``CellBuffer`` via ``layout(_:width:height:)``,
///    diffs against ``lastBuffer``, and writes only the changed rows.
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

    /// The view output queued for the next flush.
    private var pendingViewOutput = ViewOutput("")

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
    /// The renderer will diff the terminal state (alt screen, window title,
    /// cursor visibility) and content against the previous frame on the next
    /// ``flush()``.
    func write(_ view: ViewOutput) {
        pendingViewOutput = view
    }

    /// Force a full repaint on the next flush by clearing the last-render cache.
    func repaint() {
        lastBuffer = CellBuffer(width: 0, height: 0)
    }

    // MARK: - Flush

    /// Write the pending view to the terminal, diffing against the last frame.
    ///
    /// Terminal state transitions (alt screen, window title, cursor visibility)
    /// are handled first, then content is laid out into a cell buffer, diffed
    /// against the previous frame, and changed rows are written. Finally the
    /// cursor is positioned.
    func flush() {
        let viewOutput = pendingViewOutput

        // ── Handle terminal state transitions ───────────────────────────────

        // Alt screen: enter or exit if the model changed its declaration.
        if let wantAltScreen = viewOutput.altScreen {
            if wantAltScreen && !altScreenActive {
                altScreenActive = true
                terminal.write(ANSI.enterAltScreen)
                terminal.write(ANSI.eraseEntireScreen)
                terminal.write(ANSI.cursorHome)
                // Cursor is hidden by default in alt screen mode.
                cursorHidden = true
                terminal.write(ANSI.hideCursor)
                lastBuffer = CellBuffer(width: 0, height: 0)
                queuedLines = []
                cursorParkedRow = 0
            } else if !wantAltScreen && altScreenActive {
                altScreenActive = false
                terminal.write(ANSI.exitAltScreen)
                lastBuffer = CellBuffer(width: 0, height: 0)
                queuedLines = []
                cursorParkedRow = 0
            }
        }

        // Window title: update if changed.
        if let title = viewOutput.windowTitle, title != lastWindowTitle {
            terminal.write(ANSI.setWindowTitle(title))
            lastWindowTitle = title
        }

        // Cursor visibility: when a cursor is specified the cursor must be
        // visible. In alt-screen mode with no cursor, the cursor is hidden
        // automatically. In normal mode with no cursor the state is unchanged.
        if viewOutput.cursor != nil {
            if cursorHidden {
                cursorHidden = false
                terminal.write(ANSI.showCursor)
            }
        } else if altScreenActive && !cursorHidden {
            cursorHidden = true
            terminal.write(ANSI.hideCursor)
        }

        // ── Build cell buffer ─────────────────────────────────────────────

        let content = viewOutput.content
        let w = termWidth > 0 ? termWidth : Self.fallbackWidth

        var contentToLayout = content
        var bufferHeight: Int

        if content.isEmpty {
            // Empty content: use a single-row buffer with a space to maintain
            // cursor position tracking. The space cell equals .empty so it
            // won't produce visible output.
            contentToLayout = " "
            bufferHeight = 1
        } else if altScreenActive {
            bufferHeight = termHeight > 0 ? termHeight : 24
        } else {
            bufferHeight = content.lineCount()
            // Clamp to terminal height if known, taking suffix lines.
            if termHeight > 0 && bufferHeight > termHeight {
                contentToLayout = content.suffix(lines: termHeight)
                bufferHeight = termHeight
            }
        }

        // In inline mode the buffer height is derived from lineCount() (explicit
        // newlines only). Wrapping must be disabled so that lines wider than the
        // terminal width are truncated rather than spilling into rows that are
        // allocated for subsequent logical lines, which would cause those lines
        // to be dropped when the buffer fills.
        let wrapping = altScreenActive
        let newBuffer = layout(contentToLayout, width: w, height: bufferHeight, wrapping: wrapping)

        // ── Determine what needs updating ─────────────────────────────────

        let diff = newBuffer.diff(against: lastBuffer)
        let contentChanged = !diff.changes.isEmpty || diff.eraseBelow
        let cursorChanged = viewOutput.cursor != lastCursor

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

            // Paint each row, skipping unchanged ones.
            for row in 0..<newBuffer.height {
                let canSkip = !flushQueued && !changedRows.contains(row)

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

        if let cursor = viewOutput.cursor {
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

        if let cursor = viewOutput.cursor {
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

        lastCursor = viewOutput.cursor

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
