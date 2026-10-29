/// ANSI / VT100 escape sequence constants used by the renderer and terminal
/// management layer.
///
/// All sequences follow the form `ESC[...` (CSI) or `ESC...` (SS3/OSC).
enum ANSI {

    // MARK: - Escape prefix

    static let esc = "\u{1B}"
    static let csi = "\u{1B}["   // Control Sequence Introducer
    static let osc = "\u{1B}]"   // Operating System Command

    // MARK: - Cursor visibility

    /// Hide the cursor.
    static let hideCursor = "\u{1B}[?25l"
    /// Show the cursor.
    static let showCursor = "\u{1B}[?25h"

    // MARK: - Cursor movement

    /// Move cursor to home position (row 1, col 1).
    static let cursorHome = "\u{1B}[H"

    /// Move cursor up `n` lines.
    static func cursorUp(_ n: Int) -> String { "\u{1B}[\(n)A" }
    /// Move cursor down `n` lines.
    static func cursorDown(_ n: Int) -> String { "\u{1B}[\(n)B" }
    /// Move cursor to column `col` (1-based) on row `row` (1-based).
    static func cursorPosition(row: Int, col: Int) -> String { "\u{1B}[\(row);\(col)H" }
    /// Move cursor to column `col` (1-based) on the current line (CHA).
    static func cursorColumn(_ col: Int) -> String { "\u{1B}[\(col)G" }

    // MARK: - Erase

    /// Erase from cursor to end of line.
    static let eraseLineRight = "\u{1B}[K"
    /// Erase entire current line.
    static let eraseEntireLine = "\u{1B}[2K"
    /// Erase from cursor to end of screen.
    static let eraseScreenBelow = "\u{1B}[J"
    /// Erase entire screen.
    static let eraseEntireScreen = "\u{1B}[2J"

    // MARK: - Alternate screen buffer

    /// Enter the alternate screen buffer and save cursor position.
    static let enterAltScreen = "\u{1B}[?1049h"
    /// Exit the alternate screen buffer and restore cursor position.
    static let exitAltScreen = "\u{1B}[?1049l"

    // MARK: - Window title

    /// Set the terminal window title via OSC 0.
    ///
    /// ASCII control characters (U+0000–U+001F and U+007F) are stripped from
    /// `title` before the sequence is emitted. Embedded `ESC` or `BEL` would
    /// prematurely terminate the OSC sequence and could inject arbitrary escape
    /// sequences into the terminal stream — the same sanitization applied by
    /// ``osc8(url:)``.
    static func setWindowTitle(_ title: String) -> String {
        let safe = String(title.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F })
        return "\u{1B}]0;\(safe)\u{07}"
    }

    // MARK: - Synchronized output (mode 2026)

    /// Begin synchronized output — the terminal defers display until the
    /// matching ``endSyncUpdate`` is received, preventing partial-frame tearing.
    /// Terminals that do not support mode 2026 silently ignore this sequence.
    static let beginSyncUpdate = "\u{1B}[?2026h"

    /// End synchronized output — the terminal renders the buffered frame.
    static let endSyncUpdate = "\u{1B}[?2026l"

    // MARK: - Cursor shape (DECSCUSR)

    /// Set the cursor shape using DECSCUSR (`ESC[ Ps SP q`).
    ///
    /// Terminals that do not support DECSCUSR silently ignore this sequence.
    static func setCursorShape(_ shape: Cursor.Shape, blink: Bool) -> String {
        let code: Int
        switch (shape, blink) {
        case (.block, true):      code = 1
        case (.block, false):     code = 2
        case (.underline, true):  code = 3
        case (.underline, false): code = 4
        case (.bar, true):        code = 5
        case (.bar, false):       code = 6
        }
        return "\u{1B}[\(code) q"
    }

    /// Reset the cursor shape to the terminal's default.
    static let resetCursorShape = "\u{1B}[0 q"

    // MARK: - OSC 8 Hyperlinks

    /// Opens an OSC 8 hyperlink sequence pointing to the given URL.
    ///
    /// The caller is responsible for emitting the visible link text and then
    /// closing the link with ``osc8Reset``.
    ///
    /// Terminals that do not support OSC 8 silently ignore the sequences and
    /// display the visible text as-is.
    ///
    /// ASCII control characters (U+0000–U+001F and U+007F) are stripped from
    /// `url` before the sequence is emitted. Embedded `ESC`, `BEL`, or `ST`
    /// would prematurely terminate the OSC sequence and could inject arbitrary
    /// escape sequences into the terminal stream.
    ///
    /// ```
    /// ANSI.osc8(url: "https://example.com") + "click me" + ANSI.osc8Reset
    /// ```
    static func osc8(url: String) -> String {
        let safe = String(url.unicodeScalars.filter { $0.value >= 0x20 && $0.value != 0x7F })
        return "\u{1B}]8;;\(safe)\u{1B}\\"
    }

    /// Closes an OSC 8 hyperlink sequence.
    ///
    /// Must follow the visible link text that was opened with ``osc8(url:)``.
    static let osc8Reset = "\u{1B}]8;;\u{1B}\\"

    // MARK: - Attributes / reset

    /// Reset all text attributes.
    static let reset = "\u{1B}[0m"
}
