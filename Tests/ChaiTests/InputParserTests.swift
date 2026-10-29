import Testing
@testable import Chai

@Suite("InputParser")
struct InputParserTests {

    // MARK: - Helpers

    private func key(_ bytes: [UInt8]) -> KeyMsg? {
        let (msgs, _) = InputParser.parse(buffer: bytes, canHaveMoreData: false)
        return msgs.first as? KeyMsg
    }

    private func keys(_ bytes: [UInt8]) -> [KeyMsg] {
        let (msgs, _) = InputParser.parse(buffer: bytes, canHaveMoreData: false)
        return msgs.compactMap { $0 as? KeyMsg }
    }

    // MARK: - Control characters

    @Test func ctrlC() {
        let msg = key([0x03])
        #expect(msg?.type == .ctrl("c"))
        #expect(msg?.alt == false)
    }

    @Test func ctrlA() {
        let msg = key([0x01])
        #expect(msg?.type == .ctrl("a"))
    }

    @Test func ctrlZ() {
        let msg = key([0x1A])
        #expect(msg?.type == .ctrl("z"))
    }

    @Test func enter() {
        let msg = key([0x0D])
        #expect(msg?.type == .enter)
    }

    @Test func tab() {
        let msg = key([0x09])
        #expect(msg?.type == .tab)
    }

    @Test func backspace() {
        // DEL (0x7F) is the typical backspace in modern terminals.
        let msg = key([0x7F])
        #expect(msg?.type == .backspace)
    }

    @Test func backspaceByteBS() {
        // BS (0x08) is the older backspace encoding and must not become Ctrl+H.
        let msg = key([0x08])
        #expect(msg?.type == .backspace)
    }

    @Test func nulReportsCtrlAt() {
        let msg = key([0x00])
        #expect(msg?.type == .ctrl("@"))
    }

    @Test func escape() {
        let msg = key([0x1B])
        #expect(msg?.type == .escape)
    }

    @Test func space() {
        let msg = key([0x20])
        #expect(msg?.type == .space)
    }

    // MARK: - Printable ASCII

    @Test func singleASCIIRune() {
        let msg = key([0x61]) // 'a'
        #expect(msg?.type == .runes)
        #expect(msg?.runes == ["a"])
    }

    @Test func multipleASCIIRunes() {
        // "hello" — should come back as a single KeyMsg with 5 runes.
        let bytes: [UInt8] = [0x68, 0x65, 0x6C, 0x6C, 0x6F]
        let msg = key(bytes)
        #expect(msg?.type == .runes)
        #expect(msg?.runes == ["h", "e", "l", "l", "o"])
    }

    // MARK: - UTF-8 multi-byte

    @Test func twoByteUTF8() {
        // U+00E9 LATIN SMALL LETTER E WITH ACUTE: 0xC3 0xA9
        let msg = key([0xC3, 0xA9])
        #expect(msg?.type == .runes)
        #expect(msg?.runes == ["é"])
    }

    @Test func threeBytesUTF8() {
        // U+4E2D CJK UNIFIED IDEOGRAPH: 0xE4 0xB8 0xAD
        let msg = key([0xE4, 0xB8, 0xAD])
        #expect(msg?.type == .runes)
        #expect(msg?.runes == ["中"])
    }

    @Test func fourByteUTF8() {
        // U+1F600 GRINNING FACE: 0xF0 0x9F 0x98 0x80
        let msg = key([0xF0, 0x9F, 0x98, 0x80])
        #expect(msg?.type == .runes)
        #expect(msg?.runes == ["😀"])
    }

    // MARK: - Arrow keys (CSI)

    @Test func arrowUp() {
        let msg = key([0x1B, 0x5B, 0x41]) // ESC [ A
        #expect(msg?.type == .up)
    }

    @Test func arrowDown() {
        let msg = key([0x1B, 0x5B, 0x42])
        #expect(msg?.type == .down)
    }

    @Test func arrowRight() {
        let msg = key([0x1B, 0x5B, 0x43])
        #expect(msg?.type == .right)
    }

    @Test func arrowLeft() {
        let msg = key([0x1B, 0x5B, 0x44])
        #expect(msg?.type == .left)
    }

    // MARK: - Arrow keys (SS3 — alternate encoding)

    @Test func ss3ArrowUp() {
        let msg = key([0x1B, 0x4F, 0x41]) // ESC O A
        #expect(msg?.type == .up)
    }

