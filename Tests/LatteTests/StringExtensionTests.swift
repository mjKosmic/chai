import Testing
@testable import Latte

@Suite("String Extensions")
struct StringExtensionTests {

    // MARK: - Chaining produces same result as free functions

    @Test func chainedPadBorderMarginMatchesFreeFunction() {
        let content = "Hello"
        let chained = content.padded(1, 2).bordered(.rounded).margined(top: 1, left: 2)
        let free = margin(border(pad(content, 1, 2), .rounded), top: 1, left: 2)
        #expect(chained == free)
    }

    @Test func chainedAlignPadBorderMatchesFreeFunction() {
        let content = "Hi"
        let chained = content.aligned(width: 10, .center).padded(1).bordered(.normal)
        let free = border(pad(align(content, width: 10, .center), 1), .normal)
        #expect(chained == free)
    }

    // MARK: - Padding extensions

    @Test func paddedNamedParameters() {
        #expect("Hi".padded(top: 1, left: 2) == pad("Hi", top: 1, left: 2))
    }

    @Test func paddedAllSides() {
        #expect("Hi".padded(1) == pad("Hi", 1))
    }

    @Test func paddedVerticalHorizontal() {
        #expect("Hi".padded(1, 2) == pad("Hi", 1, 2))
    }

    @Test func paddedTopSidesBottom() {
        #expect("Hi".padded(1, 2, 0) == pad("Hi", 1, 2, 0))
    }

    // MARK: - Margin extensions

    @Test func marginedNamedParameters() {
        #expect("Hi".margined(top: 1, left: 2) == margin("Hi", top: 1, left: 2))
    }

    @Test func marginedAllSides() {
        #expect("Hi".margined(1) == margin("Hi", 1))
    }

    @Test func marginedVerticalHorizontal() {
        #expect("Hi".margined(1, 2) == margin("Hi", 1, 2))
    }

    @Test func marginedTopSidesBottom() {
        #expect("Hi".margined(1, 2, 0) == margin("Hi", 1, 2, 0))
    }

    // MARK: - Border extension

    @Test func borderedDefaultStyle() {
        #expect("Hi".bordered() == border("Hi"))
    }

    @Test func borderedWithStyle() {
        #expect("Hi".bordered(.normal) == border("Hi", .normal))
    }

