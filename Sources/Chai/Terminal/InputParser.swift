/// Parses raw byte sequences from stdin into ``Message`` values.
///
/// The parser handles:
/// - Single-byte control characters (Ctrl+A … Ctrl+Z, ESC, etc.)
/// - Multi-byte UTF-8 printable characters
/// - ANSI CSI escape sequences (arrow keys, function keys, etc.)
/// - SS3 sequences (alternate arrow key encoding used by some terminals)
///
/// This is a pure value type with no I/O — it operates on `[UInt8]` buffers.
struct InputParser {

    // MARK: - Public API

    /// Parse as many messages as possible from `buffer`.
    ///
    /// - Parameters:
    ///   - buffer: Raw bytes from stdin.
    ///   - canHaveMoreData: Pass `true` when the read filled the entire buffer,
    ///     indicating more bytes may be waiting. The parser will hold back
    ///     incomplete sequences rather than reporting them as unknown.
    /// - Returns: An array of parsed messages and the number of bytes consumed.
    ///   Unconsumed bytes should be prepended to the next read.
    static func parse(buffer: [UInt8], canHaveMoreData: Bool) -> (messages: [any Message], consumed: Int) {
        var messages: [any Message] = []
        var index = 0

        while index < buffer.count {
            let remaining = Array(buffer[index...])
            let (width, msg) = parseOne(bytes: remaining, canHaveMoreData: canHaveMoreData && index + remaining.count == buffer.count)
            if width == 0 {
                // Need more data — stop here and let the caller retry.
                break
            }
            if let msg = msg {
                messages.append(msg)
            }
            index += width
        }

        return (messages, index)
    }

    // MARK: - Single-message parser

    /// Attempt to parse exactly one message from the front of `bytes`.
    ///
    /// - Returns: `(bytesConsumed, message)`. If `bytesConsumed == 0` the
    ///   parser needs more data.
    static func parseOne(bytes: [UInt8], canHaveMoreData: Bool) -> (Int, (any Message)?) {
        guard !bytes.isEmpty else { return (0, nil) }

        // ── CSI sequences: ESC [ ...
        if bytes.count >= 2 && bytes[0] == 0x1B && bytes[1] == 0x5B /* '[' */ {
            return parseCSI(bytes: bytes, canHaveMoreData: canHaveMoreData)
        }

        // ── SS3 sequences: ESC O ...
        if bytes.count >= 2 && bytes[0] == 0x1B && bytes[1] == 0x4F /* 'O' */ {
            return parseSS3(bytes: bytes, canHaveMoreData: canHaveMoreData)
        }

        // ── Lone ESC or Alt+<key>
        if bytes[0] == 0x1B {
            if bytes.count == 1 {
                if canHaveMoreData { return (0, nil) }
                return (1, KeyMsg(type: .escape))
            }
            // Try to parse the next byte/sequence as an Alt-modified key.
            let (w, inner) = parseOne(bytes: Array(bytes[1...]), canHaveMoreData: false)
            if w > 0, let key = inner as? KeyMsg {
                return (1 + w, KeyMsg(type: key.type, runes: key.runes, alt: true))
            }
            // Unrecognised Alt sequence — report bare ESC.
            return (1, KeyMsg(type: .escape))
        }

        // ── NUL byte
        if bytes[0] == 0x00 {
            return (1, KeyMsg(type: .ctrl("@")))
        }

        // ── Named control characters (must come before the generic ctrl range)
        switch bytes[0] {
        case 0x08: return (1, KeyMsg(type: .backspace))   // BS  (Ctrl+H)
        case 0x09: return (1, KeyMsg(type: .tab))          // HT  (Ctrl+I)
        case 0x0D: return (1, KeyMsg(type: .enter))        // CR  (Ctrl+M)
        case 0x1B: return (1, KeyMsg(type: .escape))       // ESC (already handled above, but kept for safety)
        case 0x1C: return (1, KeyMsg(type: .ctrl("\\")))
        case 0x1D: return (1, KeyMsg(type: .ctrl("]")))
        case 0x1E: return (1, KeyMsg(type: .ctrl("^")))
        case 0x1F: return (1, KeyMsg(type: .ctrl("_")))
        case 0x7F: return (1, KeyMsg(type: .backspace))    // DEL
        default: break
        }

        // ── Generic control characters (0x01 … 0x1A → Ctrl+A … Ctrl+Z)
        // Excludes 0x08, 0x09, 0x0D which are handled above.
        if bytes[0] >= 0x01 && bytes[0] <= 0x1A {
            let c = Character(UnicodeScalar(bytes[0] + 0x60)) // offset to lowercase letter
            return (1, KeyMsg(type: .ctrl(c)))
        }

        // ── Space
        if bytes[0] == 0x20 {
            return (1, KeyMsg(type: .space, runes: [" "]))
        }

        // ── Printable UTF-8 runes
        return parsePrintable(bytes: bytes, canHaveMoreData: canHaveMoreData)
    }

