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

    @Test func f5() {
        let msg = key([0x1B, 0x5B, 0x31, 0x35, 0x7E]) // ESC [ 1 5 ~
        #expect(msg?.type == .f(5))
    }

    @Test func f12() {
        let msg = key([0x1B, 0x5B, 0x32, 0x34, 0x7E]) // ESC [ 2 4 ~
        #expect(msg?.type == .f(12))
    }

    // MARK: - Alt modifier

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

    // MARK: - KeyMsg description

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

// MARK: - KeyType Equatable

extension KeyType: Equatable {
    public static func == (lhs: KeyType, rhs: KeyType) -> Bool {
        switch (lhs, rhs) {
        case (.runes, .runes): return true
        case (.enter, .enter): return true
        case (.tab, .tab): return true
        case (.backspace, .backspace): return true
        case (.delete, .delete): return true
        case (.escape, .escape): return true
        case (.space, .space): return true
        case (.up, .up): return true
        case (.down, .down): return true
        case (.left, .left): return true
        case (.right, .right): return true
        case (.home, .home): return true
        case (.end, .end): return true
        case (.pageUp, .pageUp): return true
        case (.pageDown, .pageDown): return true
        case (.insert, .insert): return true
        case (.shiftUp, .shiftUp): return true
        case (.shiftDown, .shiftDown): return true
        case (.shiftLeft, .shiftLeft): return true
        case (.shiftRight, .shiftRight): return true
        case (.shiftHome, .shiftHome): return true
        case (.shiftEnd, .shiftEnd): return true
        case (.ctrlUp, .ctrlUp): return true
        case (.ctrlDown, .ctrlDown): return true
        case (.ctrlLeft, .ctrlLeft): return true
        case (.ctrlRight, .ctrlRight): return true
        case (.ctrlHome, .ctrlHome): return true
        case (.ctrlEnd, .ctrlEnd): return true
        case (.ctrlShiftUp, .ctrlShiftUp): return true
        case (.ctrlShiftDown, .ctrlShiftDown): return true
        case (.ctrlShiftLeft, .ctrlShiftLeft): return true
        case (.ctrlShiftRight, .ctrlShiftRight): return true
        case (.ctrlShiftHome, .ctrlShiftHome): return true
        case (.ctrlShiftEnd, .ctrlShiftEnd): return true
        case (.ctrl(let a), .ctrl(let b)): return a == b
        case (.f(let a), .f(let b)): return a == b
        case (.unknown, .unknown): return true
        default: return false
        }
    }
}