    @Test func borderedSelectiveSides() {
        #expect(
            "Hi".bordered(.normal, top: true, right: false, bottom: true, left: false)
            == border("Hi", .normal, top: true, right: false, bottom: true, left: false)
        )
    }

    // MARK: - Alignment extension

    @Test func alignedLeftDefault() {
        #expect("Hi".aligned(width: 8) == align("Hi", width: 8))
    }

    @Test func alignedCenter() {
        #expect("Hi".aligned(width: 8, .center) == align("Hi", width: 8, .center))
    }

    @Test func alignedFractional() {
        let alignment = HorizontalAlignment(fraction: 0.75)
        #expect("Hi".aligned(width: 10, alignment) == align("Hi", width: 10, alignment))
    }

    // MARK: - Size enforcement extensions

    @Test func enforcedWidth() {
        #expect("Hi".enforced(width: 8) == enforceWidth("Hi", 8))
    }

    @Test func enforcedWidthWithAlignment() {
        #expect("Hi".enforced(width: 8, alignment: .right) == enforceWidth("Hi", 8, alignment: .right))
    }

    @Test func enforcedHeight() {
        #expect("Hi".enforced(height: 4) == enforceHeight("Hi", 4))
    }

    @Test func enforcedHeightWithAlignment() {
        #expect("Hi".enforced(height: 4, alignment: .bottom) == enforceHeight("Hi", 4, alignment: .bottom))
    }

    // MARK: - Clamping extensions

    @Test func clampedWidth() {
        #expect("Hello, World!".clamped(width: 5) == clampWidth("Hello, World!", 5))
    }

    @Test func clampedHeight() {
        #expect("A\nB\nC\nD".clamped(height: 2) == clampHeight("A\nB\nC\nD", 2))
    }

    @Test func clampedBothDimensions() {
        let text = "Hello, World!\nSecond line\nThird"
        #expect(text.clamped(maxWidth: 8, maxHeight: 2) == clamp(text, maxWidth: 8, maxHeight: 2))
    }

    // MARK: - Truncation extension

    @Test func truncatedToVisibleWidth() {
        #expect("Hello, World!".truncated(toVisibleWidth: 5) == truncateToVisibleWidth("Hello, World!", maxWidth: 5))
    }

    // MARK: - Utility extensions

    @Test func tabsExpandedDefault() {
        #expect("\tHello".tabsExpanded() == expandTabs("\tHello"))
    }

    @Test func tabsExpandedCustomWidth() {
        #expect("\tHello".tabsExpanded(tabWidth: 8) == expandTabs("\tHello", tabWidth: 8))
    }

    @Test func inlinedExtractsFirstLine() {
        #expect("Hello\nWorld".inlined() == inline("Hello\nWorld"))
    }

    // MARK: - Realistic chaining examples

    @Test func styledPanelChain() {
        // A typical panel: content → pad → border → margin
        let panel = "Status: OK"
            .padded(0, 2)
            .bordered(.rounded)
            .margined(left: 2)

        let lines = panel.components(separatedBy: "\n")
        #expect(lines[0] == "  ╭──────────────╮")
        #expect(lines[1] == "  │  Status: OK  │")
        #expect(lines[2] == "  ╰──────────────╯")
    }

    @Test func constrainedBoxChain() {
        // Enforce minimum, then clamp maximum
        let result = "Hi"
            .enforced(width: 10)
            .clamped(width: 8)

        #expect(visibleWidth(of: result) == 8)
    }

    @Test func centeredPlacedChain() {
        let result = "Hello"
            .aligned(width: 11, .center)
            .padded(top: 1, bottom: 1)

        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[1] == "   Hello   ")
    }

    // MARK: - Fill character forwarding

    @Test func paddedWithCustomFill() {
        #expect("Hi".padded(left: 3, fill: ".") == pad("Hi", left: 3, fill: "."))
    }

    @Test func paddedAllSidesWithFill() {
        #expect("Hi".padded(1, fill: "·") == pad("Hi", 1, fill: "·"))
    }

    @Test func paddedVerticalHorizontalWithFill() {
        #expect("Hi".padded(0, 2, fill: "-") == pad("Hi", 0, 2, fill: "-"))
    }

    @Test func paddedTopSidesBottomWithFill() {
        #expect("Hi".padded(0, 2, 0, fill: ".") == pad("Hi", 0, 2, 0, fill: "."))
    }

    @Test func marginedWithCustomFill() {
        #expect("Hi".margined(left: 3, fill: ".") == margin("Hi", left: 3, fill: "."))
    }

    @Test func marginedAllSidesWithFill() {
        #expect("Hi".margined(1, fill: "·") == margin("Hi", 1, fill: "·"))
    }

    @Test func marginedVerticalHorizontalWithFill() {
        #expect("Hi".margined(0, 2, fill: "-") == margin("Hi", 0, 2, fill: "-"))
    }

    @Test func marginedTopSidesBottomWithFill() {
        #expect("Hi".margined(0, 2, 0, fill: ".") == margin("Hi", 0, 2, 0, fill: "."))
    }

    // MARK: - Wrapping extension

    @Test func wrappedMatchesFreeFunction() {
        let text = "Hello World this is a test"
        #expect(text.wrapped(width: 12) == wrap(text, width: 12))
    }

    @Test func wrappedWithCustomBreakCharacter() {
        let text = "one-two-three-four"
        #expect(text.wrapped(width: 10, breakCharacter: "-") == wrap(text, width: 10, breakCharacter: "-"))
    }

    // MARK: - Full pipeline with new features

    @Test func wrapThenPadWithFillThenBorder() {
        let result = "Hello World this is long"
            .wrapped(width: 12)
            .padded(0, 1, fill: " ")
            .bordered(.rounded)

        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 4) // border top + 2 wrapped lines + border bottom
    }
}
