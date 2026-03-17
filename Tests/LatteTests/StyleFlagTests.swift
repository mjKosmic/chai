import Testing
@testable import Latte

// MARK: - SGR test helper

/// Parses the SGR parameter tokens from the first CSI escape sequence in `s`.
///
/// For example, `"\u{1B}[1;31mfoo\u{1B}[0m"` → `["1", "31"]`.
/// Returns an empty array if no CSI sequence is found.
private func sgrParams(_ s: String) -> [String] {
    // Find ESC
    guard let escIdx = s.firstIndex(of: "\u{1B}") else { return [] }
    let afterEsc = s.index(after: escIdx)
    guard afterEsc < s.endIndex, s[afterEsc] == "[" else { return [] }
    let afterBracket = s.index(after: afterEsc)
    // Find the closing 'm'
    guard let mIdx = s[afterBracket...].firstIndex(of: "m") else { return [] }
    let params = String(s[afterBracket..<mIdx])
    return params.split(separator: ";", omittingEmptySubsequences: false).map(String.init)
}

// MARK: - Milestone 5.1: StyleFlag and three-state style properties

@Suite("StyleFlag")
struct StyleFlagTests {

    // MARK: Default state

    @Test func defaultStyleAllFlagsUnset() {
        let s = Style()
        #expect(s.isBold == .unset)
        #expect(s.isDim == .unset)
        #expect(s.isItalic == .unset)
        #expect(s.isStrikethrough == .unset)
        #expect(s.isReverse == .unset)
        #expect(s.isBlink == .unset)
    }

    @Test func defaultStyleIsEmpty() {
        #expect(Style().isEmpty)
    }

    // MARK: .on via builder methods (backward compatibility)

    @Test func boldBuilderSetsFlagToOn() {
        let s = Style().bold()
        #expect(s.isBold == .on)
    }

    @Test func dimBuilderSetsFlagToOn() {
        #expect(Style().dim().isDim == .on)
    }

    @Test func italicBuilderSetsFlagToOn() {
        #expect(Style().italic().isItalic == .on)
    }

    @Test func strikethroughBuilderSetsFlagToOn() {
        #expect(Style().strikethrough().isStrikethrough == .on)
    }

    @Test func reverseBuilderSetsFlagToOn() {
        #expect(Style().reverse().isReverse == .on)
    }

    @Test func blinkBuilderSetsFlagToOn() {
        #expect(Style().blink().isBlink == .on)
    }

    // MARK: .on flags emit SGR codes

    @Test func boldOnEmitsSGR1() {
        let result = Style().bold().render("x")
        #expect(result == "\u{1B}[1mx\u{1B}[0m")
    }

    @Test func dimOnEmitsSGR2() {
        let result = Style().dim().render("x")
        #expect(result == "\u{1B}[2mx\u{1B}[0m")
    }

    @Test func italicOnEmitsSGR3() {
        let result = Style().italic().render("x")
        #expect(result == "\u{1B}[3mx\u{1B}[0m")
    }

    @Test func blinkOnEmitsSGR5() {
        let result = Style().blink().render("x")
        #expect(result == "\u{1B}[5mx\u{1B}[0m")
    }

    @Test func reverseOnEmitsSGR7() {
        let result = Style().reverse().render("x")
        #expect(result == "\u{1B}[7mx\u{1B}[0m")
    }

    @Test func strikethroughOnEmitsSGR9() {
        let result = Style().strikethrough().render("x")
        #expect(result == "\u{1B}[9mx\u{1B}[0m")
    }

    // MARK: .off builders

    @Test func notBoldSetsFlagToOff() {
        #expect(Style().notBold().isBold == .off)
    }

    @Test func notDimSetsFlagToOff() {
        #expect(Style().notDim().isDim == .off)
    }

    @Test func notItalicSetsFlagToOff() {
        #expect(Style().notItalic().isItalic == .off)
    }

    @Test func notStrikethroughSetsFlagToOff() {
        #expect(Style().notStrikethrough().isStrikethrough == .off)
    }

    @Test func notReverseSetsFlagToOff() {
        #expect(Style().notReverse().isReverse == .off)
    }

    @Test func notBlinkSetsFlagToOff() {
        #expect(Style().notBlink().isBlink == .off)
    }

    // MARK: .off flags emit NO SGR codes (terminal defaults apply)

    @Test func notBoldEmitsNoSGR() {
        let result = Style().notBold().render("x")
        #expect(result == "x")
    }

    @Test func notItalicEmitsNoSGR() {
        let result = Style().notItalic().render("x")
        #expect(result == "x")
    }

    // MARK: .unset builders

    @Test func unsetBoldReturnsToUnset() {
        let s = Style().bold().unsetBold()
        #expect(s.isBold == .unset)
        #expect(s.render("x") == "x")
    }

