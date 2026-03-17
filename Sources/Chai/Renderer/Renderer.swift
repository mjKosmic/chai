import Foundation

/// A framerate-based, diff-driven terminal renderer.
///
/// The renderer maintains a pending view buffer and flushes it to the terminal
/// at a configurable frame rate (default 60 FPS). On each flush it compares
/// the new frame against the previous one and only rewrites lines that have
/// changed, minimising terminal I/O.
///
/// ## How it works
///
/// 1. ``write(_:)`` stores the latest view string in an internal buffer.
/// 2. A background `Task` ticks at `1/fps` seconds and calls ``flush()``.
/// 3. ``flush()`` splits the view into lines, diffs against the last frame,
///    moves the cursor, and writes only the changed lines.
///
/// The renderer is an actor to serialise all state mutations.
actor Renderer {

    // MARK: - Configuration

    static let defaultFPS = 60
    static let maxFPS = 120

    // MARK: - State

    private let terminal: any TerminalOutput
    private let fps: Int

    /// The view output queued for the next flush.
    private var pendingViewOutput = ViewOutput("")
    /// The content string that was last written to the terminal.
    private var lastContent: String = ""
    /// The individual lines of the last rendered frame.
    private var lastLines: [String] = []
    /// Number of lines written in the last non-altscreen render.
    private var linesRendered: Int = 0
    /// Number of lines written in the last altscreen render.
    private var altLinesRendered: Int = 0

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
        var output = view
        if output.content.isEmpty { output.content = " " }
        pendingViewOutput = output
    }

    /// Force a full repaint on the next flush by clearing the last-render cache.
    func repaint() {
        lastContent = ""
        lastLines = []
    }

    // MARK: - Flush

    /// Write the pending view to the terminal, diffing against the last frame.
    ///
    /// Terminal state transitions (alt screen, window title, cursor visibility)
    /// are handled first, then content is diffed and written, and finally the
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
                altLinesRendered = 0
                lastContent = ""
                lastLines = []
                queuedLines = []
                cursorParkedRow = 0
            } else if !wantAltScreen && altScreenActive {
                altScreenActive = false
                terminal.write(ANSI.exitAltScreen)
                lastContent = ""
                lastLines = []
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

        // ── Determine what needs updating ───────────────────────────────────

        let content = viewOutput.content
        let contentChanged = !content.isEmpty && content != lastContent
        let cursorChanged = viewOutput.cursor != lastCursor

        guard contentChanged || cursorChanged else { return }

        var out = ""

        // ── Content diff and render ─────────────────────────────────────────

        var newLineCount: Int

        if contentChanged {
            var newLines = content.components(separatedBy: "\n")

            // Clamp to terminal height if known.
            if termHeight > 0 && newLines.count > termHeight {
                newLines = Array(newLines.suffix(termHeight))
            }

            newLineCount = newLines.count

            // Move cursor back to the start of the previously rendered content.
            // Uses `cursorParkedRow` rather than `linesRendered - 1` because
            // the cursor may have been positioned mid-content by a prior frame.
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
                    // Truncate to terminal width so long logged lines don't
                    // wrap and corrupt the layout of the live view below them.
                    var renderedLine = line
                    if termWidth > 0 {
                        renderedLine = truncateToVisibleWidth(renderedLine, maxWidth: termWidth)
                    }
                    // Always emit a SGR reset after each logged line. Truncation
                    // can drop a trailing ESC[0m that was part of the original
                    // string, leaving attributes (colour, bold, etc.) active for
                    // the erase-to-EOL and all subsequent output. Resetting first
                    // also ensures eraseLineRight uses the terminal default colour.
                    out += renderedLine + ANSI.reset + ANSI.eraseLineRight + "\r\n"
                }
                queuedLines = []
            }

            // Paint each line, skipping unchanged ones.
            for (i, line) in newLines.enumerated() {
                let canSkip = !flushQueued
                    && i < lastLines.count
                    && lastLines[i] == line

                if canSkip {
                    if i < newLines.count - 1 { out += "\n" }
                    continue
                }

                // On the very first render, reset to column 0.
                if i == 0 && lastContent.isEmpty { out += "\r" }

                // Truncate lines wider than the terminal to prevent wrapping.
                // Uses ANSI-aware width measurement so that escape sequences are
                // not counted and CJK wide characters count as 2 columns.
                var rendered = line
                if termWidth > 0 {
                    rendered = truncateToVisibleWidth(rendered, maxWidth: termWidth)
                }

                out += rendered + ANSI.eraseLineRight

                if i < newLines.count - 1 { out += "\r\n" }
            }

            // Erase leftover lines from the previous frame.
            let prevCount = altScreenActive ? altLinesRendered : linesRendered
            if prevCount > newLines.count {
                out += ANSI.eraseScreenBelow
            }

            // Update line counts.
            if altScreenActive {
                altLinesRendered = newLines.count
            } else {
                linesRendered = newLines.count
            }

            lastContent = content
            lastLines = newLines
        } else {
            newLineCount = altScreenActive ? altLinesRendered : linesRendered
        }

        // ── Cursor shape ────────────────────────────────────────────────────

        if let cursor = viewOutput.cursor {
            if cursor.shape != lastCursor?.shape || cursor.blink != lastCursor?.blink {
                out += ANSI.setCursorShape(cursor.shape, blink: cursor.blink)
            }
        }

        // ── Cursor positioning ──────────────────────────────────────────────

        // After content painting the terminal cursor sits at the last printed
        // line. For cursor-only updates it sits at `cursorParkedRow`. Compute
        // a common `currentRow` so the positioning logic below works for both.

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
        altLinesRendered = 0
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
