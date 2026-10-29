import Testing
@testable import Chai

@Suite("ANSI sanitization")
struct ANSISanitizationTests {

    // MARK: - Sequence families

    @Test func removesCSI() {
        let input = "\u{1B}[31mred\u{1B}[0m"
        #expect(strippingANSISequences(input) == "red")
    }

    @Test func removesOSCTerminatedByBEL() {
        let input = "\u{1B}]0;window title\u{07}visible"
        #expect(strippingANSISequences(input) == "visible")
    }

    @Test func removesOSCTerminatedByST() {
        let input = "\u{1B}]8;;https://example.com\u{1B}\\link\u{1B}]8;;\u{1B}\\"
        #expect(strippingANSISequences(input) == "link")
    }

    @Test func removesSS3() {
        #expect(strippingANSISequences("\u{1B}OA") == "")
        #expect(strippingANSISequences("\u{1B}OAtail") == "tail")
    }

    @Test func removesTwoByteEscape() {
        #expect(strippingANSISequences("\u{1B}=text") == "text")
    }

    @Test func dropsTrailingEscapeByte() {
        #expect(strippingANSISequences("text\u{1B}") == "text")
    }

    @Test func dropsUnterminatedSequence() {
        #expect(strippingANSISequences("text\u{1B}[31") == "text")
    }

    @Test func leavesOrdinaryBracketsAlone() {
        let input = "array[0] and dict[key]"
        #expect(strippingANSISequences(input) == input)
    }

    @Test func leavesTextWithoutEscapeBytesAlone() {
        let input = "héllo 日本 😀"
        #expect(strippingANSISequences(input) == input)
    }

    // MARK: - StyledText entry points

    @Test func initStripsEscapeSequences() {
        let text = StyledText("\u{1B}[31mred\u{1B}[0m")
        #expect(text.plainText == "red")
        #expect(text.segments.count == 1)
    }

    @Test func appendStripsEscapeSequences() {
        var text = StyledText("a")
        text.append("\u{1B}[31mb")
        #expect(text.plainText == "ab")
    }

    @Test func stringLiteralStripsEscapeSequences() {
        let text: StyledText = "\u{1B}[31mred"
        #expect(text.plainText == "red")
    }

    @Test func interpolationStripsEscapeSequences() {
        let injected = "\u{1B}[31mb"
        let text: StyledText = "a\(injected)"
        #expect(text.plainText == "ab")
    }

    @Test func styledInterpolationStripsEscapeSequences() {
        let injected = "\u{1B}[31mb"
        let text: StyledText = "a\(injected, .red)"
        #expect(text.plainText == "ab")
    }

    // MARK: - View content

    @Test func viewOutputStripsEscapeSequences() {
        let output = ViewOutput("\u{1B}[31mHi\u{1B}[0m")
        #expect(output.content.plainText == "Hi")
    }

    @Test func sanitizedContentHasNoEscapeBytesAndCorrectWidth() {
        let output = ViewOutput("\u{1B}[31mHi\u{1B}[0m")
        #expect(output.content.segments.allSatisfy { segment in
            !segment.text.contains("\u{1B}")
        })
        #expect(output.content.columnWidth == 2)
        #expect(output.content.maxLineWidth == 2)
    }

    @Test func oscParametersNeverReachContent() {
        let output = ViewOutput("\u{1B}]0;secret\u{07}shown")
        #expect(output.content.plainText == "shown")
        #expect(output.content.plainText.contains("secret") == false)
    }
}
