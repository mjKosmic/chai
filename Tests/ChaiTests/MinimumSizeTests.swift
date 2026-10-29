import Testing
@testable import Chai

// MARK: - `AvailableSize.zero` and minimum semantics
//
// SwiftUI's `ProposedViewSize` has three special cases: `unspecified` (ideal),
// `zero` (minimum), and `infinity` (maximum). Chai spells them
// `.unconstrained` (ideal) and `.zero` (minimum) and deliberately omits the
// third (ARCHITECTURE.md, "Why there is no `.infinity`").
//
// `.zero` is a query, not a bound (like every query context): a view reports its
// minimum and the answer is never clamped. Most views answer their minimum
// *by construction*:
//
// - `ViewOutput` is a fully-formed raster → it answers its ideal size (and may
//   legitimately exceed the zero query — a legal overrule).
// - Fixed `Spacer(lines:)`/`Spacer(columns:)` → their rigid size; flexible
//   `Spacer()`/`Empty` → 0×0; `Fill` → the queried rect, i.e. (0, 0) at
//   `.zero`.
// - Containers follow their normal allocation rules — no special-casing.
//
// `Text` is the ONE compressible view: at a zero (or negative — clamped to
// zero, one rule) width query it reports/paints its narrowest producible
// form, wrapping at the widest single character in the content (1 for
// ASCII-only, 2 if any wide/CJK character is present, at least 1 for non-empty
// content). This is the minimum form for every non-positive width query (see
// the re-pinned tests in `TextWrappingTests` and `LayoutEngineTests`).
//
// Every expectation below was derived by running the code — never
// hand-computed.

// MARK: - The value

@Suite("AvailableSize.zero")
struct MinimumSizeTests {

    @Test func zeroIsZeroOnBothAxes() {
        #expect(AvailableSize.zero == AvailableSize(width: 0, height: 0))
        #expect(AvailableSize.zero.width == 0)
        #expect(AvailableSize.zero.height == 0)
    }

    @Test func zeroIsDistinctFromUnconstrained() {
        // `.zero` is the minimum query; `.unconstrained` is the ideal query (no context).
        #expect(AvailableSize.zero != .unconstrained)
        #expect(AvailableSize.zero != AvailableSize())
    }
}

// MARK: - Shared helpers