    // MARK: - CSI parser

    private static func parseCSI(bytes: [UInt8], canHaveMoreData: Bool) -> (Int, (any Message)?) {
        // We need at least ESC [ <final-byte>
        guard bytes.count >= 3 else {
            return canHaveMoreData ? (0, nil) : (bytes.count, nil)
        }

        // Collect parameter bytes (0x30–0x3F) and intermediate bytes (0x20–0x2F).
        var i = 2
        while i < bytes.count && bytes[i] >= 0x20 && bytes[i] <= 0x3F {
            i += 1
        }

        // Final byte must be in 0x40–0x7E.
        guard i < bytes.count else {
            return canHaveMoreData ? (0, nil) : (bytes.count, nil)
        }
        let finalByte = bytes[i]
        guard finalByte >= 0x40 && finalByte <= 0x7E else {
            return (i + 1, nil) // skip unrecognised sequence
        }

        let totalLen = i + 1
        let seq = bytes[0..<totalLen].map { $0 }
        let seqStr = String(bytes: seq, encoding: .isoLatin1) ?? ""

        // Check Alt-modifier sequences first: xterm encodes Alt as modifier
        // parameter 3 (e.g. ESC[1;3A = Alt+Up). These live in a dedicated table
        // so the returned KeyMsg correctly carries alt: true.
        if let key = csiAltTable[seqStr] {
            return (totalLen, KeyMsg(type: key, alt: true))
        }

        if let key = csiTable[seqStr] {
            return (totalLen, KeyMsg(type: key))
        }

        // Unrecognised CSI — skip it.
        return (totalLen, nil)
    }

    // MARK: - SS3 parser

    private static func parseSS3(bytes: [UInt8], canHaveMoreData: Bool) -> (Int, (any Message)?) {
        guard bytes.count >= 3 else {
            return canHaveMoreData ? (0, nil) : (bytes.count, nil)
        }
        let seqStr = String(bytes: [bytes[0], bytes[1], bytes[2]], encoding: .isoLatin1) ?? ""
        if let key = ss3Table[seqStr] {
            return (3, KeyMsg(type: key))
        }
        return (3, nil)
    }

    // MARK: - Printable UTF-8

    private static func parsePrintable(bytes: [UInt8], canHaveMoreData: Bool) -> (Int, (any Message)?) {
        var runes: [Character] = []
        var i = 0

        while i < bytes.count {
            let b = bytes[i]
            // Stop at control characters.
            if b < 0x20 || b == 0x7F { break }

            // Determine UTF-8 sequence length.
            let seqLen: Int
            if b & 0x80 == 0 {
                seqLen = 1
            } else if b & 0xE0 == 0xC0 {
                seqLen = 2
            } else if b & 0xF0 == 0xE0 {
                seqLen = 3
            } else if b & 0xF8 == 0xF0 {
                seqLen = 4
            } else {
                // Invalid UTF-8 lead byte — skip.
                i += 1
                continue
            }

            guard i + seqLen <= bytes.count else {
                // Incomplete sequence at end of buffer.
                if canHaveMoreData { break }
                i += 1
                continue
            }

            let slice = bytes[i..<(i + seqLen)]
            if let str = String(bytes: slice, encoding: .utf8), let ch = str.first {
                runes.append(ch)
                i += seqLen
            } else {
                i += 1
            }
        }

        guard !runes.isEmpty else { return (1, nil) }
        return (i, KeyMsg(type: .runes, runes: runes))
    }

    // MARK: - Lookup Tables

