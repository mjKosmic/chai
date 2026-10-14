import Chai
import Latte

// MARK: - M0 parity corpus
//
// A named corpus of view trees, each pinned with the *visible rows* produced
// by today's eager rendering path (see `eagerBuffer`/`visibleRows` in
// `ParityHarness.swift`). In Milestone M2 the layout engine runs the same
// corpus and must reproduce these rows, with the closed list of allowed
// divergences from UPGRADE.md.
//
// Expected rows were derived by actually running the code — never hand-computed
// (CJK widths and alignment padding are pinned from observed output).

/// A single named corpus case.
struct ParityCase {
    /// Human-readable case name, used in failure messages.
    let name: String
    /// The view tree under test.
    let view: any View
    /// Buffer width in columns.
    let width: Int
    /// Optional explicit buffer height. When `nil`, the height is derived
    /// from the resolved content's `lineCount()` (inline-mode rendering).
    let explicitHeight: Int?
    /// Pinned expected visible rows for today's eager path.
    let expectedRows: [String]
    /// Whether the M2 engine's output is expected to legitimately diverge
    /// from these pinned rows (see UPGRADE.md "Allowed divergences").
    let isKnownDivergent: Bool
    /// Pinned expected visible rows for the M2 engine path. `nil` means the
    /// engine must reproduce ``expectedRows`` (every non-divergent case).
    /// Every `isKnownDivergent` case carries an explicit engine expectation
    /// here so no case is ever skipped by the engine parity suite.
    let expectedEngineRows: [String]?

    init(
        name: String,
        view: any View,
        width: Int,
        explicitHeight: Int? = nil,
        expectedRows: [String],
        isKnownDivergent: Bool = false,
        expectedEngineRows: [String]? = nil
    ) {
        self.name = name
        self.view = view
        self.width = width
        self.explicitHeight = explicitHeight
        self.expectedRows = expectedRows
        self.isKnownDivergent = isKnownDivergent
        self.expectedEngineRows = expectedEngineRows
    }
}

// MARK: - Corpus

extension ParityCase {

