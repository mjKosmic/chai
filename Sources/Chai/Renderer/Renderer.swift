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

    /// The view string queued for the next flush.
    private var pendingView: String = ""
    /// The view string that was last written to the terminal.
    private var lastView: String = ""
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
                await self?.flush()
            }
        }
    }

    /// Stop the render loop and perform a final flush.
    func stop() {
        flushTask?.cancel()
        flushTask = nil
        flush()
        // Move cursor to start of last line and erase it.
        terminal.write(ANSI.eraseEntireLine + "\r")
    }

    /// Stop immediately without a final flush.
    func kill() {
        flushTask?.cancel()
        flushTask = nil
        terminal.write(ANSI.eraseEntireLine + "\r")
    }

    // MARK: - View buffer

    /// Queue a new view string for rendering on the next tick.
    func write(_ view: String) {
        pendingView = view.isEmpty ? " " : view
    }

    /// Force a full repaint on the next flush by clearing the last-render cache.
    func repaint() {
        lastView = ""
        lastLines = []
    }

    // MARK: - Flush

    /// Write the pending view to the terminal, diffing against the last frame.
    func flush() {
        let view = pendingView
        guard !view.isEmpty, view != lastView else { return }

        var newLines = view.components(separatedBy: "\n")

        // Clamp to terminal height if known.
        if termHeight > 0 && newLines.count > termHeight {
            newLines = Array(newLines.suffix(termHeight))
        }

        var out = ""

        // ── Move cursor back to the start of the previously rendered content.
        if altScreenActive {
            out += ANSI.cursorHome
        } else if linesRendered > 1 {
            out += ANSI.cursorUp(linesRendered - 1)
        }

        // ── Flush any queued print-above lines.
        let flushQueued = !queuedLines.isEmpty && !altScreenActive
        if flushQueued {
            for line in queuedLines {
                out += line + ANSI.eraseLineRight + "\r\n"
            }
            queuedLines = []
        }

        // ── Paint each line, skipping unchanged ones.
        for (i, line) in newLines.enumerated() {
            let canSkip = !flushQueued
                && i < lastLines.count
                && lastLines[i] == line

            if canSkip {
                if i < newLines.count - 1 { out += "\n" }
                continue
            }

            // On the very first render, reset to column 0.
            if i == 0 && lastView.isEmpty { out += "\r" }

            // Truncate lines wider than the terminal to prevent wrapping.
            var rendered = line
            if termWidth > 0 {
                rendered = String(rendered.prefix(termWidth))
            }

            out += rendered + ANSI.eraseLineRight

            if i < newLines.count - 1 { out += "\r\n" }
        }

        // ── Erase leftover lines from the previous frame.
        let prevCount = altScreenActive ? altLinesRendered : linesRendered
        if prevCount > newLines.count {
            out += ANSI.eraseScreenBelow
        }

        // ── Park the cursor at the start of the last line.
        if altScreenActive {
            out += ANSI.cursorPosition(row: newLines.count, col: 1)
            altLinesRendered = newLines.count
        } else {
            out += "\r"
            linesRendered = newLines.count
        }

        terminal.write(out)
        lastView = view
        lastLines = newLines
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
        if cursorHidden { terminal.write(ANSI.hideCursor) }
        altLinesRendered = 0
        repaint()
    }

    func exitAltScreen() {
        guard altScreenActive else { return }
        altScreenActive = false
        terminal.write(ANSI.exitAltScreen)
        if cursorHidden { terminal.write(ANSI.hideCursor) }
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
    }

    // MARK: - Print above view

    /// Queue a line to be printed above the live view on the next flush.
    func println(_ text: String) {
        guard !altScreenActive else { return }
        queuedLines.append(contentsOf: text.components(separatedBy: "\n"))
        repaint()
    }
}
