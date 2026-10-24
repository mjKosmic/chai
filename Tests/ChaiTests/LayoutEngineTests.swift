import Testing
@testable import Chai
import Latte

// MARK: - M1 layout engine tests
//
// Milestone M1 of the phase-2 layout engine: the proposal-driven engine SPI
// (`_sizeThatFits` / `_embed(into:at:)` / `_childViews()`) with body-resolving
// defaults, leaf implementations (`ViewOutput`, `Spacer`), and the
// `maxLineWidth` move into Chai's `StyledText`.
//
// Expectations were derived by running the code — CJK widths, offset writes,
// and truncated rows are pinned from observed output, never hand-computed.

// MARK: - Layout types

@Suite("Layout Types")
struct LayoutTypesTests {

    @Test func proposedSizeMembers() {
        let proposal = ProposedSize(width: 3, height: nil)
        #expect(proposal.width == 3)
        #expect(proposal.height == nil)
    }

    @Test func proposedSizeDefaultIsUnspecified() {
        let defaultProposal = ProposedSize()
        #expect(defaultProposal == ProposedSize(width: nil, height: nil))
        #expect(ProposedSize.unspecified == defaultProposal)
    }

    @Test func proposedSizeEquatable() {
        let a = ProposedSize(width: 1, height: 2)
        let b = ProposedSize(width: 1, height: 2)
        let c = ProposedSize(width: 2, height: 1)
        #expect(a == b)
        #expect(a != c)
    }

    @Test func viewSizeMembersAndZero() {
        let size = ViewSize(width: 4, height: 3)
        #expect(size.width == 4)
        #expect(size.height == 3)
        #expect(ViewSize.zero == ViewSize(width: 0, height: 0))
    }

    @Test func viewOriginMembersAndZero() {
        let origin = ViewOrigin(col: 7, row: 2)
        #expect(origin.col == 7)
        #expect(origin.row == 2)
        #expect(ViewOrigin.zero == ViewOrigin(col: 0, row: 0))
    }
}

// MARK: - Leaf measurement

@Suite("Engine Measurement")
struct EngineMeasurementTests {

    /// A minimal custom view whose body is a `ViewOutput` leaf — exercises
    /// the body-resolving defaults of the engine SPI.
    private struct Label: View {
        let text: String
        var body: ViewOutput { ViewOutput(text) }
    }

    // MARK: ViewOutput

    @Test func viewOutputMeasuresIdealSizePlain() {
        #expect(ViewOutput("abc")._sizeThatFits(.unspecified) == ViewSize(width: 3, height: 1))
    }

    @Test func viewOutputMeasuresIdealSizeMultiline() {
        #expect(ViewOutput("a\nb")._sizeThatFits(.unspecified) == ViewSize(width: 1, height: 2))
        #expect(ViewOutput("a\nbb")._sizeThatFits(.unspecified) == ViewSize(width: 2, height: 2))
    }

    @Test func viewOutputMeasuresCjkWidth() {
        // "你好" occupies 4 display columns (2 per wide char), 1 line.
        #expect(ViewOutput("你好")._sizeThatFits(.unspecified) == ViewSize(width: 4, height: 1))
        // Multi-line with a CJK line: the widest line wins.
        #expect(ViewOutput("你好\nx")._sizeThatFits(.unspecified) == ViewSize(width: 4, height: 2))
    }

    @Test func viewOutputEmptyMeasuresZero() {
        #expect(ViewOutput("")._sizeThatFits(.unspecified) == .zero)
        #expect(ViewOutput(StyledText())._sizeThatFits(.unspecified) == .zero)
    }

    // MARK: Body-resolving defaults (Empty / custom views; Text is proposal-aware)

    @Test func textMeasuresIdealSizeAtUnspecifiedProposal() {
        #expect(Text("hi")._sizeThatFits(.unspecified) == ViewSize(width: 2, height: 1))
        #expect(Text("a\nb")._sizeThatFits(.unspecified) == ViewSize(width: 1, height: 2))
    }

    @Test func textMeasuresCjkIdealSizeAtUnspecifiedProposal() {
        #expect(Text("你好")._sizeThatFits(.unspecified) == ViewSize(width: 4, height: 1))
    }