    /// All corpus cases.
    static let allCases: [ParityCase] = [
        // ── VStack ──────────────────────────────────────────────────────────

        ParityCase(
            name: "vstack multiple texts",
            view: VStack {
                Text("a")
                Text("b")
                Text("c")
            },
            width: 8,
            expectedRows: ["a", "b", "c"]
        ),

        ParityCase(
            name: "vstack single child",
            view: VStack {
                Text("only")
            },
            width: 8,
            expectedRows: ["only"]
        ),

        ParityCase(
            name: "vstack skips empty child",
            view: VStack {
                Text("a")
                Empty()
                Text("b")
            },
            width: 8,
            expectedRows: ["a", "b"]
        ),

        ParityCase(
            name: "vstack center alignment pads every line to max width",
            view: VStack(alignment: .center) {
                Text("ab")
                Text("cdef")
            },
            width: 8,
            // Joined = " ab \ncdef" (4-col max). Right padding is stripped by
            // `visibleRows`, so the first row keeps only its leading space.
            expectedRows: [" ab", "cdef"]
        ),

        ParityCase(
            name: "vstack right alignment pads every line to max width",
            view: VStack(alignment: .right) {
                Text("ab")
                Text("cdef")
            },
            width: 8,
            // Joined = "  ab\ncdef".
            expectedRows: ["  ab", "cdef"]
        ),

        // ── HStack ──────────────────────────────────────────────────────────

        ParityCase(
            name: "hstack multiple children",
            view: HStack {
                Text("a")
                Text("b")
                Text("c")
            },
            width: 8,
            expectedRows: ["abc"]
        ),

        ParityCase(
            name: "hstack differing heights pads shorter child rows",
            view: HStack {
                Text("a\nb")
                Text("1")
            },
            width: 8,
            // Per-column normalization: the right child is extended with blank
            // rows (which extract as "") → "a1", "b".
            expectedRows: ["a1", "b"]
        ),

        ParityCase(
            name: "hstack bottom alignment",
            view: HStack(alignment: .bottom) {
                Text("a\nb")
                Text("1")
            },
            width: 8,
            expectedRows: ["a", "b1"]
        ),

        ParityCase(
            name: "hstack middle alignment",
            view: HStack(alignment: .middle) {
                Text("a\nb\nc")
                Text("1")
            },
            width: 8,
            expectedRows: ["a", "b1", "c"]
        ),

        ParityCase(
            name: "hstack lays out for loop horizontally",
            view: HStack {
                for item in ["a", "b", "c"] {
                    Text(item)
                }
            },
            width: 8,
            expectedRows: ["abc"]
        ),

        ParityCase(
            name: "hstack includes spacer columns",
            view: HStack {
                Text("a")
                Spacer(columns: 3)
                Text("b")
            },
            width: 8,
            // Interior spaces are preserved — they are not trailing.
            expectedRows: ["a   b"]
        ),

        ParityCase(
            name: "hstack with if true (no else) includes branch",
            view: HStack {
                Text("a")
                if true {
                    Text("b")
                }
            },
            width: 8,
            expectedRows: ["ab"]
        ),

        ParityCase(
            name: "hstack with if false (no else) omits branch",
            view: HStack {
                Text("a")
                if false {
                    Text("b")
                }
            },
            width: 8,
            expectedRows: ["a"]
        ),

        // ── Nesting ─────────────────────────────────────────────────────────

        ParityCase(
            name: "three level nesting: vstack of hstacks with for loop",
            view: VStack {
                HStack {
                    Text("a")
                    Text("b")
                }
                HStack {
                    Text("c")
                    for item in ["d", "e"] {
                        Text(item)
                    }
                }
            },
            width: 8,
            expectedRows: ["ab", "cde"]
        ),

        // ── Styling survives container layout ───────────────────────────────

        ParityCase(
            name: "styled child in vstack center",
            view: VStack(alignment: .center) {
                Text("err".fg(.red))
                Text("ok")
            },
            width: 8,
            // Joined = "err\nok " (3-col max); trailing pad stripped.
            expectedRows: ["err", "ok"]
        ),

        ParityCase(
            name: "styled child in hstack",
            view: HStack {
                Text("a".fg(.red))
                Text("b")
            },
            width: 8,
            expectedRows: ["ab"]
        ),

        // ── Wide characters ─────────────────────────────────────────────────

        ParityCase(
            name: "cjk wide chars in hstack extract as single characters",
            view: HStack {
                Text("你好")
                Text("!")
            },
            width: 8,
            // "你好" = 4 display columns with 2 continuation cells; extracting
            // one character per wide primary yields "你好!", not "你 好 !".
            expectedRows: ["你好!"]
        ),

        ParityCase(
            name: "cjk wide chars in vstack",
            view: VStack {
                Text("你好")
                Text("ok")
            },
            width: 8,
            expectedRows: ["你好", "ok"]
        ),

        // ── Builder expression kinds ────────────────────────────────────────

        ParityCase(
            name: "string literal expression inside vstack",
            view: VStack {
                Text("header")
                "a literal row"
            },
            // Width 13+ so the 13-column literal row is NOT truncated.
            width: 16,
            expectedRows: ["header", "a literal row"]
        ),

        ParityCase(
            name: "viewoutput used directly as child",
            view: VStack {
                Text("top")
                ViewOutput("direct")
                Text("bottom")
            },
            width: 8,
            expectedRows: ["top", "direct", "bottom"]
        ),

        // ── Explicit buffer height ──────────────────────────────────────────

        ParityCase(
            name: "vstack with explicit height pads buffer with blank rows",
            view: VStack {
                Text("a")
                Text("b")
            },
            width: 8,
            explicitHeight: 4,
            expectedRows: ["a", "b", "", ""]
        ),

        // ── Truncation policy pin (spec discovery from the probe) ───────────
        //
        // The eager inline path derives the buffer height from `lineCount()`
        // and rasterizes with `wrapping: false`, so a line wider than the
        // buffer width is TRUNCATED, not wrapped — the overflow columns are
        // dropped and no extra row appears. Pinned here so M2's inline-mode
        // buffer policy (truncate) is verified against it.
        //
        // !!! ALLOWED DIVERGENCE #5 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // A1 made `Text` a proposal consumer: it now WRAPS its content to a
        // positive non-nil width proposal (measure and render use the same
        // `StyledText.wrappedToWidth(_:)`). The engine therefore wraps the
        // 8-column first line into two rows at the 5-column proposal, while
        // the eager path still truncates at the buffer edge (it has no
        // proposal context). Pinned below is TODAY's eager output; the engine
        // must produce the wrapped rows.
        ParityCase(
            name: "DIVERGENT: vstack wide Text line wraps (A1) instead of truncating",
            view: VStack {
                Text("abcdefgh")
                Text("x")
            },
            width: 5,
            // TODAY's eager output: the 8-column line is truncated at the
            // 5-column buffer edge → ["abcde", "x"].
            expectedRows: ["abcde", "x"],
            isKnownDivergent: true,
            // Engine (A1): `Text("abcdefgh")` wraps to "abcde"/"fgh" (char-level
            // fallback at the 5-column proposal) → ["abcde", "fgh", "x"].
            expectedEngineRows: ["abcde", "fgh", "x"]
        ),

        // ── Known divergence ────────────────────────────────────────────────
        //
        // !!! ALLOWED DIVERGENCE #1 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // `Spacer(lines: 2)` inside a VStack resolves today (eager path) to a
        // `ViewOutput("\n\n")` which `joinVertically` glues with an *extra*
        // separator newline on top of the spacer's own newlines. The result is
        // "a\n\n\n\nb" — **3** blank rows between "a" and "b" instead of the
        // requested 2. This doubling quirk is unpinned by tests and is
        // considered a bug in the eager path.
        //
        // The M2 engine will produce exactly 2 blank rows ("a\n\n\nb" →
        // ["a", "", "", "b"]), so this case MUST be excluded when the parity
        // test flips to engine-vs-eager comparison in M2 (the
        // `isKnownDivergent` flag exists for exactly that). Pinned below is
        // TODAY's eager output.
        ParityCase(
            name: "DIVERGENT: vstack with spacer lines 2 doubles blank rows",
            view: VStack {
                Text("a")
                Spacer(lines: 2)
                Text("b")
            },
            width: 8,
            // TODAY's eager output: "a\n\n\n\nb" → 3 blank rows between "a"
            // and "b". The M2 engine must produce exactly 2.
            expectedRows: ["a", "", "", "", "b"],
            isKnownDivergent: true,
            // Engine: exactly 2 blank rows — "a\n\n\nb" → ["a", "", "", "b"].
            expectedEngineRows: ["a", "", "", "b"]
        ),

        // ── M2 additions ─────────────────────────────────────────────────────
        //
        // Pinned by running the code (see the M2 report); expected rows below
        // are not hand-computed.

        // !!! ALLOWED DIVERGENCE #3 (UPGRADE.md) — DO NOT "FIX" THESE CASES !!!
        //
        // Multi-line children under a non-left `VStack` alignment: today's
        // eager `body` aligns every LINE of the joined text, while the engine
        // aligns each CHILD as a block (a child is one layout unit; per-line
        // alignment is an artifact of text joining). Child `Text("a\nbb")`
        // measures 2×2; under `.center` the shortage 1 yields
        // `Int(1 × 0.5)` = 0 → the block stays at col 0, so the engine rows
        // are unpadded. SwiftUI-consistent; unpinned by pre-existing tests
        // (StackTests alignment cases use single-line children).

        ParityCase(
            name: "DIVERGENT: vstack center aligns multiline child as block",
            view: VStack(alignment: .center) {
                Text("a\nbb")
                Text("ccc")
            },
            width: 8,
            // TODAY's eager output: every line aligned to width 3 →
            // " a \nbb \nccc" → [" a", "bb", "ccc"].
            expectedRows: [" a", "bb", "ccc"],
            isKnownDivergent: true,
            // Engine: the 2×2 child block stays at col 0 (shortage 1,
            // Int(1 × 0.5) = 0) → ["a", "bb", "ccc"].
            expectedEngineRows: ["a", "bb", "ccc"]
        ),

        ParityCase(
            name: "DIVERGENT: vstack right aligns multiline child as block",
            view: VStack(alignment: .right) {
                Text("a\nbb")
                Text("ccc")
            },
            width: 8,
            // TODAY's eager output: every line aligned to width 3 →
            // "  a\n bb\nccc" → ["  a", " bb", "ccc"].
            expectedRows: ["  a", " bb", "ccc"],
            isKnownDivergent: true,
            // Engine: the 2×2 child block sits at col 1 (shortage 1,
            // Int(1 × 1.0) = 1). Row 0 is "a" at col 1 → visible " a": the
            // block's own right edge is flush, not the per-line "  a" padding.
            expectedEngineRows: [" a", " bb", "ccc"]
        ),

        // ── Cross-container nesting (parity — engine must match eager) ───────

        ParityCase(
            name: "hstack bottom nests vstack inside",
            view: HStack(alignment: .bottom) {
                Text("top\nmid")
                VStack {
                    Text("a")
                    Text("b")
                }
            },
            width: 8,
            expectedRows: ["topa", "midb"]
        ),

        ParityCase(
            name: "three level hstack vstack hstack with for loop",
            view: HStack {
                VStack {
                    HStack {
                        Text("a")
                        Text("b")
                    }
                    HStack {
                        Text("c")
                        for item in ["d", "e"] {
                            Text(item)
                        }
                    }
                }
                Text("z")
            },
            width: 8,
            // VStack = "ab\ncde"; "z" beside it at col 3 → "ab z", "cde".
            expectedRows: ["ab z", "cde"]
        ),

        // ── All-empty children────────────────────────────────────────────────

        ParityCase(
            name: "hstack all empty children",
            view: HStack {
                Empty()
                Empty()
            },
            width: 8,
            // Both children measure 0×0; the stack is 0×0 → zero rows.
            expectedRows: []
        ),

        // ── M4 additions: frame() ──────────────────────────────────────────
        //
        // Fixed-dimension frames are PARITY cases: the legacy `body`'s
        // `.width()`/`.height()` composition agrees with the engine for fixed
        // dims (both enforce minimums, aligned by the same fraction math).
        // The flexible-axis case is the one divergence (see below).

        ParityCase(
            name: "fixed frame left top around small vstack",
            view: VStack {
                Text("a")
                Text("b")
            }
            .frame(width: 6, height: 3),
            width: 6,
            // Eager: width-pad "a"/"b" to 6 (left), then height-pad 1 blank
            // row at the bottom → rows ["a", "b", ""].
            expectedRows: ["a", "b", ""]
        ),

        ParityCase(
            name: "fixed frame right bottom around small vstack",
            view: VStack {
                Text("a")
                Text("b")
            }
            .frame(width: 8, height: 4, horizontalAlignment: .right, verticalAlignment: .bottom),
            width: 8,
            // Eager: width-pad to 8 (right) → "       a","       b"; then
            // height-pad 2 blank rows on top.
            expectedRows: ["", "", "       a", "       b"]
        ),

        ParityCase(
            name: "fixed frame center middle around text",
            view: Text("ab")
                .frame(width: 8, height: 3, horizontalAlignment: .center, verticalAlignment: .middle),
            width: 8,
            // Eager: width-pad "ab" to 8 (center) → "   ab   "; height-pad 1
            // blank row each side (odd remainder goes bottom) → row 1 has the
            // content.
            expectedRows: ["", "   ab", ""]
        ),

        ParityCase(
            name: "fixed frame center middle around hstack",
            view: HStack {
                Text("a")
                Text("b")
            }
            .frame(width: 6, height: 2, horizontalAlignment: .center, verticalAlignment: .middle),
            width: 6,
            // Eager: "ab" padded to 6 (center) → "  ab  "; height-pad 1 blank
            // row at the bottom (odd remainder goes bottom).
            expectedRows: ["  ab", ""]
        ),

        // !!! ALLOWED DIVERGENCE #6 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // A1 made `Text` a proposal consumer, so a fixed-width frame now WRAPS
        // its Text child to the frame's width. The engine's child is "ab"/"cd"
        // (2×2) inside the 2-wide frame — no horizontal overflow — while the
        // eager `body` (no proposal context) keeps the 4-wide raster and the
        // derived 2-wide buffer truncates it to "ab". The frame still does not
        // clip (pinned); the divergence is the wrap itself. Pinned below is
        // TODAY's eager output; the engine must produce the wrapped rows.
        ParityCase(
            name: "DIVERGENT: fixed frame smaller than Text wraps (A1); eager truncates at buffer",
            view: Text("abcd")
                .frame(width: 2, horizontalAlignment: .center),
            width: 2,
            // TODAY's eager output: the 4-wide raster is truncated at the
            // 2-wide buffer edge → ["ab"].
            expectedRows: ["ab"],
            isKnownDivergent: true,
            // Engine (A1): `Text("abcd")` wraps to the frame's 2-column
            // proposal → ["ab", "cd"].
            expectedEngineRows: ["ab", "cd"]
        ),

        // !!! ALLOWED DIVERGENCE #4 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // Flexible-axis fill exists only in the engine. The eager `body` has
        // no proposal context: with no fixed dimensions it resolves to the
        // content's ideal width ("ab", 2 columns). The engine is proposed 8
        // columns by the harness, fills the offer (answers 8), and centers
        // the 2-wide child within it → "   ab". Default `.left` would make
        // the fill invisible at the visible-rows level (content at col 0
        // either way), so the case uses `.center` to pin the fill + placement
        // in one observable row.

        ParityCase(
            name: "DIVERGENT: flexible width frame fills proposal and centers",
            view: Text("ab")
                .frame(horizontalAlignment: .center),
            width: 8,
            // TODAY's eager output: no proposal context → ideal "ab".
            expectedRows: ["ab"],
            isKnownDivergent: true,
            // Engine: fills the 8-column offer, centers the child at col 3.
            expectedEngineRows: ["   ab"]
        ),

        // ── A2 additions: FlexibleSpacer ───────────────────────────────────
        //
        // !!! ALLOWED DIVERGENCE #7 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // `FlexibleSpacer` distributes leftover main-axis space, which only
        // exists in the engine: the eager path has no proposal context, so its
        // `body` resolves to empty content and the eager HStack join SKIPS the
        // empty component (the phase-1 skip-empty semantics) → "LR". The
        // engine sees the 10-column offer, the spacer reports a positive
        // fraction, and the stack fills the offer and hands the spacer the 8
        // leftover columns → "L        R".
        //
        // A `Fill` corpus case would be invisible under the harness's
        // `(width, nil)` proposal (an HStack offers `nil` width to its
        // children), so `Fill` is covered by unit tests instead —
        // `Tests/ChaiTests/FlexibilityTests.swift` and
        // `Tests/LatteTests/FlexibleSpacerTests.swift`.
        ParityCase(
            name: "DIVERGENT: hstack FlexibleSpacer distributes leftover (A2); eager skips empty spacer",
            view: HStack {
                Text("L")
                FlexibleSpacer()
                Text("R")
            },
            width: 10,
            // TODAY's eager output: the spacer's body is empty and the eager
            // join skips it → "LR".
            expectedRows: ["LR"],
            isKnownDivergent: true,
            // Engine (A2): the spacer absorbs the 8-column leftover → "L" +
            // 8 spaces + "R".
            expectedEngineRows: ["L        R"]
        ),

        // !!! ALLOWED DIVERGENCE #8 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // `Fill` answers the proposal dimensions, so in a non-left-aligned
        // VStack it widens the stack to the offer (Fill claims the proposed
        // width) and shifts its sibling to the alignment offset. The eager
        // path resolves Fill's empty `body` and skips it (skip-empty
        // semantics), so the stack stays content-sized. Pinned below is
        // TODAY's eager output; the engine must produce the shifted row.
        ParityCase(
            name: "DIVERGENT: vstack right-aligned Fill claims proposed width (A2)",
            view: VStack(alignment: .right) {
                Text("ab")
                Fill()
            },
            width: 8,
            // TODAY's eager output: Fill's empty body is skipped → "ab".
            expectedRows: ["ab"],
            isKnownDivergent: true,
            // Engine (A2): Fill claims the 8-column proposal; the stack is
            // 8 wide and the right-aligned Text sits at offset 6 →
            // "      ab".
            expectedEngineRows: ["      ab"]
        ),

        // !!! ALLOWED DIVERGENCE #9 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // `.clipped()` masks overflow only in the engine (A3). The eager path
        // has no assigned rect, so `ClipView.body` resolves its content
        // unchanged — clipping is a render-time mask. The receiver here is a
        // `ViewOutput`, so `.frame(width: 2)` resolves to the NEW `View.frame`
        // (the eager overload requires `height`), producing
        // `FrameView<ViewOutput>`. The eager frame's `.width()` modifier PADS
        // to a minimum and never truncates — "abcd" is already wider than 2, so
        // it is unchanged. The engine's frame answers width 2, the 4-wide
        // raster overflows it, and the clip masks it to "ab".
        ParityCase(
            name: "DIVERGENT: clipped frame masks overflow in the engine (A3); eager no-op",
            view: ViewOutput("abcd")
                .frame(width: 2)
                .clipped(),
            width: 4,
            // TODAY's eager output: `.width(2)` pads to a minimum (a no-op for
            // the already-4-wide "abcd") and `.clipped()` cannot clip →
            // ["abcd"].
            expectedRows: ["abcd"],
            isKnownDivergent: true,
            // Engine (A3): the frame answers width 2; the clip masks the
            // 4-wide raster to the 2-wide rect → ["ab"].
            expectedEngineRows: ["ab"]
        ),

        // !!! ALLOWED DIVERGENCE #10 (UPGRADE.md) — DO NOT "FIX" THIS CASE !!!
        //
        // Newline-only `Text` collapses to 0x0 in the engine: content with
        // no visible character (whitespace- or newline-only) wraps to empty
        // — the A1 blank-line rule preserves hard lines only when the
        // content has a visible character. The eager path resolves
        // `Text("\n")` to `ViewOutput("\n")` and measures `lineCount()` = 2
        // blank rows. Pinned below is TODAY's eager output; the engine
        // renders nothing.
        ParityCase(
            name: "DIVERGENT: newline-only Text collapses to nothing (A1); eager measures two blank rows",
            view: Text("\n"),
            width: 8,
            // TODAY's eager output: "\n" is two blank lines.
            expectedRows: ["", ""],
            isKnownDivergent: true,
            // Engine: no visible character → wraps to empty → 0x0 → no rows.
            expectedEngineRows: []
        ),
    ]
}
