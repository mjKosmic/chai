import Testing
@testable import Chai

@Suite("StyledText")
struct StyledTextTests {

    // MARK: - Creation

    @Test func emptyStyledText() {
        let text = StyledText()
        #expect(text.segments.isEmpty)
        #expect(text.isEmpty)
    }

    @Test func stringLiteralCreation() {
        let text: StyledText = "Hello"
        #expect(text.segments.count == 1)
        #expect(text.segments[0].text == "Hello")
        #expect(text.segments[0].style == .default)
    }

    @Test func styledCreation() {
        let text = StyledText("Error", style: TextAttributes(foreground: .red))
        #expect(text.segments.count == 1)
        #expect(text.segments[0].text == "Error")
        #expect(text.segments[0].style.foreground == .red)
    }

    @Test func emptyStringCreation() {
        let text = StyledText("")
        #expect(text.segments.isEmpty)
        #expect(text.isEmpty)
    }

    // MARK: - Append

    @Test func appendText() {
        var text = StyledText("Hello")
        text.append(" World", style: TextAttributes(foreground: .blue))
        #expect(text.segments.count == 2)
        #expect(text.segments[1].text == " World")
    }

    @Test func appendEmptyString() {
        var text = StyledText("Hello")
        text.append("")
        #expect(text.segments.count == 1)
    }

    // MARK: - Concatenation

    @Test func concatenation() {
        let a: StyledText = "Hello"
        let b: StyledText = " World"
        let result = a + b
        #expect(result.segments.count == 2)
    }

    @Test func concatenationAssignment() {
        var text: StyledText = "Hello"
        text += " World"
        #expect(text.segments.count == 2)
    }

    @Test func concatenationWithEmpty() {
        let a: StyledText = "Hello"
        let b = StyledText()
        let result = a + b
        #expect(result.segments.count == 1)
    }

    // MARK: - Line counting

    @Test func lineCountSingleLine() {
        let text: StyledText = "Hello"
        #expect(text.lineCount() == 1)
    }

    @Test func lineCountMultiline() {
        let text: StyledText = "a\nb\nc"
        #expect(text.lineCount() == 3)
    }

    @Test func lineCountEmpty() {
        let text = StyledText()
        #expect(text.lineCount() == 0)
    }

    @Test func lineCountTrailingNewline() {
        let text: StyledText = "Hello\n"
        #expect(text.lineCount() == 2)
    }

    @Test func lineCountOnlyNewlines() {
        let text: StyledText = "\n\n\n"
        #expect(text.lineCount() == 4)
    }

    @Test func lineCountAcrossSegments() {
        let text = "Hello\n".fg(.red) + "World\n".fg(.blue)
        #expect(text.lineCount() == 3)
    }

    // MARK: - isEmpty

    @Test func isEmptyTrue() {
        #expect(StyledText().isEmpty)
        #expect(StyledText("").isEmpty)
    }

    @Test func isEmptyFalse() {
        let text: StyledText = "x"
        #expect(!text.isEmpty)
    }

    // MARK: - String styling extensions

    @Test func stringFg() {
        let text = "Hello".fg(.red)
        #expect(text.segments[0].style.foreground == .red)
    }

    @Test func stringBg() {
        let text = "Hello".bg(.blue)
        #expect(text.segments[0].style.background == .blue)
    }

    @Test func stringBold() {
        let text = "Hello".bold()
        #expect(text.segments[0].style.attributes.contains(.bold))
    }

    @Test func stringItalic() {
        let text = "Hello".italic()
        #expect(text.segments[0].style.attributes.contains(.italic))
    }

    @Test func stringDim() {
        let text = "Hello".dim()
        #expect(text.segments[0].style.attributes.contains(.dim))
    }

    @Test func stringStrikethrough() {
        let text = "Hello".strikethrough()
        #expect(text.segments[0].style.attributes.contains(.strikethrough))
    }

    // MARK: - StyledText chaining

    @Test func chainingFgBold() {
        let text = "Error".fg(.red).bold()
        #expect(text.segments[0].style.foreground == .red)
        #expect(text.segments[0].style.attributes.contains(.bold))
    }

    @Test func chainingBoldFg() {
        let text = "Error".bold().fg(.red)
        #expect(text.segments[0].style.foreground == .red)
        #expect(text.segments[0].style.attributes.contains(.bold))
    }

    @Test func chainingPreservesExistingAttributes() {
        let text = "Test".bold().italic().underline()
        let attrs = text.segments[0].style.attributes
        #expect(attrs.contains(.bold))
        #expect(attrs.contains(.italic))
        #expect(attrs.contains(.underline))
    }

    // MARK: - String interpolation

    @Test func plainInterpolation() {
        let count = 42
        let text: StyledText = "Count: \(count)"
        #expect(!text.isEmpty)
        // Should have segments for "Count: " and "42"
        let fullText = text.segments.map(\.text).joined()
        #expect(fullText == "Count: 42")
    }

    @Test func styledInterpolation() {
        let inner = "world".fg(.red)
        let text: StyledText = "Hello \(inner)!"
        #expect(text.segments.count == 3)
        #expect(text.segments[1].style.foreground == .red)
    }

    // MARK: - Array joining

    @Test func arrayJoinedDefault() {
        let items: [StyledText] = ["a", "b", "c"]
        let result = items.joined()
        let fullText = result.segments.map(\.text).joined()
        #expect(fullText == "a\nb\nc")
    }

    @Test func arrayJoinedCustomSeparator() {
        let items: [StyledText] = ["a", "b"]
        let result = items.joined(separator: " | ")
        let fullText = result.segments.map(\.text).joined()
        #expect(fullText == "a | b")
    }

    @Test func arrayJoinedEmpty() {
        let items: [StyledText] = []
        let result = items.joined()
        #expect(result.isEmpty)
    }

    // MARK: - Equality

    @Test func equalityIdentical() {
        let a: StyledText = "Hello"
        let b: StyledText = "Hello"
        #expect(a == b)
    }

    @Test func equalityDifferentText() {
        let a: StyledText = "Hello"
        let b: StyledText = "World"
        #expect(a != b)
    }

    @Test func equalityDifferentStyle() {
        let a = "Hello".fg(.red)
        let b = "Hello".fg(.blue)
        #expect(a != b)
    }
}