    @Test func ss3ArrowDown() {
        let msg = key([0x1B, 0x4F, 0x42])
        #expect(msg?.type == .down)
    }

    // MARK: - Modified arrows

    @Test func shiftUp() {
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x32, 0x41]) // ESC [ 1 ; 2 A
        #expect(msg?.type == .shiftUp)
    }

    @Test func ctrlUp() {
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x41]) // ESC [ 1 ; 5 A
        #expect(msg?.type == .ctrlUp)
    }

    @Test func ctrlShiftUp() {
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x36, 0x41]) // ESC [ 1 ; 6 A
        #expect(msg?.type == .ctrlShiftUp)
    }

    // MARK: - Navigation keys

    @Test func home() {
        let msg = key([0x1B, 0x5B, 0x48]) // ESC [ H
        #expect(msg?.type == .home)
    }

    @Test func end() {
        let msg = key([0x1B, 0x5B, 0x46]) // ESC [ F
        #expect(msg?.type == .end)
    }

    @Test func pageUp() {
        let msg = key([0x1B, 0x5B, 0x35, 0x7E]) // ESC [ 5 ~
        #expect(msg?.type == .pageUp)
    }

    @Test func pageDown() {
        let msg = key([0x1B, 0x5B, 0x36, 0x7E]) // ESC [ 6 ~
        #expect(msg?.type == .pageDown)
    }

    @Test func insert() {
        let msg = key([0x1B, 0x5B, 0x32, 0x7E]) // ESC [ 2 ~
        #expect(msg?.type == .insert)
    }

    @Test func delete() {
        let msg = key([0x1B, 0x5B, 0x33, 0x7E]) // ESC [ 3 ~
        #expect(msg?.type == .delete)
    }

    // MARK: - Function keys

    @Test func f1_xterm() {
        let msg = key([0x1B, 0x4F, 0x50]) // ESC O P
        #expect(msg?.type == .f(1))
    }

    @Test func xtermFunctionKeysF1ThroughF4() {
        let sequences: [(UInt8, KeyType)] = [
            (0x31, .f(1)), (0x32, .f(2)), (0x33, .f(3)), (0x34, .f(4)),
        ]
        for (secondDigit, expected) in sequences {
            let msg = key([0x1B, 0x5B, 0x31, secondDigit, 0x7E]) // ESC [ 1 <digit> ~
            #expect(msg?.type == expected)
        }
    }

    @Test func f5() {
        let msg = key([0x1B, 0x5B, 0x31, 0x35, 0x7E]) // ESC [ 1 5 ~
        #expect(msg?.type == .f(5))
    }

    @Test func f12() {
        let msg = key([0x1B, 0x5B, 0x32, 0x34, 0x7E]) // ESC [ 2 4 ~
        #expect(msg?.type == .f(12))
    }

    // MARK: - Shift+Tab

    @Test func shiftTab() {
        // ESC [ Z is the standard BackTab / Shift+Tab sequence.
        let msg = key([0x1B, 0x5B, 0x5A])
        #expect(msg?.type == .shiftTab)
        #expect(msg?.alt == false)
    }

    @Test func shiftTabDistinguishableFromTab() {
        // Regular Tab (0x09) must remain .tab; ESC[Z must be .shiftTab.
        // Applications that implement forward/backward focus traversal depend
        // on this distinction being unambiguous.
        let tab      = key([0x09])
        let shiftTab = key([0x1B, 0x5B, 0x5A])
        #expect(tab?.type == .tab)
        #expect(shiftTab?.type == .shiftTab)
        #expect(tab?.type != shiftTab?.type)
    }

    // MARK: - Alt + arrows (xterm CSI modifier encoding)

    @Test func altArrowUpXtermCSI() {
        // ESC [ 1 ; 3 A — xterm encodes Alt as modifier parameter 3.
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x41])
        #expect(msg?.type == .up)
        #expect(msg?.alt == true)
    }

    @Test func altArrowDownXtermCSI() {
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x42])
        #expect(msg?.type == .down)
        #expect(msg?.alt == true)
    }

    @Test func altArrowRightXtermCSI() {
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x43])
        #expect(msg?.type == .right)
        #expect(msg?.alt == true)
    }

    @Test func altArrowLeftXtermCSI() {
        let msg = key([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x44])
        #expect(msg?.type == .left)
        #expect(msg?.alt == true)
    }

    @Test func altArrowXtermCSIDistinguishedFromPlainArrow() {
        // ESC[A is plain up (alt=false); ESC[1;3A is Alt+Up (alt=true).
        // Both must produce type == .up so existing switch handlers work,
        // but they must differ in the alt flag.
        let plain = key([0x1B, 0x5B, 0x41])
        let alt   = key([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x41])
        #expect(plain?.type == .up)
        #expect(alt?.type   == .up)
        #expect(plain?.alt  == false)
        #expect(alt?.alt    == true)
    }

    @Test func altArrowXtermCSIDistinguishedFromShiftArrow() {
        // ESC[1;2A is Shift+Up (type=.shiftUp, alt=false).
        // ESC[1;3A is Alt+Up  (type=.up,      alt=true).
        let shift = key([0x1B, 0x5B, 0x31, 0x3B, 0x32, 0x41])
        let alt   = key([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x41])
        #expect(shift?.type == .shiftUp)
        #expect(shift?.alt  == false)
        #expect(alt?.type   == .up)
        #expect(alt?.alt    == true)
    }

    // MARK: - Alt modifier (ESC-prefix form — existing behaviour preserved)

    @Test func altA() {
        // ESC followed by 'a' → Alt+a
        let msg = key([0x1B, 0x61])
        #expect(msg?.type == .runes)
        #expect(msg?.runes == ["a"])
        #expect(msg?.alt == true)
    }

    @Test func altEnter() {
        let msg = key([0x1B, 0x0D])
        #expect(msg?.type == .enter)
        #expect(msg?.alt == true)
    }

    @Test func escapeBeforeUnrecognizedBytes() {
        // ESC followed by an unrecognized CSI sequence: Escape is produced and
        // the following bytes are decoded as their own input.
        let msgs = keys([0x1B, 0x1B, 0x5B, 0x39, 0x39, 0x39, 0x7A, 0x61])
        #expect(msgs.count == 2)
        #expect(msgs[0].type == .escape)
        #expect(msgs[1].runes == ["a"])
    }

    // MARK: - Multiple messages in one buffer

    @Test func twoKeysInBuffer() {
        // 'a' then 'b' — consecutive printable ASCII is batched into one KeyMsg
        // with multiple runes (matching Bubble Tea's behaviour).
        let msgs = keys([0x61, 0x62])
        #expect(msgs.count == 1)
        #expect(msgs[0].runes == ["a", "b"])
    }

    @Test func keyThenArrow() {
        // 'q' then ESC [ A (up arrow)
        let msgs = keys([0x71, 0x1B, 0x5B, 0x41])
        #expect(msgs.count == 2)
        #expect(msgs[0].runes == ["q"])
        #expect(msgs[1].type == .up)
    }

    // MARK: - Partial / incomplete sequences

    @Test func incompleteCSIWaitsForMoreData() {
        // ESC [ — incomplete CSI, canHaveMoreData = true
        let (msgs, consumed) = InputParser.parse(buffer: [0x1B, 0x5B], canHaveMoreData: true)
        #expect(msgs.isEmpty)
        #expect(consumed == 0)
    }

    @Test func incompleteCSIConsumedWhenNoMoreData() {
        // ESC [ — incomplete CSI, canHaveMoreData = false → skip
        let (_, consumed) = InputParser.parse(buffer: [0x1B, 0x5B], canHaveMoreData: false)
        #expect(consumed == 2)
    }

    // MARK: - Linux console function keys

    @Test func linuxConsoleFunctionKeys() {
        let selectors: [(UInt8, KeyType)] = [
            (0x41, .f(1)), (0x42, .f(2)), (0x43, .f(3)), (0x44, .f(4)), (0x45, .f(5)),
        ]
        for (selector, expected) in selectors {
            let msg = key([0x1B, 0x5B, 0x5B, selector])
            #expect(msg?.type == expected)
        }
    }

    @Test func linuxConsoleIntroducerWaitsForSelector() {
        let (msgs, consumed) = InputParser.parse(
            buffer: [0x1B, 0x5B, 0x5B],
            canHaveMoreData: true
        )
        #expect(msgs.isEmpty)
        #expect(consumed == 0)
    }

    @Test func linuxConsoleIntroducerWithoutKeyLeavesText() {
        // ESC [ [ x — not a Linux-console key. The introducer is consumed as an
        // unknown sequence and "x" is still delivered as text.
        let msgs = keys([0x1B, 0x5B, 0x5B, 0x78])
        #expect(msgs.count == 1)
        #expect(msgs[0].runes == ["x"])
    }

    // MARK: - SS3 coverage

    @Test func ss3RightAndLeft() {
        #expect(key([0x1B, 0x4F, 0x43])?.type == .right)
        #expect(key([0x1B, 0x4F, 0x44])?.type == .left)
    }

    @Test func ss3FunctionKeys() {
        #expect(key([0x1B, 0x4F, 0x51])?.type == .f(2))
        #expect(key([0x1B, 0x4F, 0x52])?.type == .f(3))
        #expect(key([0x1B, 0x4F, 0x53])?.type == .f(4))
    }

    // MARK: - Navigation variants

    @Test func homeVariants() {
        #expect(key([0x1B, 0x5B, 0x31, 0x7E])?.type == .home) // ESC [ 1 ~
        #expect(key([0x1B, 0x5B, 0x37, 0x7E])?.type == .home) // ESC [ 7 ~
    }

    @Test func endVariants() {
        #expect(key([0x1B, 0x5B, 0x34, 0x7E])?.type == .end) // ESC [ 4 ~
        #expect(key([0x1B, 0x5B, 0x38, 0x7E])?.type == .end) // ESC [ 8 ~
    }

    // MARK: - Unrecognized sequences

    @Test func unrecognizedCSIIsSkippedWithoutLeakingText() {
        // ESC [ 9 9 9 z followed by "a"
        let msgs = keys([0x1B, 0x5B, 0x39, 0x39, 0x39, 0x7A, 0x61])
        #expect(msgs.count == 1)
        #expect(msgs[0].runes == ["a"])
    }

    // MARK: - Printable runs

    @Test func mixedASCIIAndMultiByteRunes() {
        // "héllo"
        let bytes: [UInt8] = [0x68, 0xC3, 0xA9, 0x6C, 0x6C, 0x6F]
        #expect(key(bytes)?.runes == ["h", "é", "l", "l", "o"])
    }

    @Test func wideRunesInOneMessage() {
        // "日本"
        let bytes: [UInt8] = [0xE6, 0x97, 0xA5, 0xE6, 0x9C, 0xAC]
        #expect(key(bytes)?.runes == ["日", "本"])
    }

    @Test func invalidUTF8ByteIsSkipped() {
        let msg = key([0xFF, 0x61])
        #expect(msg?.runes == ["a"])
    }

    // MARK: - Split UTF-8 across reads

    @Test func truncatedUTF8IsRetainedWhenMoreDataMayFollow() {
        // First two bytes of 中 (0xE4 0xB8 0xAD) — the lead byte must not be consumed.
        let (msgs, consumed) = InputParser.parse(
            buffer: [0xE4, 0xB8],
            canHaveMoreData: true
        )
        #expect(msgs.isEmpty)
        #expect(consumed == 0)
    }

    @Test func truncatedUTF8CompletesOnNextRead() {
        let (first, firstConsumed) = InputParser.parse(
            buffer: [0xE4, 0xB8],
            canHaveMoreData: true
        )
        #expect(first.isEmpty)
        #expect(firstConsumed == 0)

        let (second, secondConsumed) = InputParser.parse(
            buffer: [0xE4, 0xB8, 0xAD],
            canHaveMoreData: false
        )
        #expect(secondConsumed == 3)
        #expect((second.first as? KeyMsg)?.runes == ["中"])
    }

    @Test func truncatedUTF8IsDroppedWhenFinal() {
        let (msgs, consumed) = InputParser.parse(
            buffer: [0xE4, 0xB8],
            canHaveMoreData: false
        )
        #expect(msgs.isEmpty)
        #expect(consumed == 2)
    }

    // MARK: - KeyMsg description

    @Test func keyDescriptionShiftTab() {
        let msg = KeyMsg(type: .shiftTab)
        #expect(msg.description == "shift+tab")
    }

    @Test func keyDescriptionCtrlC() {
        let msg = KeyMsg(type: .ctrl("c"))
        #expect(msg.description == "ctrl+c")
    }

    @Test func keyDescriptionAltUp() {
        let msg = KeyMsg(type: .up, alt: true)
        #expect(msg.description == "alt+up")
    }

    @Test func keyDescriptionF5() {
        let msg = KeyMsg(type: .f(5))
        #expect(msg.description == "f5")
    }

    @Test func keyDescriptionRune() {
        let msg = KeyMsg(type: .runes, runes: ["a"])
        #expect(msg.description == "a")
    }
}