    @Test func emptyMeasuresZeroThroughDefault() {
        #expect(Empty()._sizeThatFits(.unspecified) == .zero)
        #expect(Text("")._sizeThatFits(.unspecified) == .zero)
    }

    @Test func customViewMeasuresThroughBody() {
        #expect(Label(text: "xyz")._sizeThatFits(.unspecified) == ViewSize(width: 3, height: 1))
    }

    // MARK: Spacer

    @Test func spacerColumnsMeasure() {
        #expect(Spacer(columns: 5)._sizeThatFits(.unspecified) == ViewSize(width: 5, height: 1))
    }

    @Test func spacerLinesMeasure() {
        #expect(Spacer(lines: 2)._sizeThatFits(.unspecified) == ViewSize(width: 0, height: 2))
    }

    @Test func zeroArgSpacerIsFlexible() {
        // `Spacer()` is the flexible spacer: rigidly 0×0, with fraction 1 on
        // both axes (a stack distributes leftover into it).
        #expect(Spacer()._sizeThatFits(.unspecified) == .zero)
        #expect(Spacer()._flexibility() == LayoutFlexibility(width: 1, height: 1))
    }

    @Test func fixedSpacerMeasuresItsLineCount() {
        #expect(Spacer(lines: 1)._sizeThatFits(.unspecified) == ViewSize(width: 0, height: 1))
    }

    @Test func zeroSizedSpacerMeasuresZero() {
        #expect(Spacer(columns: 0)._sizeThatFits(.unspecified) == .zero)
    }

    // MARK: Non-wrapping leaves ignore proposals
    //
    // `ViewOutput` and `Spacer` are not proposal consumers. `Text` IS
    // (A1) — see `TextWrappingTests`; the probe below documents its minimum
    // semantics at a non-positive width (A3): it compresses to the narrowest
    // producible width (see `ProposedSizeZeroTests`).

    @Test func leavesIgnoreProposals() {
        // A `ViewOutput` is a fully-formed raster: proposals do not change
        // the ideal measurement.
        #expect(ViewOutput("abc")._sizeThatFits(ProposedSize(width: 1, height: 1)) == ViewSize(width: 3, height: 1))
        #expect(ViewOutput("abcd")._sizeThatFits(ProposedSize(width: 2, height: nil)) == ViewSize(width: 4, height: 1))
        // A non-positive width proposal is the MINIMUM offer for `Text` (A3):
        // "hi" compresses to width 1, one row per character.
        #expect(Text("hi")._sizeThatFits(ProposedSize(width: 0, height: 0)) == ViewSize(width: 1, height: 2))
        #expect(Spacer(columns: 5)._sizeThatFits(ProposedSize(width: 1, height: 1)) == ViewSize(width: 5, height: 1))
    }
}

// MARK: - Leaf render

@Suite("Allocation Render")
struct EngineRenderTests {

    /// Extract a row's visible text using the parity convention: zero-width
    /// cells (wide-char continuations) are skipped, wide primaries contribute
    /// their character once, and trailing spaces are stripped.
    private func rowText(_ buffer: CellBuffer, row: Int) -> String {
        var line = ""
        for col in 0..<buffer.width {
            let cell = buffer[col, row]
            if cell.width == 0 { continue }
            line.append(cell.character)
        }
        while line.last == " " { line.removeLast() }
        return line
    }

    @Test func viewOutputRendersAtZeroOrigin() {
        var buffer = CellBuffer(width: 10, height: 1)
        ViewOutput("Hello")._embed(into: &buffer, at: .zero)
        #expect(rowText(buffer, row: 0) == "Hello")
        #expect(buffer[0, 0].character == "H")
        #expect(buffer[4, 0].character == "o")
    }