    /// CSI sequence string → KeyType
    static let csiTable: [String: KeyType] = [
        // Arrow keys
        "\u{1B}[A": .up,
        "\u{1B}[B": .down,
        "\u{1B}[C": .right,
        "\u{1B}[D": .left,

        // Shift + arrows
        "\u{1B}[1;2A": .shiftUp,
        "\u{1B}[1;2B": .shiftDown,
        "\u{1B}[1;2C": .shiftRight,
        "\u{1B}[1;2D": .shiftLeft,
        "\u{1B}[a": .shiftUp,    // urxvt
        "\u{1B}[b": .shiftDown,  // urxvt
        "\u{1B}[c": .shiftRight, // urxvt
        "\u{1B}[d": .shiftLeft,  // urxvt

        // Ctrl + arrows
        "\u{1B}[1;5A": .ctrlUp,
        "\u{1B}[1;5B": .ctrlDown,
        "\u{1B}[1;5C": .ctrlRight,
        "\u{1B}[1;5D": .ctrlLeft,

        // Ctrl+Shift + arrows
        "\u{1B}[1;6A": .ctrlShiftUp,
        "\u{1B}[1;6B": .ctrlShiftDown,
        "\u{1B}[1;6C": .ctrlShiftRight,
        "\u{1B}[1;6D": .ctrlShiftLeft,

        // Shift+Tab (BackTab) — distinct from plain Tab so apps can implement
        // forward/backward focus navigation unambiguously.
        "\u{1B}[Z": .shiftTab,

        // Home / End
        "\u{1B}[H":    .home,
        "\u{1B}[1~":   .home,
        "\u{1B}[7~":   .home,  // urxvt
        "\u{1B}[F":    .end,
        "\u{1B}[4~":   .end,
        "\u{1B}[8~":   .end,   // urxvt

        // Shift + Home / End
        "\u{1B}[1;2H": .shiftHome,
        "\u{1B}[1;2F": .shiftEnd,
        "\u{1B}[7$":   .shiftHome, // urxvt
        "\u{1B}[8$":   .shiftEnd,  // urxvt

        // Ctrl + Home / End
        "\u{1B}[1;5H": .ctrlHome,
        "\u{1B}[1;5F": .ctrlEnd,
        "\u{1B}[7^":   .ctrlHome,  // urxvt
        "\u{1B}[8^":   .ctrlEnd,   // urxvt

        // Ctrl+Shift + Home / End
        "\u{1B}[1;6H": .ctrlShiftHome,
        "\u{1B}[1;6F": .ctrlShiftEnd,

        // Page Up / Down
        "\u{1B}[5~": .pageUp,
        "\u{1B}[6~": .pageDown,

        // Insert / Delete
        "\u{1B}[2~": .insert,
        "\u{1B}[3~": .delete,

        // Function keys — Linux console
        "\u{1B}[[A": .f(1),
        "\u{1B}[[B": .f(2),
        "\u{1B}[[C": .f(3),
        "\u{1B}[[D": .f(4),
        "\u{1B}[[E": .f(5),

        // Function keys — xterm / vt100
        "\u{1B}[11~": .f(1),
        "\u{1B}[12~": .f(2),
        "\u{1B}[13~": .f(3),
        "\u{1B}[14~": .f(4),
        "\u{1B}[15~": .f(5),
        "\u{1B}[17~": .f(6),
        "\u{1B}[18~": .f(7),
        "\u{1B}[19~": .f(8),
        "\u{1B}[20~": .f(9),
        "\u{1B}[21~": .f(10),
        "\u{1B}[23~": .f(11),
        "\u{1B}[24~": .f(12),
        "\u{1B}[25~": .f(13),
        "\u{1B}[26~": .f(14),
        "\u{1B}[28~": .f(15),
        "\u{1B}[29~": .f(16),
        "\u{1B}[31~": .f(17),
        "\u{1B}[32~": .f(18),
        "\u{1B}[33~": .f(19),
        "\u{1B}[34~": .f(20),
    ]

    /// SS3 sequence string → KeyType
    static let ss3Table: [String: KeyType] = [
        "\u{1B}OA": .up,
        "\u{1B}OB": .down,
        "\u{1B}OC": .right,
        "\u{1B}OD": .left,
        "\u{1B}OP": .f(1),
        "\u{1B}OQ": .f(2),
        "\u{1B}OR": .f(3),
        "\u{1B}OS": .f(4),
    ]

    /// CSI sequences that encode the **Alt modifier** via xterm's modifier
    /// parameter 3 (e.g. `ESC[1;3A` = Alt+Up).
    ///
    /// These are checked before ``csiTable`` in `parseCSI` so that the returned
    /// `KeyMsg` correctly carries `alt: true`. Sequences with other modifiers
    /// (Shift=2, Ctrl=5, Ctrl+Shift=6) are handled directly in ``csiTable``
    /// with dedicated `KeyType` cases and do not need the `alt` flag.
    static let csiAltTable: [String: KeyType] = [
        "\u{1B}[1;3A": .up,
        "\u{1B}[1;3B": .down,
        "\u{1B}[1;3C": .right,
        "\u{1B}[1;3D": .left,
    ]
}