    @Test func unsetDimReturnsToUnset() {
        #expect(Style().dim().unsetDim().isDim == .unset)
    }

    @Test func unsetItalicReturnsToUnset() {
        #expect(Style().italic().unsetItalic().isItalic == .unset)
    }

    @Test func unsetStrikethroughReturnsToUnset() {
        #expect(Style().strikethrough().unsetStrikethrough().isStrikethrough == .unset)
    }

    @Test func unsetReverseReturnsToUnset() {
        #expect(Style().reverse().unsetReverse().isReverse == .unset)
    }

    @Test func unsetBlinkReturnsToUnset() {
        #expect(Style().blink().unsetBlink().isBlink == .unset)
    }

    // MARK: isEmpty with StyleFlag

    @Test func styleFlagOnIsNotEmpty() {
        #expect(!Style().bold().isEmpty)
        #expect(!Style().dim().isEmpty)
        #expect(!Style().italic().isEmpty)
        #expect(!Style().strikethrough().isEmpty)
        #expect(!Style().reverse().isEmpty)
        #expect(!Style().blink().isEmpty)
    }

    @Test func styleFlagOffIsNotEmpty() {
        // .off carries explicit intent and is considered non-empty
        #expect(!Style().notBold().isEmpty)
        #expect(!Style().notItalic().isEmpty)
    }

    @Test func styleFlagUnsetIsEmpty() {
        // An .unset flag (the default) contributes nothing
        let s = Style().bold().unsetBold()
        #expect(s.isEmpty)
    }

    // MARK: isEmpty with underline (fixes pre-existing bug)

    @Test func underlineStyleCurlyIsNotEmpty() {
        #expect(!Style().underlineStyle(.curly).isEmpty)
    }

    @Test func underlineColorAloneIsNotEmpty() {
        // Even without an underline style set, a color alone is non-empty
        #expect(!Style().underlineColor(.extended(1)).isEmpty)
    }

    @Test func underlineStyleNoneAndNoColorIsEmpty() {
        let s = Style()
        #expect(s.underlineStyle == .none)
        #expect(s.underlineColor == nil)
        #expect(s.isEmpty)
    }

    // MARK: init backward compatibility (Bool parameters)

    @Test func initWithBoolTrueMapsToOn() {
        let s = Style(isBold: true, isDim: true, isItalic: true,
                      isStrikethrough: true, isReverse: true, isBlink: true)
        #expect(s.isBold == .on)
        #expect(s.isDim == .on)
        #expect(s.isItalic == .on)
        #expect(s.isStrikethrough == .on)
        #expect(s.isReverse == .on)
        #expect(s.isBlink == .on)
    }

    @Test func initWithBoolFalseMapsToUnset() {
        let s = Style(isBold: false, isDim: false)
        #expect(s.isBold == .unset)
        #expect(s.isDim == .unset)
    }

    // MARK: Equatable

    @Test func differentFlagsAreNotEqual() {
        #expect(Style().bold() != Style())
        #expect(Style().bold() != Style().notBold())
        #expect(Style().notBold() != Style())
    }

    @Test func sameFlagStateIsEqual() {
        #expect(Style().bold() == Style().bold())
        #expect(Style().notBold() == Style().notBold())
    }
}

// MARK: - Milestone 5.2: Style Inheritance

@Suite("StyleInheritance")
struct StyleInheritanceTests {

    // MARK: Color inheritance

    @Test func childForegroundOverridesParent() {
        let parent = Style().foreground(.ansi(.blue))
        let child  = Style().foreground(.ansi(.red)).inheriting(from: parent)
        #expect(child.foreground == .ansi(.red))
    }

    @Test func unsetChildForegroundInheritedFromParent() {
        let parent = Style().foreground(.ansi(.blue))
        let child  = Style().inheriting(from: parent)
        #expect(child.foreground == .ansi(.blue))
    }

    @Test func childBackgroundOverridesParent() {
        let parent = Style().background(.ansi(.green))
        let child  = Style().background(.ansi(.red)).inheriting(from: parent)
        #expect(child.background == .ansi(.red))
    }

    @Test func unsetChildBackgroundInheritedFromParent() {
        let parent = Style().background(.ansi(.green))
        let child  = Style().inheriting(from: parent)
        #expect(child.background == .ansi(.green))
    }

    // MARK: StyleFlag inheritance

    @Test func unsetBoldInheritsParentBold() {
        let parent = Style().bold()
        let child  = Style().inheriting(from: parent)
        #expect(child.isBold == .on)
    }

    @Test func onBoldNotOverriddenByParent() {
        let parent = Style() // parent has unset bold
        let child  = Style().bold().inheriting(from: parent)
        #expect(child.isBold == .on)
    }

