#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

import Foundation

/// Describes the color capability of the connected terminal.
///
/// Use ``detect(environment:isTerminal:)`` to determine the profile at
/// runtime, then pass it to ``Style/render(_:profile:)`` for automatic
/// color downsampling.
///
/// ```swift
/// let profile = ColorProfile.detect()
/// let output = Style().foreground(.trueColor(r: 255, g: 100, b: 50))
///     .render("Warning!", profile: profile)
/// ```
///
/// Profiles are ordered by capability — `noColor < ansi < ansi256 < trueColor`
/// — so you can use standard comparison operators.
public enum ColorProfile: Int, Comparable, Sendable {
    /// No color output. Used when `NO_COLOR` is set or stdout is not a TTY.
    case noColor = 0

    /// 16-color ANSI (standard 8 + bright 8).
    case ansi = 1

    /// 256-color extended palette.
    case ansi256 = 2

    /// 24-bit true color (16.7 million colors).
    case trueColor = 3

    public static func < (lhs: ColorProfile, rhs: ColorProfile) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Detects the color profile from environment variables and TTY state.
    ///
    /// Detection order (first match wins):
    /// 1. `NO_COLOR` set → ``noColor``
    /// 2. stdout is not a TTY → ``noColor``
    /// 3. `COLORTERM` is `truecolor` or `24bit` → ``trueColor``
    /// 4. `TERM_PROGRAM` is `iTerm.app` or `Hyper` → ``trueColor``
    /// 5. `TERM` contains `256color` → ``ansi256``
    /// 6. `TERM` is `xterm` or `linux` → ``ansi``
    /// 7. Default → ``ansi``
    ///
    /// - Parameters:
    ///   - environment: The environment dictionary to read. Defaults to the
    ///     current process environment. Pass a custom dictionary in tests.
    ///   - isTerminal: Whether stdout is a TTY. Defaults to the result of
    ///     `isatty(STDOUT_FILENO)`. Pass `false` in tests to simulate piped output.
    /// - Returns: The detected color profile.
    public static func detect(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        isTerminal: Bool = isatty(STDOUT_FILENO) != 0
    ) -> ColorProfile {
        if environment["NO_COLOR"] != nil { return .noColor }
        if !isTerminal { return .noColor }

        if let colorterm = environment["COLORTERM"] {
            if colorterm == "truecolor" || colorterm == "24bit" { return .trueColor }
        }

        if let termProgram = environment["TERM_PROGRAM"] {
            if termProgram == "iTerm.app" || termProgram == "Hyper" { return .trueColor }
        }

        if let term = environment["TERM"] {
            if term.contains("256color") { return .ansi256 }
            if term == "xterm" || term == "linux" { return .ansi }
        }

        return .ansi
    }
}