/// Visible rows using the parity convention: zero-width cells (wide-char
/// continuations) skipped, wide primaries counted once, trailing spaces
/// stripped.
private func zeroVisibleRows(_ buffer: CellBuffer) -> [String] {
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

/// Measure `view` at `available`, embed it at its measured rect into a buffer
/// of `width`×`height`, and return the visible rows.
private func zeroEngineRows(
    _ view: some View,
    available: AvailableSize,
    width: Int,
    height: Int
) -> [String] {
    let size = view._measure(in: available)
    var buffer = CellBuffer(width: width, height: height)
    view._embed(into: &buffer, at: ViewRect(size: size))
    return zeroVisibleRows(buffer)
}

// MARK: - Text: the only compressible view

@Suite("Text minimum semantics")
struct TextMinimumSemanticsTests {

    @Test func asciiContentWrapsToOneColumn() {
        // "hello world" at the minimum width 1: the space at the break is
        // consumed, so 10 rows (not 11) — widest line 1.
        #expect(Text("hello world")._measure(in: .zero) == ViewSize(width: 1, height: 10))
    }

    @Test func cjkContentWrapsToTwoColumns() {
        // The widest single character is a wide (2-column) CJK character, so
        // the minimum width is 2; each character gets its own row.
        #expect(Text("你好")._measure(in: .zero) == ViewSize(width: 2, height: 2))
    }

    @Test func mixedContentUsesTheWidestCharacter() {
        // "ab你好cd" at minimum width 2: "ab" / "你" / "好" / "cd" (the CJK
        // units break char-by-char; ASCII runs greedily fill the 2 columns).
        #expect(Text("ab你好cd")._measure(in: .zero) == ViewSize(width: 2, height: 4))
    }

    @Test func emptyContentStaysZeroByZero() {
        #expect(Text("")._measure(in: .zero) == .zero)
    }

    @Test func whitespaceOnlyContentStaysZeroByZero() {
        // Non-empty, so the minimum width is 1 — but whitespace-only content
        // wraps to empty under the pinned wrapping contract → 0×0.
        #expect(Text("   ")._measure(in: .zero) == .zero)
    }

    @Test func hardNewlinesAreHonoredAtTheMinimum() {
        // "a\n\nb" at minimum width 1 keeps all three lines (a hard `\n` is
        // always honored), widest line 1.
        #expect(Text("a\n\nb")._measure(in: .zero) == ViewSize(width: 1, height: 3))
    }

    @Test func zeroWidthQueryUsesMinimumSemantics() {
        // A zero *width* query (height irrelevant) is the minimum context.
        #expect(Text("hi")._measure(in: AvailableSize(width: 0, height: 0)) == ViewSize(width: 1, height: 2))
        #expect(Text("hi")._measure(in: AvailableSize(width: 0, height: nil)) == ViewSize(width: 1, height: 2))
    }

    @Test func negativeWidthQueryClampsToMinimum() {
        // A negative query is clamped to zero — one rule, same result.
        #expect(Text("hi")._measure(in: AvailableSize(width: -3, height: nil)) == ViewSize(width: 1, height: 2))
    }

    @Test func unconstrainedWidthStillMeasuresTheUnwrappedIdeal() {
        // `nil` is ideal, not minimum: the content is not compressed.
        #expect(Text("hello world")._measure(in: .unconstrained) == ViewSize(width: 11, height: 1))
    }

    @Test func positiveWidthQueryStillWrapsToThatWidth() {
        // Minimum semantics do not disturb the positive-width path.
        #expect(Text("abcdefgh")._measure(in: AvailableSize(width: 5, height: nil)) == ViewSize(width: 5, height: 2))
    }

    @Test func styledContentCompressesAndPreservesStyle() {
        let view = Text("The quick".fg(.red))
        // 8 rows (the space at the break is consumed), widest line 1.
        #expect(view._measure(in: .zero) == ViewSize(width: 1, height: 8))

        // The minimum render keeps the style on every character.
        let size = view._measure(in: .zero)
        var buffer = CellBuffer(width: 1, height: 8)
        view._embed(into: &buffer, at: ViewRect(size: size))
        #expect(buffer[0, 0].character == "T")
        #expect(buffer[0, 0].foreground == .red)
        #expect(buffer[0, 7].character == "k")
        #expect(buffer[0, 7].foreground == .red)
    }

    @Test func renderWritesTheMinimumForm() {
        // The render pass writes the SAME minimum form the fit pass measured:
        // four 1-column rows.
        #expect(
            zeroEngineRows(Text("abcd"), available: .zero, width: 1, height: 4)
                == ["a", "b", "c", "d"]
        )
    }

    @Test func renderWritesTheMinimumFormForCjk() {
        // Two 2-column rows, wide-char continuation cells skipped by extraction.
        #expect(
            zeroEngineRows(Text("你好"), available: .zero, width: 2, height: 2)
                == ["你", "好"]
        )
    }
}

// MARK: - Non-compressible views answer their minimum by construction

@Suite("Minimum semantics — non-compressible leaves")
struct MinimumNonCompressibleTests {

    @Test func viewOutputOverrulesTheZeroQuery() {
        // A `ViewOutput` is a fully-formed raster: it ignores the query context and
        // answers its ideal size — here 4 columns, wider than the zero query.
        // This is legal (a report is never clamped).
        #expect(ViewOutput("abcd")._measure(in: .zero) == ViewSize(width: 4, height: 1))
    }

