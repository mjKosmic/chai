import Testing
@testable import Chai

// MARK: - OSC 0 Window Title Tests

@Suite("ANSI Window Title")
struct ANSIWindowTitleTests {

    // MARK: - Basic correctness

    @Test func setWindowTitleProducesCorrectSequence() {
        // OSC 0 ; title BEL
        #expect(ANSI.setWindowTitle("My App") == "\u{1B}]0;My App\u{07}")
    }

    @Test func setWindowTitleEmptyStringIsAllowed() {
        #expect(ANSI.setWindowTitle("") == "\u{1B}]0;\u{07}")
    }

    // MARK: - Control-character sanitization (OSC injection prevention)

    @Test func setWindowTitleStripsEmbeddedESC() {
        // ESC (\u{1B}) would prematurely close the OSC and allow injection.
        // The backslash that follows ESC in "ESC[2J" survives; only ESC is stripped.
        let result = ANSI.setWindowTitle("App\u{1B}[2JINJECTED")
        #expect(result == "\u{1B}]0;App[2JINJECTED\u{07}")
    }

    @Test func setWindowTitleStripsEmbeddedBEL() {
        // BEL (\u{07}) is the OSC terminator — embedding it would close the
        // sequence early and allow anything that follows to be injected.
        let result = ANSI.setWindowTitle("App\u{07}INJECTED")
        #expect(result == "\u{1B}]0;AppINJECTED\u{07}")
    }

    @Test func setWindowTitleStripsAllC0ControlChars() {
        let controls = (0x00...0x1F).map { String(UnicodeScalar($0)!) }.joined()
        let result = ANSI.setWindowTitle("pre\(controls)post")
        #expect(result == "\u{1B}]0;prepost\u{07}")
    }

    @Test func setWindowTitleStripsDelChar() {
        // DEL (U+007F) is also a non-printing control character.
        let result = ANSI.setWindowTitle("App\u{7F}Title")
        #expect(result == "\u{1B}]0;AppTitle\u{07}")
    }

    @Test func setWindowTitleCleanStringPassesThroughUnchanged() {
        let title = "My Application — Dashboard (42 items)"
        let result = ANSI.setWindowTitle(title)
        #expect(result == "\u{1B}]0;\(title)\u{07}")
    }

    @Test func setWindowTitleUnicodeIsAllowed() {
        // Non-ASCII printable characters are valid in a window title.
        let result = ANSI.setWindowTitle("アプリ 🚀")
        #expect(result == "\u{1B}]0;アプリ 🚀\u{07}")
    }

    // MARK: - Consistency with osc8

    @Test func setWindowTitleAndOSC8ApplySameSanitization() {
        // Both functions must strip the same set of characters from the
        // user-provided content so that the security invariant is consistent
        // across all OSC-emitting code paths.
        // NUL, BEL, ESC, and DEL are stripped from the payload; only the
        // structural protocol bytes remain in the output.
        let dirty = "test\u{00}\u{07}\u{1B}\u{7F}end"
        #expect(ANSI.setWindowTitle(dirty) == "\u{1B}]0;testend\u{07}")
        #expect(ANSI.osc8(url: dirty)      == "\u{1B}]8;;testend\u{1B}\\")
    }
}

// MARK: - OSC 8 Hyperlink Tests

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
