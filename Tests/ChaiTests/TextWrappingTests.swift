import Testing
@testable import Chai
import Latte

// MARK: - A1: word-aware wrapping `Text`
//
// Milestone A1 of the phase-3 Stage A SPI break: `Text` becomes the first
// production proposal consumer. A non-`nil`, positive width proposal wraps
// the content to that width (both measurement and rendering use the SAME
// `StyledText.wrappedToWidth(_:)` function, so the two passes agree by
// construction — the A0 fit/render value-equality contract).
//
// This suite pins the wrapping rules from UPGRADE.md ("Phase 3 — Stage A"):
//
// 1. Whitespace (space/tab) is a break opportunity; the whitespace at a break
//    is consumed; interior runs are preserved when no break happens there.
// 2. Breaking is allowed AFTER a hyphen (the hyphen stays on the first line).
// 3. Each CJK/wide character is its own break unit (CJK runs wrap char-by-char
//    in display-width units; a unit wider than the container is degenerate and
//    the buffer clips it).
// 4. A non-CJK word wider than the container breaks char-by-char (display-
//    width aware), only once it cannot fit even on an empty line.
// 5. Greedy accumulation into the current line; hard `\n` is always honored
//    and each hard line wraps independently.
// 6. Styles are preserved exactly via segment splitting; no invented/merged
//    styles.
// 7. Width ≤ 0 → unwrapped (both measure and render).
//
// The first block pins the shared wrapping function directly (exact, includes
// embedded newlines); the second block pins the `Text` wiring (measure +
// render) against the same function. Every expectation below was derived by
// running the code, never hand-computed (see the A1 report).

// MARK: - The pinned wrapping table

@Suite("Text Wrapping — pinned table")
struct TextWrappingTableTests {

    // MARK: Rule 1 — whitespace breaks (consumed at the break; interior preserved)

    @Test func breaksAtWhitespaceAndConsumesIt() {
        // 11 columns: "The quick" (9) + the space is the last break before
        // "brown" overflows → the space is consumed, not carried.
        #expect(StyledText("The quick brown fox").wrappedToWidth(11).plainText == "The quick\nbrown fox")
    }

    @Test func whitespaceRunAtBreakIsFullyConsumed() {
        // "a  b" at 2: the whole two-space run is the break point, so both
        // spaces vanish and "b" starts a fresh line.
        #expect(StyledText("a  b").wrappedToWidth(2).plainText == "a\nb")
    }

    @Test func interiorWhitespaceRunIsPreservedWhenNoBreakHappensThere() {
        // "a  b" at 10 fits on one line — the interior run is untouched.
        #expect(StyledText("a  b").wrappedToWidth(10).plainText == "a  b")
    }

    @Test func tabIsAZeroWidthBreakOpportunity() {
        // A tab is break whitespace with display width 0. "a\tb c" at 3:
        // "a\tb" fits (width 2), the space before "c" is the break point and
        // is consumed.
        #expect(StyledText("a\tb c").wrappedToWidth(3).plainText == "a\tb\nc")
    }

    // MARK: Rule 2 — hyphen breaks (after the hyphen, nothing inserted)

    @Test func breaksAfterHyphenKeepingTheHyphen() {
        #expect(StyledText("long-word").wrappedToWidth(5).plainText == "long-\nword")
    }

    @Test func hyphenStaysWhenTheWordFits() {
        #expect(StyledText("long-word").wrappedToWidth(9).plainText == "long-word")
    }

    // MARK: Rule 3 — CJK char-by-char units

    @Test func cjkRunWrapsCharByCharInWidthUnits() {
        // Four wide (2-column) characters at width 5: two per line.
        #expect(StyledText("你好世界").wrappedToWidth(5).plainText == "你好\n世界")
    }

    @Test func mixedCjkAndLatinBreaksAtTheCjkUnitBoundary() {
        // "ab你好cd" at 5: "ab你" = 1+1+2 = 4 columns; the next wide char
        // would overflow, and the CJK break opportunity after 你 is the last
        // one → "ab你" / "好cd" (2+1+1 = 4).
        #expect(StyledText("ab你好cd").wrappedToWidth(5).plainText == "ab你\n好cd")
    }

    // MARK: Rule 4 — char-level fallback for over-long non-CJK words