    @Test func textRendersThroughOwnImplementation() {
        // `Text` has its own `_embed`; allocated 10 columns it writes the
        // content unwrapped (one row).
        var buffer = CellBuffer(width: 10, height: 1)
        Text("hi")._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 10, height: 1)))
        #expect(buffer[0, 0].character == "h")
        #expect(buffer[1, 0].character == "i")
        #expect(buffer[2, 0] == .empty)
    }

    @Test func multilineRendersAtColumnOffset() {
        // Exercises the `CellBuffer.write` fix: the `\n` resets to the
        // write's start column, so every line keeps the 2-column offset.
        var buffer = CellBuffer(width: 6, height: 2)
        ViewOutput("a\nb")._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: 2, row: 0), size: ViewSize(width: 2, height: 2))
        )
        #expect(buffer[2, 0].character == "a")
        #expect(buffer[2, 1].character == "b")
        #expect(buffer[0, 0] == .empty)
        #expect(buffer[0, 1] == .empty)
        // Leading spaces below are the offset — only trailing spaces strip.
        #expect(rowText(buffer, row: 0) == "  a")
        #expect(rowText(buffer, row: 1) == "  b")
    }

    @Test func cjkRendersAtColumnOffset() {
        var buffer = CellBuffer(width: 8, height: 2)
        ViewOutput("你\n好")._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: 2, row: 0), size: ViewSize(width: 4, height: 2))
        )
        // Row 0: two spaces then 你 (wide, with continuation at col 3).
        #expect(buffer[2, 0].character == "你")
        #expect(buffer[2, 0].width == 2)
        #expect(buffer[3, 0].width == 0)
        // Row 1: same offset for 好.
        #expect(buffer[2, 1].character == "好")
        #expect(buffer[2, 1].width == 2)
        #expect(buffer[3, 1].width == 0)
        #expect(rowText(buffer, row: 0) == "  你")
        #expect(rowText(buffer, row: 1) == "  好")
    }

    @Test func rendersTruncatedAtBufferWidth() {
        // Matching `wrapping: false`: a line wider than the buffer is
        // truncated at the right edge, not wrapped onto another row.
        var buffer = CellBuffer(width: 4, height: 1)
        ViewOutput("abcdef")._embed(into: &buffer, at: .zero)
        #expect(rowText(buffer, row: 0) == "abcd")
        #expect(buffer[3, 0].character == "d")
    }

    @Test func multilineAtOffsetTruncatesAtBufferWidth() {
        var buffer = CellBuffer(width: 4, height: 2)
        ViewOutput("abc\ndefgh")._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: 2, row: 0), size: ViewSize(width: 2, height: 2))
        )
        // "abc" at col 2: cols 0–1 empty, "ab" at 2–3, "c" truncated.
        #expect(rowText(buffer, row: 0) == "  ab")
        #expect(rowText(buffer, row: 1) == "  de")
    }

    @Test func spacerRenderIsNoOp() {
        // Blank cells are the buffer default — a spacer draws nothing, and
        // pre-existing cells are left untouched.
        var buffer = CellBuffer(width: 4, height: 1, fill: Cell(character: "x"))
        Spacer(columns: 4)._embed(into: &buffer, at: ViewRect(size: ViewSize(width: 4, height: 1)))
        #expect(rowText(buffer, row: 0) == "xxxx")
    }
}

// MARK: - Child view transparency

@Suite("Engine Child Views")
struct EngineChildViewsTests {

    /// A minimal custom view whose body is a `ViewOutput` leaf.
    private struct Label: View {
        let text: String
        var body: ViewOutput { ViewOutput(text) }
    }

    /// A composite view whose body is a `VStack` — an ordinary container,
    /// not a structural view, so it presents itself as a single child.
    private struct Nested: View {
        var body: some View {
            VStack {
                Text("a")
                Text("b")
            }
        }
    }

    /// Resolve each child view to its rendered plain text.
    private func resolvedTexts(_ views: [any View]) -> [String] {
        views.map { engineText($0) }
    }

    @Test func defaultChildViewsIsSelf() {
        #expect(Label(text: "z")._childViews().count == 1)
        #expect(resolvedTexts(Label(text: "z")._childViews()) == ["z"])
    }

    @Test func viewOutputDefaultChildViewsIsSelf() {
        #expect(ViewOutput("leaf")._childViews().count == 1)
        #expect(resolvedTexts(ViewOutput("leaf")._childViews()) == ["leaf"])
    }

