import Testing
@testable import Latte

// MARK: - Helpers

/// Strips ANSI escape sequences from a string, returning only the visible characters.
private func stripANSI(_ s: String) -> String {
    var result = ""
    var iter = s.unicodeScalars.makeIterator()
    while let scalar = iter.next() {
        guard scalar.value != 0x1B else {
            // Consume the rest of the escape sequence.
            guard let next = iter.next() else { break }
            switch next {
            case "[":
                // CSI: skip until final byte in @–~ (0x40–0x7E)
                while let c = iter.next() {
                    if c.value >= 0x40 && c.value <= 0x7E { break }
                }
            case "]":
                // OSC: skip until BEL (0x07) or ST (ESC \)
                while let c = iter.next() {
                    if c.value == 0x07 { break }
                    if c.value == 0x1B { _ = iter.next(); break }
                }
            default:
                break // Two-byte sequence; second byte already consumed
            }
            continue
        }
        result.unicodeScalars.append(scalar)
    }
    return result
}

// MARK: - Tests

@Suite("Compositor")
struct CompositorTests {

    // -------------------------------------------------------------------------
    // 8.1 — Basic construction
    // -------------------------------------------------------------------------

    @Test func emptyCompositorRendersSpaces() {
        let comp = Compositor(width: 3, height: 2)
        let result = comp.render()
        let lines = result.components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "   ")
        #expect(lines[1] == "   ")
    }

    @Test func singleLayerNoOffset() {
        var comp = Compositor(width: 5, height: 1)
        comp.add(Layer(content: "Hello", x: 0, y: 0))
        let visible = stripANSI(comp.render())
        #expect(visible == "Hello")
    }

    @Test func singleLayerWithHorizontalOffset() {
        var comp = Compositor(width: 8, height: 1)
        comp.add(Layer(content: "Hi", x: 3, y: 0))
        let visible = stripANSI(comp.render())
        //  Cols: 0  1  2  3  4  5  6  7
        //        _  _  _  H  i  _  _  _
        #expect(visible == "   Hi   ")
    }

    @Test func singleLayerWithVerticalOffset() {
        var comp = Compositor(width: 3, height: 3)
        comp.add(Layer(content: "AB", x: 0, y: 1))
        let lines = stripANSI(comp.render()).components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0] == "   ")
        #expect(lines[1].hasPrefix("AB"))
        #expect(lines[2] == "   ")
    }

    // -------------------------------------------------------------------------
    // 8.1 — Z-ordering / occlusion
    // -------------------------------------------------------------------------

    @Test func twoLayersCorrectOcclusion() {
        // Layer 0 (z=0): "AAAAAAAAAA" fills all 10 cols
        // Layer 1 (z=1): "BBB"        overwrites cols 3–5
        var comp = Compositor(width: 10, height: 1)
        comp.add(Layer(content: "AAAAAAAAAA", x: 0, y: 0, z: 0))
        comp.add(Layer(content: "BBB",        x: 3, y: 0, z: 1))

        let chars = Array(stripANSI(comp.render()).components(separatedBy: "\n")[0])
        #expect(chars[0] == "A")
        #expect(chars[1] == "A")
        #expect(chars[2] == "A")
        #expect(chars[3] == "B")
        #expect(chars[4] == "B")
        #expect(chars[5] == "B")
        #expect(chars[6] == "A")
        #expect(chars[7] == "A")
        #expect(chars[8] == "A")
        #expect(chars[9] == "A")
    }

    @Test func lowerZLayerDoesNotOccludeHigherZ() {
        // Adding layers in reverse z order should still render higher z on top.
        var comp = Compositor(width: 5, height: 1)
        comp.add(Layer(content: "BBBBB", x: 0, y: 0, z: 1))  // added first
        comp.add(Layer(content: "AAAAA", x: 0, y: 0, z: 0))  // added second but lower z

        let visible = stripANSI(comp.render())
        // Higher z (B) should win everywhere
        #expect(visible == "BBBBB")
    }

    // -------------------------------------------------------------------------
    // 8.1 — Space transparency
    // -------------------------------------------------------------------------

    @Test func spaceInUpperLayerIsTransparent() {
        // Layer 0 (z=0): "AAAAA"   → A at every column
        // Layer 1 (z=1): "B B B"   → B at 0, 2, 4; space at 1, 3 (transparent)
        var comp = Compositor(width: 5, height: 1)
        comp.add(Layer(content: "AAAAA", x: 0, y: 0, z: 0))
        comp.add(Layer(content: "B B B", x: 0, y: 0, z: 1))

        let chars = Array(stripANSI(comp.render()).components(separatedBy: "\n")[0])
        #expect(chars[0] == "B")
        #expect(chars[1] == "A")   // transparent space → lower layer shows through
        #expect(chars[2] == "B")
        #expect(chars[3] == "A")   // transparent space → lower layer shows through
        #expect(chars[4] == "B")
    }

    @Test func spaceInLowestLayerIsNotTransparent() {
        // The lowest layer's spaces write to previously-empty cells (there is
        // no lower content to preserve, so they are rendered as spaces).
        var comp = Compositor(width: 3, height: 1)
        comp.add(Layer(content: "A B", x: 0, y: 0, z: 0))

        let chars = Array(stripANSI(comp.render()).components(separatedBy: "\n")[0])
        #expect(chars[0] == "A")
        #expect(chars[1] == " ")   // space from lowest layer = plain space in output
        #expect(chars[2] == "B")
    }

    // -------------------------------------------------------------------------
    // 8.1 — Clipping
    // -------------------------------------------------------------------------

    @Test func contentClippedHorizontally() {
        var comp = Compositor(width: 5, height: 1)
        comp.add(Layer(content: "Hello World", x: 0, y: 0))

        let visible = stripANSI(comp.render()).components(separatedBy: "\n")[0]
        // "Hello" fits; " World" is clipped
        #expect(visible.count == 5)
        #expect(visible == "Hello")
    }

    @Test func contentClippedVertically() {
        var comp = Compositor(width: 5, height: 2)
        comp.add(Layer(content: "A\nB\nC", x: 0, y: 0))   // row 2 is clipped

        let lines = stripANSI(comp.render()).components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("A"))
        #expect(lines[1].hasPrefix("B"))
    }

    @Test func layerOffsetPartiallyOutsideBoundsIsClipped() {
        // Layer starts at row -1; its second row (row 0) is within bounds.
        var comp = Compositor(width: 5, height: 2)
        comp.add(Layer(content: "AB\nCD", x: 0, y: -1))

        let lines = stripANSI(comp.render()).components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0].hasPrefix("CD"))   // row -1 clipped; row 0 = "CD"
        #expect(lines[1] == "     ")        // no content in row 1
    }

    @Test func layerEntirelyOutsideBoundsIsIgnored() {
        var comp = Compositor(width: 3, height: 2)
        comp.add(Layer(content: "XY", x: 0, y: 5))   // row 5 is outside height=2

        let lines = stripANSI(comp.render()).components(separatedBy: "\n")
        #expect(lines.count == 2)
        #expect(lines[0] == "   ")
        #expect(lines[1] == "   ")
    }

    @Test func outputDimensionsAreAlwaysWidthTimesHeight() {
        // Even with a layer that overflows in all directions, the output must
        // have exactly `height` rows, each `width` visible columns wide.
        var comp = Compositor(width: 4, height: 3)
        comp.add(Layer(content: "XXXXXXXXXX", x: -2, y: -1))

        let output = stripANSI(comp.render())
        let lines = output.components(separatedBy: "\n")
        #expect(lines.count == 3)
        for line in lines {
            #expect(line.count == 4)
        }
    }

    // -------------------------------------------------------------------------
    // 8.1 — ANSI preservation
    // -------------------------------------------------------------------------

    @Test func ansiSequencesArePreservedInOutput() {
        var comp = Compositor(width: 5, height: 1)
        let redHello = "\u{1B}[31mHello\u{1B}[m"
        comp.add(Layer(content: redHello, x: 0, y: 0))

        let result = comp.render()
        // The SGR code must appear in the raw output...
        #expect(result.contains("\u{1B}[31m"))
        // ...and the visible text must be correct.
        #expect(stripANSI(result) == "Hello")
    }

    @Test func ansiSequencesDoNotCorruptColumnTracking() {
        // An ANSI-styled 3-char prefix followed by a plain 2-char suffix.
        // The compositor must track visible columns correctly despite the ESC bytes.
        var comp = Compositor(width: 5, height: 1)
        let styled = "\u{1B}[32mABC\u{1B}[m"   // green "ABC" (3 visible cols)
        comp.add(Layer(content: styled, x: 0, y: 0, z: 0))
        comp.add(Layer(content: "XY",  x: 3, y: 0, z: 1))

        let visible = stripANSI(comp.render()).components(separatedBy: "\n")[0]
        let chars = Array(visible)
        // Cols 0–2: A B C (from styled lower layer)
        // Cols 3–4: X Y  (from upper layer — must land at the correct columns)
        #expect(chars[0] == "A")
        #expect(chars[1] == "B")
        #expect(chars[2] == "C")
        #expect(chars[3] == "X")
        #expect(chars[4] == "Y")
    }

    @Test func ansiStyleDoesNotBleedToNeighbouringCells() {
        // A red 'A' followed by a plain 'B'; 'B' must NOT be rendered in red.
        var comp = Compositor(width: 2, height: 1)
        comp.add(Layer(content: "\u{1B}[31mA", x: 0, y: 0, z: 0))
        comp.add(Layer(content: "B",            x: 1, y: 0, z: 1))

        let result = comp.render()
        // The reset sequence must appear between the red 'A' and the plain 'B'.
        #expect(result.contains("\u{1B}[m"))
        // Visible characters must still be A and B.
        #expect(stripANSI(result) == "AB")
    }

    // -------------------------------------------------------------------------
    // SGR span persistence — all characters in a styled span must be styled

    // A styled span produced by Style.render("Hello") looks like ESC[1mHello ESC[0m.
    // Previously only 'H' received the SGR prefix because pendingANSI was cleared
    // after the first character.  All five characters must now carry the bold prefix.
    @Test func sgrSpanStylesAllCharactersInTheSpan() {
        var comp = Compositor(width: 5, height: 1)
        let boldHello = "\u{1B}[1mHello\u{1B}[0m"
        comp.add(Layer(content: boldHello, x: 0, y: 0))

        let result = comp.render()
        // Every cell must carry the bold prefix exactly once.
        let boldOccurrences = result.components(separatedBy: "\u{1B}[1m").count - 1
        #expect(boldOccurrences == 5)   // H, e, l, l, o each get ESC[1m
        #expect(stripANSI(result) == "Hello")
    }

    // A multi-colour span: ESC[31mAB ESC[32mCD.  After the colour switch each
    // cell must use the colour active when it was parsed.
    @Test func sgrStateUpdatesCorrectlyMidSpan() {
        var comp = Compositor(width: 4, height: 1)
        let multiColor = "\u{1B}[31mAB\u{1B}[32mCD"
        comp.add(Layer(content: multiColor, x: 0, y: 0))

        let result = comp.render()
        #expect(result.contains("\u{1B}[31m"))  // red used for A and B
        #expect(result.contains("\u{1B}[32m"))  // green used for C and D
        #expect(stripANSI(result) == "ABCD")
    }

    // A SGR reset mid-span clears the active style so subsequent characters
    // receive no SGR prefix.
    @Test func sgrResetClearsActiveStyleForSubsequentChars() {
        var comp = Compositor(width: 4, height: 1)
        let span = "\u{1B}[1mAB\u{1B}[0mCD"   // bold AB, then reset, then plain CD
        comp.add(Layer(content: span, x: 0, y: 0))

        let result = comp.render()
        // Bold SGR must appear exactly twice: once for A, once for B.
        let boldOccurrences = result.components(separatedBy: "\u{1B}[1m").count - 1
        #expect(boldOccurrences == 2)
        #expect(stripANSI(result) == "ABCD")
    }

    // C12 — ESC[m (no params) must also clear the active SGR state, not just ESC[0m.
    @Test func sgrNoParamResetAlsoClearsActiveStyle() {
        var comp = Compositor(width: 4, height: 1)
        // Bold AB, then ESC[m (bare reset, no "0" param), then plain CD.
        let span = "\u{1B}[1mAB\u{1B}[mCD"
        comp.add(Layer(content: span, x: 0, y: 0))

        let result = comp.render()
        // Bold must appear for A and B only (exactly twice).
        let boldOccurrences = result.components(separatedBy: "\u{1B}[1m").count - 1
        #expect(boldOccurrences == 2)
        #expect(stripANSI(result) == "ABCD")
    }

    // C12 — Compound reset ESC[0;1m clears prior styles before applying bold.
    @Test func sgrCompoundResetClearsAndAppliesNewStyle() {
        var comp = Compositor(width: 3, height: 1)
        // Red A, then compound reset+bold for B, then C inherits bold.
        let span = "\u{1B}[31mA\u{1B}[0;1mBC"
        comp.add(Layer(content: span, x: 0, y: 0))

        let result = comp.render()
        // ESC[31m (red) must appear once (for A); ESC[0;1m must appear for B and C.
        let redOccurrences  = result.components(separatedBy: "\u{1B}[31m").count - 1
        let compOccurrences = result.components(separatedBy: "\u{1B}[0;1m").count - 1
        #expect(redOccurrences  == 1)   // only A is red
        #expect(compOccurrences == 2)   // B and C each get the compound prefix
        #expect(stripANSI(result) == "ABC")
    }

    // C13 — Zero-width characters must not advance the column counter.
    //
    // U+200B (ZERO WIDTH SPACE) is always its own grapheme cluster in Swift and
    // has `displayWidth == 0`.  It must be appended to the preceding cell without
    // consuming a column, so that 'B' still lands at column 1 in a width-2 grid.
    @Test func zeroWidthCharDoesNotAdvanceColumn() {
        var comp = Compositor(width: 2, height: 1)
        // "A" + U+200B (zero-width space) + "B":  visible width = 2.
        let content = "A\u{200B}B"
        comp.add(Layer(content: content, x: 0, y: 0))

        let result = comp.render()
        #expect(result.components(separatedBy: "\n").count == 1)
        let visible = stripANSI(result)
        // 'B' must appear (it was not pushed out of bounds by the zero-width char).
        #expect(visible.contains("B"))
        // The rendered row must be exactly 2 visible columns wide.
        #expect(visibleWidth(of: visible) == 2)
    }

    // -------------------------------------------------------------------------
    // 8.1 — Multi-line layers
    // -------------------------------------------------------------------------

    @Test func multiLineLayerRendersCorrectly() {
        var comp = Compositor(width: 4, height: 3)
        comp.add(Layer(content: "AB\nCD\nEF", x: 0, y: 0))

        let lines = stripANSI(comp.render()).components(separatedBy: "\n")
        #expect(lines.count == 3)
        #expect(lines[0].hasPrefix("AB"))
        #expect(lines[1].hasPrefix("CD"))
        #expect(lines[2].hasPrefix("EF"))
    }

    // MARK: - Wide character split-glyph normalization

    // If a higher-z layer writes into the *continuation* cell of an existing wide
    // glyph, the leading cell must be cleared so the renderer doesn't emit the
    // wide glyph AND the new character at the same terminal columns.
    @Test func overwritingContinuationCellClearsLeadingCell() {
        // Layer 0 (z=0): "A汉B"  → A at col0, 汉 at col1 (leading) + col2 (cont), B at col3
        // Layer 1 (z=1): "X" at col 2  — writes into the continuation of 汉
        var comp = Compositor(width: 4, height: 1)
        comp.add(Layer(content: "A汉B", x: 0, y: 0, z: 0))
        comp.add(Layer(content: "X",   x: 2, y: 0, z: 1))

        let visible = stripANSI(comp.render()).components(separatedBy: "\n")[0]
        let chars = Array(visible)
        // Expected: A(col0) space(col1, cleared leading) X(col2) B(col3)
        #expect(chars.count == 4)
        #expect(chars[0] == "A")
        #expect(chars[1] == " ")  // leading cell of 汉 was cleared
        #expect(chars[2] == "X")
        #expect(chars[3] == "B")
    }

    // If a higher-z layer writes into the *leading* cell of an existing wide
    // glyph, the continuation cell must be cleared so it doesn't leave an
    // invisible hole that makes the row appear 1 column short.
    @Test func overwritingLeadingCellClearsContinuationCell() {
        // Layer 0 (z=0): "A汉B"  → A at col0, 汉 at col1 (leading) + col2 (cont), B at col3
        // Layer 1 (z=1): "X" at col 1  — overwrites the leading cell of 汉
        var comp = Compositor(width: 4, height: 1)
        comp.add(Layer(content: "A汉B", x: 0, y: 0, z: 0))
        comp.add(Layer(content: "X",   x: 1, y: 0, z: 1))

        let visible = stripANSI(comp.render()).components(separatedBy: "\n")[0]
        let chars = Array(visible)
        // Expected: A(col0) X(col1) space(col2, cleared continuation) B(col3)
        #expect(chars.count == 4)
        #expect(chars[0] == "A")
        #expect(chars[1] == "X")
        #expect(chars[2] == " ")  // continuation of 汉 was cleared
        #expect(chars[3] == "B")
    }

    // A double-wide character placed at the last column must be clipped (not written)
    // so the rendered row stays exactly `width` visible columns wide.
    @Test func wideCharAtLastColumnIsClipped() {
        var comp = Compositor(width: 3, height: 1)
        // "A汉" — 'A' is 1 col, '汉' is 2 cols; with width=3, '汉' starts at col 1
        // but needs col 2 as well.  That fits (cols 1 and 2).
        comp.add(Layer(content: "A汉", x: 0, y: 0))
        let fit = stripANSI(comp.render()).components(separatedBy: "\n")[0]
        #expect(fit == "A汉")   // 1 + 2 = 3 cols — fits exactly

        // Now place '汉' at the *last* column (col 2) so col 3 would be needed.
        var comp2 = Compositor(width: 3, height: 1)
        comp2.add(Layer(content: "AB汉", x: 0, y: 0))  // A=col0, B=col1, 汉 would need col2+col3
        let clipped = stripANSI(comp2.render()).components(separatedBy: "\n")[0]
        // '汉' must be clipped; the last column stays as a plain space.
        #expect(clipped.count == 3)   // visible width still exactly 3 (A, B, space)
        #expect(clipped.hasPrefix("AB"))
        #expect(!clipped.contains("汉"))
    }

    @Test func overlappingMultiLineLayers() {
        //  Layer 0 (z=0): 3×3 grid of A
        //  Layer 1 (z=1): "XY" placed at (1, 1)
        var comp = Compositor(width: 3, height: 3)
        comp.add(Layer(content: "AAA\nAAA\nAAA", x: 0, y: 0, z: 0))
        comp.add(Layer(content: "XY",             x: 1, y: 1, z: 1))

        let lines = stripANSI(comp.render()).components(separatedBy: "\n")
        #expect(lines[0] == "AAA")
        let mid = Array(lines[1])
        #expect(mid[0] == "A")
        #expect(mid[1] == "X")
        #expect(mid[2] == "Y")
        #expect(lines[2] == "AAA")
    }
}
