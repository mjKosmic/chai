#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Foundation

// MARK: - TerminalOutput protocol

/// Abstraction over a writable terminal output channel.
///
/// Conforming types write ANSI-encoded strings to a terminal (or a test
/// buffer). The `Renderer` depends on this protocol rather than `Terminal`
/// directly, which makes the renderer fully testable without a real TTY.
protocol TerminalOutput: AnyObject, Sendable {
    func write(_ string: String)
}

// MARK: - Terminal

/// Low-level terminal management: raw mode, terminal size, and output writing.
///
/// This type is not part of the public API — it is used internally by
/// ``Program``.
final class Terminal: TerminalOutput, @unchecked Sendable {

    // MARK: - Properties

    let inputFD: Int32
    let outputFD: Int32

    /// The original terminal attributes, saved before entering raw mode.
    private var savedTermios: termios?

    // MARK: - Init

    init(inputFD: Int32 = STDIN_FILENO, outputFD: Int32 = STDOUT_FILENO) {
        self.inputFD = inputFD
        self.outputFD = outputFD
    }

    // MARK: - Raw Mode

    /// Put the terminal into raw (non-canonical, no-echo) mode.
    ///
    /// In raw mode:
    /// - Input is available byte-by-byte (no line buffering).
    /// - Echo is disabled.
    /// - Signal generation for Ctrl+C etc. is disabled (we handle them ourselves).
    func enableRawMode() throws {
        var t = termios()
        guard tcgetattr(inputFD, &t) == 0 else {
            throw TerminalError.tcgetattrFailed(errno: errno)
        }
        savedTermios = t

        // Disable canonical mode, echo, signal generation, and extended input.
        t.c_lflag &= ~tcflag_t(ICANON | ECHO | ISIG | IEXTEN)
        // Disable software flow control and CR/NL translation.
        t.c_iflag &= ~tcflag_t(IXON | IXOFF | ICRNL | INLCR)
        // Disable output processing.
        t.c_oflag &= ~tcflag_t(OPOST)
        // Read at least 1 byte, no timeout.
        withUnsafeMutableBytes(of: &t.c_cc) { ptr in
            ptr[Int(VMIN)]  = 1
            ptr[Int(VTIME)] = 0
        }

        guard tcsetattr(inputFD, TCSAFLUSH, &t) == 0 else {
            throw TerminalError.tcsetattrFailed(errno: errno)
        }
    }

    /// Restore the terminal to its state before ``enableRawMode()`` was called.
    func disableRawMode() {
        guard var saved = savedTermios else { return }
        tcsetattr(inputFD, TCSAFLUSH, &saved)
        savedTermios = nil
    }

    // MARK: - Terminal Size

    /// Query the current terminal dimensions.
    ///
    /// - Returns: `(width, height)` in columns and rows, or `(80, 24)` as a
    ///   safe fallback if the query fails.
    func size() -> (width: Int, height: Int) {
        var ws = winsize()
        if ioctl(outputFD, UInt(TIOCGWINSZ), &ws) == 0,
           ws.ws_col > 0, ws.ws_row > 0 {
            return (Int(ws.ws_col), Int(ws.ws_row))
        }
        return (80, 24)
    }

    // MARK: - Output

    /// Write a string directly to the output file descriptor (bypasses stdio buffering).
    func write(_ string: String) {
        var s = string
        s.withUTF8 { ptr in
            guard let base = ptr.baseAddress, ptr.count > 0 else { return }
            var written = 0
            while written < ptr.count {
                let result = Foundation.write(outputFD, base + written, ptr.count - written)
                if result <= 0 { break }
                written += result
            }
        }
    }

    // MARK: - Cleanup

    deinit {
        disableRawMode()
    }
}

// MARK: - Errors

enum TerminalError: Error, CustomStringConvertible {
    case tcgetattrFailed(errno: Int32)
    case tcsetattrFailed(errno: Int32)

    var description: String {
        switch self {
        case .tcgetattrFailed(let e):
            return "tcgetattr failed: \(String(cString: strerror(e)))"
        case .tcsetattrFailed(let e):
            return "tcsetattr failed: \(String(cString: strerror(e)))"
        }
    }
}