    @Test func overlongWordBreaksCharByChar() {
        // 20 characters at width 6 → greedy 6-column chunks, last one short.
        #expect(
            StyledText("supercalifragilistic").wrappedToWidth(6).plainText
                == "superc\nalifra\ngilist\nic"
        )
    }

    @Test func overlongWordAfterWhitespaceBreaksAtTheSpaceThenFallsBack() {
        // "ab supercalifragilistic" at 6: the first line takes "ab"; the
        // over-long word then cannot fit on the empty line, so it falls back
        // to char-level chunks.
        #expect(
            StyledText("ab supercalifragilistic").wrappedToWidth(6).plainText
                == "ab\nsuperc\nalifra\ngilist\nic"
        )
    }

    @Test func greedyAccumulationAsciiText() {
        // "The quick brown fox" at 3: each word alone overflows, so each is
        // char-split; the whitespace breaks are consumed.
        #expect(
            StyledText("The quick brown fox").wrappedToWidth(3).plainText
                == "The\nqui\nck\nbro\nwn\nfox"
        )
    }

    // MARK: Rule 5 — hard newlines

    @Test func hardNewlineAlwaysBreaksAndEachLineWrapsIndependently() {
        #expect(StyledText("ab\ncd ef").wrappedToWidth(3).plainText == "ab\ncd\nef")
    }

    @Test func interiorBlankHardLineIsPreserved() {
        // Rule 5: a hard `\n` is always honored, so an explicit blank line from
        // `\n\n` survives — matching the unwrapped `lineCount()` semantics.
        #expect(StyledText("a\n\nb").wrappedToWidth(5).plainText == "a\n\nb")
        #expect(StyledText("a\n\nb").wrappedToWidth(5).lineCount() == 3)
    }

    @Test func trailingHardNewlineIsPreserved() {
        // A trailing `\n` yields its (empty) second line, as before wrapping.
        #expect(StyledText("a\n").wrappedToWidth(5).plainText == "a\n")
        #expect(StyledText("a\n").wrappedToWidth(5).lineCount() == 2)
    }

    // MARK: Rule 6 — style preservation

    @Test func stylePreservedAcrossAWhitespaceBreak() {
        // "The" (red) + " quick" (plain) at 3 → "The" / "qui" / "ck".
        let wrapped = ("The".fg(.red) + " quick").wrappedToWidth(3)
        #expect(wrapped.plainText == "The\nqui\nck")
        #expect(wrapped.segments.count == 5)
        #expect(wrapped.segments[0].text == "The")
        #expect(wrapped.segments[0].style.foreground == .red)
        // The injected newline carries the default style — never the red.
        #expect(wrapped.segments[1].text == "\n")
        #expect(wrapped.segments[1].style.foreground == nil)
        #expect(wrapped.segments[2].text == "qui")
        #expect(wrapped.segments[2].style.foreground == nil)
        #expect(wrapped.segments[3].text == "\n")
        #expect(wrapped.segments[4].text == "ck")
        #expect(wrapped.segments[4].style.foreground == nil)
    }

    @Test func stylePreservedAcrossACharLevelBreak() {
        // A single red run split by the char-level fallback keeps red on BOTH
        // parts; the only non-red segments are the injected newlines.
        let wrapped = StyledText("abcdef", style: TextAttributes(foreground: .red)).wrappedToWidth(2)
        #expect(wrapped.plainText == "ab\ncd\nef")
        #expect(wrapped.segments.count == 5)
        for (index, segment) in wrapped.segments.enumerated() {
            if index % 2 == 0 {
                #expect(segment.style.foreground == .red)
            } else {
                #expect(segment.text == "\n")
                #expect(segment.style.foreground == nil)
            }
        }
    }

    @Test func noBreakLeavesStylesUntouched() {
        // "The" (red) + " quick" at 5 → "The" / "quick": no split of a styled
        // run, no invented style.
        let wrapped = ("The".fg(.red) + " quick").wrappedToWidth(5)
        #expect(wrapped.plainText == "The\nquick")
        #expect(wrapped.segments.count == 3)
        #expect(wrapped.segments[0].text == "The")
        #expect(wrapped.segments[0].style.foreground == .red)
        #expect(wrapped.segments[2].text == "quick")
        #expect(wrapped.segments[2].style.foreground == nil)
    }

    // MARK: Rule 7 — degenerate widths

    @Test func widthZeroIsUnwrapped() {
        #expect(StyledText("hello world").wrappedToWidth(0).plainText == "hello world")
    }

    @Test func negativeWidthIsUnwrapped() {
        #expect(StyledText("hello world").wrappedToWidth(-3).plainText == "hello world")
    }

    @Test func singleWideCharWiderThanTheContainerIsKeptDegenerate() {
        // A 2-column CJK character at width 1 cannot be split; it is kept on
        // its line and the buffer clips it (degenerate, rule 3).
        #expect(StyledText("你").wrappedToWidth(1).plainText == "你")
    }

    // MARK: Whitespace-only / empty content

    @Test func whitespaceOnlyContentWrapsToEmpty() {
        #expect(StyledText("   ").wrappedToWidth(5).plainText == "")
        #expect(StyledText("   ").wrappedToWidth(5).lineCount() == 0)
        #expect(StyledText("   ").wrappedToWidth(5).maxLineWidth == 0)
    }

    @Test func emptyContentWrapsToEmpty() {
        #expect(StyledText("").wrappedToWidth(5).plainText == "")
        #expect(StyledText("").wrappedToWidth(5).lineCount() == 0)
    }
}

// MARK: - `Text` wiring (production proposal consumer)

@Suite("Text Wrapping — Text integration")
struct TextWrappingIntegrationTests {

