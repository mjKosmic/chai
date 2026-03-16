import Testing
@testable import Latte

// MARK: - Milestone 3.1: Extended underline styles

@Suite("UnderlineStyle")
struct UnderlineStyleTests {

    // MARK: - Single (backward compat)

    @Test func singleEmitsSGR4() {
        let style = Style().underlineStyle(.single)
        let result = style.render("text")
        #expect(result == "\u{1B}[4mtext\u{1B}[0m")
    }

    @Test func underlineBuilderSetsSingle() {
        let style = Style().underline()
        let result = style.render("text")
        #expect(result == "\u{1B}[4mtext\u{1B}[0m")
    }

    @Test func isUnderlineTrueWhenSingle() {
        #expect(Style().underline().isUnderline == true)
        #expect(Style().underlineStyle(.single).isUnderline == true)
    }

    @Test func isUnderlineFalseForNone() {
        #expect(Style().isUnderline == false)
    }

    @Test func isUnderlineFalseForCurly() {
        // curly is not "single", so isUnderline should be false
        #expect(Style().underlineStyle(.curly).isUnderline == false)
    }

    @Test func settingIsUnderlineTrueMakesSingle() {
        var style = Style()
        style.isUnderline = true
        #expect(style.underlineStyle == .single)
        #expect(style.render("x") == "\u{1B}[4mx\u{1B}[0m")
    }

    @Test func settingIsUnderlineFalseClearsUnderline() {
        var style = Style().underlineStyle(.single)
        style.isUnderline = false
        #expect(style.underlineStyle == .none)
        #expect(style.render("x") == "x")
    }

    // MARK: - Double

    @Test func doubleEmitsSGR21() {
        let style = Style().underlineStyle(.double)
        let result = style.render("text")
        #expect(result == "\u{1B}[21mtext\u{1B}[0m")
    }

    // MARK: - Extended styles (4:n)

    @Test func curlyEmitsSGR4Colon3() {
        let style = Style().underlineStyle(.curly)
        let result = style.render("text")
        #expect(result == "\u{1B}[4:3mtext\u{1B}[0m")
    }

    @Test func dottedEmitsSGR4Colon4() {
        let style = Style().underlineStyle(.dotted)
        let result = style.render("text")
        #expect(result == "\u{1B}[4:4mtext\u{1B}[0m")
    }

    @Test func dashedEmitsSGR4Colon5() {
        let style = Style().underlineStyle(.dashed)
        let result = style.render("text")
        #expect(result == "\u{1B}[4:5mtext\u{1B}[0m")
    }

    @Test func noneEmitsNoUnderlineCode() {
        let style = Style().underlineStyle(.none)
        let result = style.render("text")
        #expect(result == "text")
    }

    // MARK: - Underline color

    @Test func underlineColorTrueColorEmitsSGR58() {
        let style = Style()
            .underlineStyle(.single)
            .underlineColor(.trueColor(r: 255, g: 0, b: 0))
        let result = style.render("text")
        #expect(result.contains("58;2;255;0;0"))
    }

    @Test func underlineColorExtendedEmitsSGR58_5() {
        let style = Style()
            .underlineStyle(.single)
            .underlineColor(.extended(196))
        let result = style.render("text")
        #expect(result.contains("58;5;196"))
    }

    @Test func underlineColorAnsiEmitsSGR58_5WithRawValue() {
        // ANSI red = raw value 1
        let style = Style()
            .underlineStyle(.single)
            .underlineColor(.ansi(.red))
        let result = style.render("text")
        #expect(result.contains("58;5;1"))
    }

    @Test func underlineColorAndStyleCombine() {
        let style = Style()
            .underlineStyle(.curly)
            .underlineColor(.trueColor(r: 255, g: 0, b: 0))
        let result = style.render("text")
        #expect(result.contains("4:3"))
        #expect(result.contains("58;2;255;0;0"))
    }

    @Test func underlineColorOmittedAtNoColorProfile() {
        let style = Style()
            .underlineStyle(.single)
            .underlineColor(.trueColor(r: 255, g: 0, b: 0))
        let result = style.render("text", profile: .noColor)
        #expect(result == "text")
    }

    // MARK: - isEmpty

    @Test func emptyStyleHasNoneUnderline() {
        let style = Style()
        #expect(style.underlineStyle == .none)
        #expect(style.underlineColor == nil)
        #expect(style.isEmpty)
    }

    @Test func styleWithUnderlineIsNotEmpty() {
        #expect(!Style().underlineStyle(.curly).isEmpty)
        #expect(!Style().underlineColor(.extended(1)).isEmpty)
    }

    // MARK: - Backward compatibility: existing composed-style test still passes

    @Test func composedStyleWithUnderlineStillWorks() {
        let style = Style()
            .foreground(.ansi(.green))
            .bold()
            .underline()
        let result = style.render("styled")
        #expect(result.contains("32"))   // green fg
        #expect(result.contains("1"))    // bold
        #expect(result.contains("4"))    // single underline
    }

    // MARK: - Equatable: underlineStyle is part of identity

    @Test func differentUnderlineStylesAreNotEqual() {
        let s1 = Style().underlineStyle(.single)
        let s2 = Style().underlineStyle(.curly)
        #expect(s1 != s2)
    }

    @Test func sameUnderlineStylesAreEqual() {
        let s1 = Style().underlineStyle(.curly)
        let s2 = Style().underlineStyle(.curly)
        #expect(s1 == s2)
    }
}
