import Testing
@testable import Latte

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
}