    /// Visible rows of a buffer (parity convention: zero-width cells skipped,
    /// trailing spaces stripped).
    private func visibleRows(_ buffer: CellBuffer) -> [String] {
        var rows: [String] = []
        for row in 0..<buffer.height {
            var line = ""
            for col in 0..<buffer.width {
                let cell = buffer[col, row]
                if cell.width == 0 { continue }
                line.append(cell.character)
            }
            while line.last == " " { line.removeLast() }
            rows.append(line)
        }
        return rows
    }

    /// Render `view` through the engine at `proposal`, returning the visible
    /// rows. The buffer width is the proposal width (so a wrapped line can
    /// never be a buffer artifact).
    private func engineRows(_ view: some View, proposal: ProposedSize) -> [String] {
        let size = view._sizeThatFits(proposal)
        var buffer = CellBuffer(width: proposal.width ?? size.width, height: size.height)
        view._render(into: &buffer, at: .zero, size: size, proposal: proposal)
        return visibleRows(buffer)
    }

    @Test func positiveWidthProposalMeasuresTheWrappedSize() {
        let proposal = ProposedSize(width: 11, height: nil)
        // "The quick" / "brown fox" → widest line 9, 2 lines.
        #expect(Text("The quick brown fox")._sizeThatFits(proposal) == ViewSize(width: 9, height: 2))
    }

    @Test func narrowerProposalWrapsToMoreLines() {
        // "The" / "qui" / "ck" / "bro" / "wn" / "fox" → 3×6.
        #expect(
            Text("The quick brown fox")._sizeThatFits(ProposedSize(width: 3, height: nil))
                == ViewSize(width: 3, height: 6)
        )
    }

    @Test func nilProposalMeasuresTheUnwrappedIdeal() {
        #expect(Text("The quick brown fox")._sizeThatFits(.unspecified) == ViewSize(width: 19, height: 1))
    }

    @Test func nonPositiveWidthProposalMeasuresTheUnwrappedIdeal() {
        #expect(
            Text("The quick brown fox")._sizeThatFits(ProposedSize(width: 0, height: nil))
                == ViewSize(width: 19, height: 1)
        )
    }

    @Test func wideEnoughProposalMeasuresTheUnwrappedIdeal() {
        #expect(
            Text("The quick brown fox")._sizeThatFits(ProposedSize(width: 40, height: nil))
                == ViewSize(width: 19, height: 1)
        )
    }

    @Test func whitespaceOnlyContentMeasuresZeroByZero() {
        #expect(Text("   ")._sizeThatFits(ProposedSize(width: 5, height: nil)) == .zero)
    }

    @Test func emptyContentMeasuresZeroByZero() {
        #expect(Text("")._sizeThatFits(ProposedSize(width: 5, height: nil)) == .zero)
    }

    @Test func blankHardLinesMeasureAsLines() {
        // A1 does not change blank-line semantics: `Text("a\n\nb")` keeps its
        // three lines under a width proposal (a hard `\n` is always honored).
        #expect(
            Text("a\n\nb")._sizeThatFits(ProposedSize(width: 5, height: nil))
                == ViewSize(width: 1, height: 3)
        )
    }

    @Test func renderWritesTheWrappedContentAtTheProposal() {
        // The fit proposal (5) and the render proposal are the SAME value: the
        // rendered rows are exactly the measured wrapped rows.
        let proposal = ProposedSize(width: 5, height: nil)
        #expect(engineRows(Text("abcdefgh"), proposal: proposal) == ["abcde", "fgh"])
    }

    @Test func renderAtZeroWidthWritesContentUnwrapped() {
        // Rule 7: a non-positive proposal renders the content unchanged — one
        // row, NOT the wrapped two rows. The buffer is 8-wide so nothing is
        // clipped; this pins "unwrapped", not "truncated".
        let proposal = ProposedSize(width: 0, height: nil)
        let size = Text("abcdefgh")._sizeThatFits(proposal)
        #expect(size == ViewSize(width: 8, height: 1))
        var buffer = CellBuffer(width: 8, height: 2)
        Text("abcdefgh")._render(into: &buffer, at: .zero, size: size, proposal: proposal)
        #expect(visibleRows(buffer) == ["abcdefgh", ""])
    }

    @Test func textMeasuresWrappedInsideAVStack() {
        let stack = VStack {
            Text("The quick brown fox")
            Text("jumps")
        }
        // First child wraps to 9×2; "jumps" is 5×1 → the stack is 9 wide, 3 tall.
        #expect(stack._sizeThatFits(ProposedSize(width: 11, height: nil)) == ViewSize(width: 9, height: 3))
    }

    @Test func textWrapsInsideAVStackAtRenderTime() {
        let stack = VStack {
            Text("The quick brown fox")
            Text("jumps")
        }
        // The stack forwards its incoming width proposal to each child, so the
        // render-time wrap matches the fit-time wrap (value-equality contract).
        #expect(
            engineRows(stack, proposal: ProposedSize(width: 11, height: nil))
                == ["The quick", "brown fox", "jumps"]
        )
    }
}
