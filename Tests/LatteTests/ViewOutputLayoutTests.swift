import Testing
import Chai
import Latte

// Phase 4 P4b retired the eager `ViewOutput` modifier family. What remains on
// `ViewOutput` are the two *raster* clamping helpers — operations on a
// fully-formed output, with no tree-based equivalent. Layout modifiers now
// live on `View` and are pinned by `ModifierWrapperTests` (padding/border),
// `FrameTests` (frame), and `ClipTests` (clip); the String-level helpers are
// pinned by `StringExtensionTests` and `PaddingTests`.

@Suite("ViewOutput raster helpers")
struct ViewOutputRasterHelperTests {

    @Test func clampedWidthTruncatesLongLines() {
        let view = ViewOutput("Hello, World!").clampedWidth(5)
        #expect(view.content.plainText == "Hello")
    }

    @Test func clampedWidthLeavesShortLinesAlone() {
        let view = ViewOutput("Hi").clampedWidth(10)
        #expect(view.content.plainText == "Hi")
    }

    @Test func clampedHeightDropsExtraLines() {
        let view = ViewOutput("A\nB\nC\nD").clampedHeight(2)
        #expect(view.content.plainText == "A\nB")
    }

    @Test func clampedHeightLeavesFewLinesAlone() {
        let view = ViewOutput("A\nB").clampedHeight(5)
        #expect(view.content.plainText == "A\nB")
    }

    @Test func clampedWidthHandlesWideCharacters() {
        // "世界" = 4 columns; clamp to 3 must drop the second character without
        // splitting it.
        let view = ViewOutput("\u{4E16}\u{754C}").clampedWidth(3)
        #expect(view.content.plainText == "\u{4E16}")
    }

    @Test func clampedWidthOnMultiLineContent() {
        let view = ViewOutput("Hello, World!\nHi").clampedWidth(5)
        let lines = view.content.plainText.split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines[0] == "Hello")
        #expect(lines[1] == "Hi")
    }
}
