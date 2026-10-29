import Testing
@testable import Chai

@Suite("Style")
struct StyleTests {
    @Test func emptyStylePassesThrough() {
        let style = Style()
        #expect(style.render("hello") == "hello")
    }

    @Test func boldWrapsInANSI() {
        let style = Style().bold()
        let result = style.render("test")
        #expect(result.contains("\u{1B}["))
        #expect(result.contains("1"))
        #expect(result.hasSuffix("\u{1B}[0m"))
    }

    @Test func foregroundColor() {
        let style = Style().foreground(.ansi(.red))
        let result = style.render("red")
        #expect(result.contains("31"))
    }

    @Test func backgroundColor() {
        let style = Style().background(.ansi(.blue))
        let result = style.render("blue")
        #expect(result.contains("44"))
    }

    @Test func trueColorForeground() {
        let style = Style().foreground(.trueColor(r: 255, g: 128, b: 0))
        let result = style.render("orange")
        #expect(result.contains("38;2;255;128;0"))
    }

    @Test func extendedColor() {
        let style = Style().foreground(.extended(208))
        let result = style.render("ext")
        #expect(result.contains("38;5;208"))
    }

    @Test func hexColor() {
        let color = Color.hex("#FF6B35")
        #expect(color != nil)
        if case let .trueColor(r, g, b) = color {
            #expect(r == 255)
            #expect(g == 107)
            #expect(b == 53)
        }
    }

    @Test func composedStyle() {
        let style = Style()
            .foreground(.ansi(.green))
            .bold()
            .underline()
        let result = style.render("styled")
        #expect(result.contains("32"))   // green fg
        #expect(result.contains("1"))    // bold
        #expect(result.contains("4"))    // underline
    }
}

@Suite("ColorProfile")
struct ColorProfileTests {
    @Test func detectNoColorEnv() {
        let profile = ColorProfile.detect(
            environment: ["NO_COLOR": "1"],
            isTerminal: true
        )
        #expect(profile == .noColor)
    }

    @Test func detectNotATTY() {
        let profile = ColorProfile.detect(
            environment: [:],
            isTerminal: false
        )
        #expect(profile == .noColor)
    }

    @Test func detectTrueColorFromColorterm() {
        let profile = ColorProfile.detect(
            environment: ["COLORTERM": "truecolor"],
            isTerminal: true
        )
        #expect(profile == .trueColor)
    }

    @Test func detectTrueColorFrom24bit() {
        let profile = ColorProfile.detect(
            environment: ["COLORTERM": "24bit"],
            isTerminal: true
        )
        #expect(profile == .trueColor)
    }

    @Test func detectTrueColorFromTermProgram() {
        let profile = ColorProfile.detect(
            environment: ["TERM_PROGRAM": "iTerm.app"],
            isTerminal: true
        )
        #expect(profile == .trueColor)
    }

    @Test func detectAnsi256FromTerm() {
        let profile = ColorProfile.detect(
            environment: ["TERM": "xterm-256color"],
            isTerminal: true
        )
        #expect(profile == .ansi256)
    }

    @Test func detectAnsiFromXterm() {
        let profile = ColorProfile.detect(
            environment: ["TERM": "xterm"],
            isTerminal: true
        )
        #expect(profile == .ansi)
    }

    @Test func defaultIsAnsi() {
        let profile = ColorProfile.detect(
            environment: [:],
            isTerminal: true
        )
        #expect(profile == .ansi)
    }

    @Test func comparable() {
        #expect(ColorProfile.noColor < ColorProfile.ansi)
        #expect(ColorProfile.ansi < ColorProfile.ansi256)
        #expect(ColorProfile.ansi256 < ColorProfile.trueColor)
    }
}

@Suite("ColorDownsampling")
struct ColorDownsamplingTests {
    @Test func trueColorUnchangedAtTrueColor() {
        let color = Color.trueColor(r: 200, g: 50, b: 50)
        #expect(color.downsampled(to: .trueColor) == color)
    }

    @Test func noColorReturnsNil() {
        let color = Color.trueColor(r: 200, g: 50, b: 50)
        #expect(color.downsampled(to: .noColor) == nil)
    }

    @Test func ansiDownsampleReturnsAnsiCase() {
        let color = Color.trueColor(r: 255, g: 0, b: 0)
        let result = color.downsampled(to: .ansi)
        if case .ansi? = result {
            // Good — downsampled to ANSI 16
        } else {
            #expect(Bool(false), "Expected .ansi case, got \(String(describing: result))")
        }
    }

    @Test func ansi256DownsampleReturnsExtendedCase() {
        let color = Color.trueColor(r: 100, g: 200, b: 100)
        let result = color.downsampled(to: .ansi256)
        if case .extended? = result {
            // Good — downsampled to 256-color palette
        } else {
            #expect(Bool(false), "Expected .extended case, got \(String(describing: result))")
        }
    }

    @Test func pureRedDownsamplesToAnsiRed() {
        let color = Color.trueColor(r: 255, g: 0, b: 0)
        let result = color.downsampled(to: .ansi)
        // Should map to bright red (index 9) which is closest to (255,0,0)
        #expect(result == .ansi(.brightRed))
    }

    @Test func ansiColorSurvivesTrueColorProfile() {
        let color = Color.ansi(.cyan)
        #expect(color.downsampled(to: .trueColor) == color)
    }
}

@Suite("ProfileAwareRendering")
struct ProfileAwareRenderingTests {
    @Test func noColorStripsEverything() {
        let style = Style().foreground(.trueColor(r: 255, g: 0, b: 0)).bold()
        let result = style.render("hello", profile: .noColor)
        #expect(result == "hello")
    }

    @Test func trueColorProfileIsDefault() {
        let style = Style().foreground(.trueColor(r: 255, g: 128, b: 0))
        let defaultResult  = style.render("test")
        let explicitResult = style.render("test", profile: .trueColor)
        #expect(defaultResult == explicitResult)
    }

    @Test func ansiProfileProduces16ColorCode() {
        let style = Style().foreground(.trueColor(r: 255, g: 0, b: 0))
        let result = style.render("red", profile: .ansi)
        // Should contain a basic ANSI color code (30-37 or 90-97), not 38;2;...
        #expect(!result.contains("38;2;"))
        #expect(!result.contains("38;5;"))
    }

    @Test func ansi256ProfileProducesExtendedCode() {
        let style = Style().foreground(.trueColor(r: 100, g: 200, b: 100))
        let result = style.render("green", profile: .ansi256)
        // Should contain extended color code 38;5;N, not 38;2;...
        #expect(!result.contains("38;2;"))
        #expect(result.contains("38;5;"))
    }

    @Test func boldPreservedAtAllProfiles() {
        let style = Style().bold()
        for profile in [ColorProfile.ansi, .ansi256, .trueColor] {
            let result = style.render("bold", profile: profile)
            #expect(result.contains("1"))
        }
    }
}
