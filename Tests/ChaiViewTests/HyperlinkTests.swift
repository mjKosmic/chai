import Testing
@testable import Chai

// MARK: - Milestone 3.2: OSC 8 Hyperlinks

@Suite("Hyperlink")
struct HyperlinkTests {

    let st = "\u{1B}\\"  // String Terminator (ESC \)

    // MARK: - Basic rendering

    @Test func hyperlinkWrapsInOSC8() {
        let style = Style().hyperlink("https://example.com")
        let result = style.render("Visit us")
        let expected =
            "\u{1B}]8;;https://example.com\(st)"
            + "Visit us"
            + "\u{1B}]8;;\(st)"
        #expect(result == expected)
    }

    @Test func noHyperlinkProducesNoOSC8() {
        let style = Style()
        let result = style.render("plain text")
        #expect(!result.contains("\u{1B}]8;;"))
        #expect(result == "plain text")
    }

    @Test func hyperlinkWithSGRStyleWrapsCorrectly() {
        let style = Style()
            .bold()
            .hyperlink("https://example.com")
        let result = style.render("click")
        // OSC 8 open sequence should come first
        #expect(result.hasPrefix("\u{1B}]8;;https://example.com\(st)"))
        // Bold SGR should be inside
        #expect(result.contains("\u{1B}[1mclick\u{1B}[0m"))
        // OSC 8 close sequence should come last
        #expect(result.hasSuffix("\u{1B}]8;;\(st)"))
    }

    // MARK: - noColor profile strips hyperlinks

    @Test func hyperlinkOmittedAtNoColorProfile() {
        let style = Style().hyperlink("https://example.com")
        let result = style.render("Visit us", profile: .noColor)
        #expect(result == "Visit us")
        #expect(!result.contains("\u{1B}]8;;"))
    }

    @Test func styledHyperlinkOmittedAtNoColorProfile() {
        let style = Style()
            .bold()
            .hyperlink("https://example.com")
        let result = style.render("click", profile: .noColor)
        // noColor strips everything
        #expect(result == "click")
    }

    // MARK: - Builder API

    @Test func hyperlinkBuilderSetsProperty() {
        let style = Style().hyperlink("https://example.com")
        #expect(style.hyperlink == "https://example.com")
    }

    @Test func nilHyperlinkIsDefault() {
        #expect(Style().hyperlink == nil)
    }

    // MARK: - isEmpty

    @Test func styleWithHyperlinkIsNotEmpty() {
        #expect(!Style().hyperlink("https://example.com").isEmpty)
    }

    @Test func styleWithoutHyperlinkCanBeEmpty() {
        #expect(Style().isEmpty)
    }

    // MARK: - Equatable

    @Test func hyperlinkPartOfEquality() {
        let s1 = Style().hyperlink("https://a.com")
        let s2 = Style().hyperlink("https://b.com")
        let s3 = Style().hyperlink("https://a.com")
        #expect(s1 != s2)
        #expect(s1 == s3)
    }

    @Test func nilVsNonNilHyperlinkNotEqual() {
        let withLink = Style().hyperlink("https://example.com")
        let withoutLink = Style()
        #expect(withLink != withoutLink)
    }

    // MARK: - Control-character sanitization (OSC injection prevention)

    @Test func embeddedESCIsStrippedFromURL() {
        // ESC (\u{1B}) would prematurely terminate the OSC sequence.
        let style = Style().hyperlink("https://evil.com\u{1B}\\INJECTED")
        let result = style.render("click")
        // The rendered output must not contain the raw ESC followed by backslash
        // inside the OSC parameter field. After stripping, the URL becomes
        // "https://evil.com\\INJECTED" — the backslash is harmless on its own.
        #expect(!result.contains("INJECTED\u{1B}]8;;"))
        // The OSC open tag must contain only the sanitized URL
        let openTag = "\u{1B}]8;;https://evil.com\\INJECTED\u{1B}\\"
        #expect(result.hasPrefix(openTag))
    }

    @Test func embeddedBELIsStrippedFromURL() {
        // BEL (\u{07}) is an alternative OSC string terminator.
        let style = Style().hyperlink("https://evil.com\u{07}INJECTED")
        let result = style.render("click")
        let openTag = "\u{1B}]8;;https://evil.comINJECTED\u{1B}\\"
        #expect(result.hasPrefix(openTag))
    }

    @Test func embeddedNULIsStrippedFromURL() {
        let style = Style().hyperlink("https://x.com\u{00}payload")
        let result = style.render("t")
        #expect(result.hasPrefix("\u{1B}]8;;https://x.compayload\u{1B}\\"))
    }

    @Test func allC0ControlCharsAreStripped() {
        // Build a URL containing every C0 control code (0x00–0x1F).
        let controls = (0x00...0x1F).map { String(UnicodeScalar($0)!) }.joined()
        let style = Style().hyperlink("https://x.com/\(controls)end")
        let result = style.render("t")
        // After stripping, the URL must contain no control characters.
        #expect(result.hasPrefix("\u{1B}]8;;https://x.com/end\u{1B}\\"))
    }

    @Test func delCharIsStrippedFromURL() {
        // DEL (0x7F) is also excluded.
        let style = Style().hyperlink("https://x.com/\u{7F}end")
        let result = style.render("t")
        #expect(result.hasPrefix("\u{1B}]8;;https://x.com/end\u{1B}\\"))
    }

    @Test func cleanURLIsUnaffectedBySanitization() {
        // A well-formed URL must pass through completely unchanged.
        let url = "https://example.com/path?q=hello+world&lang=en#section"
        let style = Style().hyperlink(url)
        let result = style.render("click")
        #expect(result.hasPrefix("\u{1B}]8;;\(url)\u{1B}\\"))
    }

    @Test func hyperlinkStoredVerbatimEquatableUnaffected() {
        // The stored property keeps the raw string so Equatable comparisons
        // are not affected by sanitization — sanitization is emission-only.
        let raw = "https://x.com\u{1B}bad"
        let style = Style().hyperlink(raw)
        #expect(style.hyperlink == raw)
        #expect(style == Style().hyperlink(raw))
    }
}