    @Test func compositeViewPresentsItselfAsSingleChild() {
        // A `VStack` inside an ordinary view is a single child to an outer
        // container — it is not a structural view, so it is not flattened.
        #expect(Nested()._childViews().count == 1)
        #expect(resolvedTexts(Nested()._childViews()) == ["a\nb"])
    }

    @Test func tupleViewExposesOneViewPerChild() {
        let tuple = TupleView(Text("a"), Text("b"))
        #expect(tuple._childViews().count == 2)
        #expect(resolvedTexts(tuple._childViews()) == ["a", "b"])
    }

    @Test func tupleViewFlattensNestedForEachView() {
        let tuple = TupleView(Text("x"), ForEachView([Text("a"), Text("b")]))
        #expect(tuple._childViews().count == 3)
        #expect(resolvedTexts(tuple._childViews()) == ["x", "a", "b"])
    }

    @Test func tupleViewFlattensNestedTupleView() {
        let tuple = TupleView(Text("a"), TupleView(Text("b"), Text("c")))
        #expect(tuple._childViews().count == 3)
        #expect(resolvedTexts(tuple._childViews()) == ["a", "b", "c"])
    }

    @Test func forEachViewExposesOneViewPerElement() {
        let forEach = ForEachView([Text("a"), Text("b")])
        #expect(forEach._childViews().count == 2)
        #expect(resolvedTexts(forEach._childViews()) == ["a", "b"])
    }

    @Test func forEachViewFlattensMultiExpressionElements() {
        // A loop whose body has two expressions builds a TupleView per
        // element; both flattened children participate in layout.
        let forEach = ForEachView([
            TupleView(Text("a"), Text("b")),
            TupleView(Text("c"), Text("d")),
        ])
        #expect(forEach._childViews().count == 4)
        #expect(resolvedTexts(forEach._childViews()) == ["a", "b", "c", "d"])
    }

    @Test func conditionalContentExposesActiveBranch() {
        let on: ConditionalContent<Text, Empty> = .first(Text("on"))
        let off: ConditionalContent<Empty, Text> = .second(Text("off"))
        #expect(resolvedTexts(on._childViews()) == ["on"])
        #expect(resolvedTexts(off._childViews()) == ["off"])
    }

    @Test func conditionalContentFlattensMultiExpressionBranch() {
        // A multi-expression `if` body is itself a TupleView; the branch's
        // children are exposed individually.
        let first: ConditionalContent<TupleView<Text, Text>, Empty> = .first(TupleView(Text("m"), Text("n")))
        let second: ConditionalContent<Empty, TupleView<Text, Text>> = .second(TupleView(Text("x"), Text("y")))
        #expect(resolvedTexts(first._childViews()) == ["m", "n"])
        #expect(resolvedTexts(second._childViews()) == ["x", "y"])
    }

    @Test func optionalViewExposesContentWhenPresent() {
        let some: OptionalView<Text> = OptionalView(Text("y"))
        #expect(resolvedTexts(some._childViews()) == ["y"])
    }

    @Test func optionalViewExposesNothingWhenNil() {
        let none: OptionalView<Text> = OptionalView(nil)
        #expect(none._childViews().isEmpty)
    }
}

// MARK: - StyledText.maxLineWidth (moved from Latte, now internal to Chai)

@Suite("StyledText maxLineWidth")
struct StyledTextMaxLineWidthTests {

    @Test func plainContent() {
        #expect(StyledText("abc").maxLineWidth == 3)
    }

    @Test func multilineTakesWidestLine() {
        #expect(StyledText("a\nbb").maxLineWidth == 2)
        #expect(StyledText("aa\nb").maxLineWidth == 2)
    }

    @Test func cjkCountsDisplayColumns() {
        #expect(StyledText("你好").maxLineWidth == 4)
        #expect(StyledText("你好\nx").maxLineWidth == 4)
        #expect(StyledText("x\n你好").maxLineWidth == 4)
    }

    @Test func emptyContentMeasuresZero() {
        #expect(StyledText().maxLineWidth == 0)
        #expect(StyledText("").maxLineWidth == 0)
    }
}