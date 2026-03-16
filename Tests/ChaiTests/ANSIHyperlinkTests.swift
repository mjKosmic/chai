import Testing
@testable import Chai

@Suite("ANSI OSC 8 Hyperlinks")
struct ANSIHyperlinkTests {

    let st = "\u{1B}\\"   // String Terminator

    // MARK: - Basic correctness

    @Test func osc8ProducesCorrectSequence() {
        let result = ANSI.osc8(url: "https://example.com")
        #expect(result == "\u{1B}]8;;https://example.com\u{1B}\\")
    }

    @Test func osc8ResetProducesCorrectSequence() {
        #expect(ANSI.osc8Reset == "\u{1B}]8;;\u{1B}\\")
    }

    @Test func osc8CanBeComposedWithReset() {
        let link = ANSI.osc8(url: "https://example.com") + "click me" + ANSI.osc8Reset
        #expect(link.hasPrefix("\u{1B}]8;;https://example.com\u{1B}\\"))
        #expect(link.hasSuffix("\u{1B}]8;;\u{1B}\\"))
        #expect(link.contains("click me"))
    }

    // MARK: - Control-character sanitization (OSC injection prevention)

    @Test func osc8StripsEmbeddedESC() {
        // ESC (\u{1B}) would prematurely close the OSC and allow injection.
        let result = ANSI.osc8(url: "https://evil.com\u{1B}\\INJECTED")
        // After stripping ESC, only the backslash remains — harmless on its own.
        #expect(result == "\u{1B}]8;;https://evil.com\\INJECTED\u{1B}\\")
    }

    @Test func osc8StripsEmbeddedBEL() {
        // BEL (\u{07}) is an alternative OSC string terminator.
        let result = ANSI.osc8(url: "https://evil.com\u{07}INJECTED")
        #expect(result == "\u{1B}]8;;https://evil.comINJECTED\u{1B}\\")
    }

    @Test func osc8StripsAllC0ControlChars() {
        let controls = (0x00...0x1F).map { String(UnicodeScalar($0)!) }.joined()
        let result = ANSI.osc8(url: "https://x.com/\(controls)end")
        #expect(result == "\u{1B}]8;;https://x.com/end\u{1B}\\")
    }

    @Test func osc8StripsDelChar() {
        let result = ANSI.osc8(url: "https://x.com/\u{7F}end")
        #expect(result == "\u{1B}]8;;https://x.com/end\u{1B}\\")
    }

    @Test func osc8CleanURLPassesThroughUnchanged() {
        let url = "https://example.com/path?q=hello+world&lang=en#section"
        let result = ANSI.osc8(url: url)
        #expect(result == "\u{1B}]8;;\(url)\u{1B}\\")
    }
}
