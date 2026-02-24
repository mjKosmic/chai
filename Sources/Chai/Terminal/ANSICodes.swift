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
    /// Move cursor up one line.
    static let cursorUp1 = "\u{1B}[A"

    /// Move cursor up `n` lines.
    static func cursorUp(_ n: Int) -> String { "\u{1B}[\(n)A" }
    /// Move cursor down `n` lines.
    static func cursorDown(_ n: Int) -> String { "\u{1B}[\(n)B" }
    /// Move cursor to column `col` (1-based) on row `row` (1-based).
    static func cursorPosition(row: Int, col: Int) -> String { "\u{1B}[\(row);\(col)H" }

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

    // MARK: - Scrolling regions

    /// Set top and bottom scroll margins (1-based).
    static func setScrollMargins(top: Int, bottom: Int) -> String {
        "\u{1B}[\(top);\(bottom)r"
    }
    /// Reset scroll margins to full screen.
    static let resetScrollMargins = "\u{1B}[r"

    // MARK: - Line insertion / deletion

    /// Insert `n` blank lines at the cursor position.
    static func insertLines(_ n: Int) -> String { "\u{1B}[\(n)L" }

    // MARK: - Mouse

    /// Enable button-event mouse tracking (click + drag).
    static let enableMouseCellMotion = "\u{1B}[?1002h"
    /// Disable button-event mouse tracking.
    static let disableMouseCellMotion = "\u{1B}[?1002l"
    /// Enable all-motion mouse tracking (includes hover).
    static let enableMouseAllMotion = "\u{1B}[?1003h"
    /// Disable all-motion mouse tracking.
    static let disableMouseAllMotion = "\u{1B}[?1003l"
    /// Enable SGR extended mouse mode (supports large coordinates).
    static let enableMouseSGR = "\u{1B}[?1006h"
    /// Disable SGR extended mouse mode.
    static let disableMouseSGR = "\u{1B}[?1006l"

    // MARK: - Bracketed paste

    /// Enable bracketed paste mode.
    static let enableBracketedPaste = "\u{1B}[?2004h"
    /// Disable bracketed paste mode.
    static let disableBracketedPaste = "\u{1B}[?2004l"

    // MARK: - Focus reporting

    /// Enable focus-in / focus-out reporting.
    static let enableFocusReporting = "\u{1B}[?1004h"
    /// Disable focus reporting.
    static let disableFocusReporting = "\u{1B}[?1004l"

    // MARK: - Window title

    /// Set the terminal window title via OSC 0.
    static func setWindowTitle(_ title: String) -> String {
        "\u{1B}]0;\(title)\u{07}"
    }

    // MARK: - Attributes / reset

    /// Reset all text attributes.
    static let reset = "\u{1B}[0m"
}
