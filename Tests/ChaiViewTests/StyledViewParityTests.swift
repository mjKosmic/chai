import Testing
import Chai

// MARK: - Inline styling vs modifiers

@Suite("View styling — parity")
struct StyledViewParityTests {

    @Test func inlineTextAndModifiedTextPaintIdenticalCells() {
        let inline = embedBuffer(Text("x".fg(.red).bold()), width: 6)
        let modified = embedBuffer(Text("x").fg(.red).bold(), width: 6)
        #expect(inline == modified)
    }

    @Test func styleValueMatchesTheInlineChain() {
        let viaStyle = embedBuffer(
            Text("x").styled(Style().foreground(.red).bold()),
            width: 6
        )
        let inline = embedBuffer(Text("x".fg(.red).bold()), width: 6)
        #expect(viaStyle == inline)
    }

    @Test func styleValueMatchesInlineAcrossAllColorsAndAttributes() {
        let style = Style()
            .foreground(.trueColor(r: 10, g: 20, b: 30))
            .background(.brightBlue)
            .italic()
            .underline()
            .strikethrough()
        let viaStyle = embedBuffer(Text("xy").styled(style), width: 6)
        let inline = embedBuffer(
            Text("xy".fg(.trueColor(r: 10, g: 20, b: 30)).bg(.brightBlue).italic().underline().strikethrough()),
            width: 6
        )
        #expect(viaStyle == inline)
    }

    @Test func nestedModifiersMatchTheEquivalentInlineChain() {
        let nested = embedBuffer(
            Text("a b").fg(.blue).bold().bg(.brightBlack),
            width: 6
        )
        let inline = embedBuffer(
            Text("a b".fg(.blue).bold().bg(.brightBlack)),
            width: 6
        )
        #expect(nested == inline)
    }
}

// MARK: - Structured output

@Suite("View styling — structured output")
struct StyledViewStructuredOutputTests {

    @Test func embeddedStyledViewContainsNoEscapeBytes() {
        let view = VStack {
            Text("a b").fg(.red).bold()
            Text("c").bg(.blue)
        }
        .underline()

        let buffer = embedBuffer(view, width: 6)
        for row in 0..<buffer.height {
            for col in 0..<buffer.width {
                #expect(buffer[col, row].character != "\u{1B}")
            }
        }
    }

    @Test func styleRenderStillProducesANSIForOutOfBandOutput() {
        let rendered = Style().foreground(.red).bold().render("x")
        #expect(rendered.hasPrefix("\u{1B}["))
        #expect(rendered.contains("31"))
        #expect(rendered.contains("1"))
        #expect(rendered.hasSuffix("\u{1B}[0m"))
    }

    @Test func styleRenderHonorsTheNoColorProfile() {
        let style = Style().foreground(.red).bold()
        #expect(style.render("plain", profile: .noColor) == "plain")
    }
}