    @Test func offBoldBlocksParentBold() {
        let parent = Style().bold()
        let child  = Style().notBold().inheriting(from: parent)
        // .off explicitly suppresses bold — parent cannot override
        #expect(child.isBold == .off)
    }

    @Test func allFlagsInheritedWhenUnset() {
        let parent = Style().bold().dim().italic()
            .strikethrough().reverse().blink()
        let child  = Style().inheriting(from: parent)
        #expect(child.isBold == .on)
        #expect(child.isDim == .on)
        #expect(child.isItalic == .on)
        #expect(child.isStrikethrough == .on)
        #expect(child.isReverse == .on)
        #expect(child.isBlink == .on)
    }

    @Test func allFlagsBlockedWhenOff() {
        let parent = Style().bold().italic()
        let child  = Style().notBold().notItalic().inheriting(from: parent)
        #expect(child.isBold == .off)
        #expect(child.isItalic == .off)
    }

    // MARK: Underline inheritance

    @Test func underlineStyleInheritedWhenNone() {
        let parent = Style().underlineStyle(.curly)
        let child  = Style().inheriting(from: parent)
        #expect(child.underlineStyle == .curly)
    }

    @Test func underlineStyleNotOverriddenByParent() {
        let parent = Style().underlineStyle(.double)
        let child  = Style().underlineStyle(.dotted).inheriting(from: parent)
        #expect(child.underlineStyle == .dotted)
    }

    @Test func underlineColorInheritedWhenNil() {
        let parent = Style().underlineColor(.ansi(.red))
        let child  = Style().inheriting(from: parent)
        #expect(child.underlineColor == .ansi(.red))
    }

    @Test func underlineColorNotOverriddenByParent() {
        let parent = Style().underlineColor(.ansi(.red))
        let child  = Style().underlineColor(.ansi(.blue)).inheriting(from: parent)
        #expect(child.underlineColor == .ansi(.blue))
    }

    // MARK: Hyperlink inheritance

    @Test func hyperlinkInheritedWhenNil() {
        let parent = Style().hyperlink("https://example.com")
        let child  = Style().inheriting(from: parent)
        #expect(child.hyperlink == "https://example.com")
    }

    @Test func hyperlinkNotOverriddenByParent() {
        let parent = Style().hyperlink("https://parent.com")
        let child  = Style().hyperlink("https://child.com").inheriting(from: parent)
        #expect(child.hyperlink == "https://child.com")
    }

    // MARK: Non-mutating guarantee

    @Test func receiverUnchangedAfterInheriting() {
        let parent = Style().bold().foreground(.ansi(.blue))
        let child  = Style()
        let _      = child.inheriting(from: parent)
        // child should be unchanged
        #expect(child.isBold == .unset)
        #expect(child.foreground == nil)
    }

    @Test func parentUnchangedAfterInheriting() {
        let parent = Style().bold().foreground(.ansi(.blue))
        let child  = Style().foreground(.ansi(.red))
        let _      = child.inheriting(from: parent)
        #expect(parent.isBold == .on)
        #expect(parent.foreground == .ansi(.blue))
    }

    // MARK: Rendered output after inheritance

    @Test func inheritedBoldRendersCorrectly() {
        let parent = Style().bold()
        let child  = Style().foreground(.ansi(.red)).inheriting(from: parent)
        let result = child.render("hello")
        // Parse the SGR parameters to avoid substring false-positives:
        // "31" (red fg) contains "1", so result.contains("1") is unreliable.
        let params = sgrParams(result)
        #expect(params.contains("31"))  // red fg
        #expect(params.contains("1"))   // bold (exact token, not substring)
    }

    @Test func blockedBoldNotRendered() {
        let parent = Style().bold()
        let child  = Style().notBold().inheriting(from: parent)
        let result = child.render("x")
        // .off bold emits nothing (same as unset; terminal default applies)
        #expect(result == "x")
    }

    @Test func mixed_inheritance_scenario() {
        // Simulates a theme: base style with blue foreground and bold.
        // A component overrides foreground to red, explicitly suppresses bold.
        let base      = Style().foreground(.ansi(.blue)).bold()
        let component = Style().foreground(.ansi(.red)).notBold()
                               .inheriting(from: base)
        #expect(component.foreground == .ansi(.red))
        #expect(component.isBold == .off)
        // Render should have red fg only, no bold.
        // Parse SGR params for exact token matching — avoids substring
        // false-positives (e.g. "31" containing "1", or bold appearing
        // first/last in the param list defeating ";1;" substring checks).
        let result = component.render("text")
        let params = sgrParams(result)
        #expect(params.contains("31"))   // red fg present
        #expect(!params.contains("1"))   // bold token absent
    }
}