    @Test func spacersAnswerTheirRigidSize() {
        #expect(Spacer(lines: 2)._measure(in: .zero) == ViewSize(width: 0, height: 2))
        #expect(Spacer(columns: 3)._measure(in: .zero) == ViewSize(width: 3, height: 1))
        #expect(Spacer(lines: 1)._measure(in: .zero) == ViewSize(width: 0, height: 1))
    }

    @Test func zeroSizedViewsAnswerZero() {
        #expect(Spacer()._measure(in: .zero) == .zero)
        #expect(Empty()._measure(in: .zero) == .zero)
    }

    @Test func fillAnswersTheZeroQuery() {
        // `Fill` answers the query verbatim: at `.zero` that is (0, 0).
        #expect(Fill()._measure(in: .zero) == .zero)
    }
}

// MARK: - Containers follow their normal allocation rules at `.zero`

@Suite("Minimum semantics — containers")
struct MinimumContainerTests {

    @Test func vstackComposesTrueMinimums() {
        // VStack queries each child with `(width: 0, height: nil)`, so both
        // Text children compress: (1, 3) and (1, 2) → max width 1, Σ heights 5.
        let stack = VStack {
            Text("abc")
            Text("de")
        }
        #expect(stack._measure(in: .zero) == ViewSize(width: 1, height: 5))
        #expect(zeroEngineRows(stack, available: .zero, width: 1, height: 5) == ["a", "b", "c", "d", "e"])
    }

    @Test func vstackMinimumUsesTheWidestChildMinimum() {
        // A CJK child raises the composed minimum width to 2.
        let stack = VStack {
            Text("abc")
            Text("你好")
        }
        // "abc" → (1, 3); "你好" → (2, 2) → width 2, height 5.
        #expect(stack._measure(in: .zero) == ViewSize(width: 2, height: 5))
    }

    @Test func hstackAtZeroYieldsIdealWidthNotMinimum() {
        // DOCUMENTED CONSEQUENCE (not a bug): HStack queries its children with `(nil, 0)`
        // children — it measures columns at *ideal* width — so a Text child
        // answers its unwrapped ideal, not its minimum. At `.zero` the stack
        // therefore measures the sum of the children's ideal widths.
        let stack = HStack {
            Text("ab")
            Text("cd")
        }
        #expect(stack._measure(in: .zero) == ViewSize(width: 4, height: 1))
        #expect(zeroEngineRows(stack, available: .zero, width: 4, height: 1) == ["abcd"])
    }

    @Test func hstackAtZeroKeepsLongTextAtIdealWidth() {
        // The long Text is NOT compressed to 1 column: it answers its ideal 11
        // columns ("hello world"), so the stack is 12 wide.
        let stack = HStack {
            Text("hello world")
            Text("x")
        }
        #expect(stack._measure(in: .zero) == ViewSize(width: 12, height: 1))
    }
}

// MARK: - FrameView at `.zero`

@Suite("Minimum semantics — frame at zero")
struct MinimumFrameTests {

    @Test func fixedDimensionsAnswerFixed() {
        // Both axes fixed: the frame answers them verbatim regardless of the
        // zero query.
        #expect(Text("ab").frame(width: 6, height: 3)._measure(in: .zero) == ViewSize(width: 6, height: 3))
    }

    @Test func fullyFlexibleFrameFillsTheZeroQuery() {
        // Both axes flexible: the frame fills the (non-`nil`) zero assignment on
        // each axis, so it answers 0×0.
        #expect(Text("ab").frame()._measure(in: .zero) == ViewSize(width: 0, height: 0))
    }

    @Test func fixedWidthFlexibleHeightForwardsZeroToChildAndFillsIt() {
        // Fixed width answers 2; the flexible height fills the zero assignment
        // (height 0). The child query is `(2, 0)` — the fixed width with
        // the forwarded zero height.
        #expect(Text("abcd").frame(width: 2)._measure(in: .zero) == ViewSize(width: 2, height: 0))
    }
}
