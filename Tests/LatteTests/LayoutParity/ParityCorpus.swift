import Chai
import Latte

// MARK: - Parity corpus
//
// A named corpus of view trees, each pinned with the visible rows produced by
// the phase-4 allocation engine (`embedBuffer` + `visibleRows` in
// `ParityHarness.swift`). This is the engine spec: after P4b retired the eager
// `_resolveToViewOutput()` path, there is no second renderer to compare
// against, and the historical eager-vs-engine divergence list (#1–#10 in
// UPGRADE.md) is closed. `expectedRows` is the single source of truth.
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
    /// Optional explicit buffer height. When `nil`, the height is the view's
    /// reported query height (inline-mode rendering).
    let explicitHeight: Int?
    /// Pinned expected visible rows — the engine spec.
    let expectedRows: [String]

    init(
        name: String,
        view: any View,
        width: Int,
        explicitHeight: Int? = nil,
        expectedRows: [String]
    ) {
        self.name = name
        self.view = view
        self.width = width
        self.explicitHeight = explicitHeight
        self.expectedRows = expectedRows
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
            name: "vstack center alignment places children as blocks",
            view: VStack(alignment: .center) {
                Text("ab")
                Text("cdef")
            },
            width: 8,
            // The 2-wide child sits at col 1 of the 4-wide stack
            // (shortage 2 → Int(2 × 0.5) = 1); trailing padding is stripped.
            expectedRows: [" ab", "cdef"]
        ),

        ParityCase(
            name: "vstack right alignment places children as blocks",
            view: VStack(alignment: .right) {
                Text("ab")
                Text("cdef")
            },
            width: 8,
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
            name: "hstack differing heights anchors shorter child",
            view: HStack {
                Text("a\nb")
                Text("1")
            },
            width: 8,
            // Top alignment (the default): the 1-row child sits at row 0.
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
            // The stack is 3 wide; "ok" (2 wide) has a center shortage of 1,
            // which truncates to 0 — the block stays at col 0.
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

        // ── Text wrapping (A1) ──────────────────────────────────────────────

        ParityCase(
            name: "vstack wide Text line wraps instead of truncating",
            view: VStack {
                Text("abcdefgh")
                Text("x")
            },
            width: 5,
            // `Text("abcdefgh")` wraps at the 5-column allocated width:
            // "abcde"/"fgh" (char-level fallback), then "x".
            expectedRows: ["abcde", "fgh", "x"]
        ),

        // ── Spacer (engine semantics) ───────────────────────────────────────

        ParityCase(
            name: "vstack with spacer lines 2 reserves exactly two blank rows",
            view: VStack {
                Text("a")
                Spacer(lines: 2)
                Text("b")
            },
            width: 8,
            // The engine measures the spacer's requested count directly —
            // exactly 2 blank rows (the retired eager join double-counted the
            // spacer's newlines; that bug is not preserved).
            expectedRows: ["a", "", "", "b"]
        ),

        // ── Multi-line children align as blocks ─────────────────────────────

        ParityCase(
            name: "vstack center aligns multiline child as block",
            view: VStack(alignment: .center) {
                Text("a\nbb")
                Text("ccc")
            },
            width: 8,
            // The 2×2 child block stays at col 0 (shortage 1,
            // Int(1 × 0.5) = 0); alignment applies per child, not per line.
            expectedRows: ["a", "bb", "ccc"]
        ),

        ParityCase(
            name: "vstack right aligns multiline child as block",
            view: VStack(alignment: .right) {
                Text("a\nbb")
                Text("ccc")
            },
            width: 8,
            // The 2×2 child block sits at col 1 (shortage 1,
            // Int(1 × 1.0) = 1). Row 0 is "a" at col 1 → visible " a": the
            // block's own right edge is flush.
            expectedRows: [" a", " bb", "ccc"]
        ),

        // ── Cross-container nesting ─────────────────────────────────────────

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

        // ── All-empty children ──────────────────────────────────────────────

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

        // ── frame() ────────────────────────────────────────────────────────

        ParityCase(
            name: "fixed frame left top around small vstack",
            view: VStack {
                Text("a")
                Text("b")
            }
            .frame(width: 6, height: 3),
            width: 6,
            // The frame owns a 6×3 rect; the child is top-left → one blank row
            // below the content.
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
            // Right-aligned to col 7; bottom-aligned with 2 blank rows above.
            expectedRows: ["", "", "       a", "       b"]
        ),

        ParityCase(
            name: "fixed frame center middle around text",
            view: Text("ab")
                .frame(width: 8, height: 3, horizontalAlignment: .center, verticalAlignment: .middle),
            width: 8,
            // Centered horizontally (col 3); one blank row each side (the odd
            // remainder goes bottom).
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
            // "ab" centered (col 2); one blank row at the bottom.
            expectedRows: ["  ab", ""]
        ),

        ParityCase(
            name: "fixed frame smaller than Text wraps it",
            view: Text("abcd")
                .frame(width: 2, horizontalAlignment: .center),
            width: 2,
            // The frame's 2-column width reaches the Text as its allocation;
            // the text wraps rather than overflowing.
            expectedRows: ["ab", "cd"]
        ),

        ParityCase(
            name: "flexible width frame fills the assignment and centers",
            view: Text("ab")
                .frame(horizontalAlignment: .center),
            width: 8,
            // The flexible frame keeps the 8-column assignment and centers the
            // 2-wide child at col 3.
            expectedRows: ["   ab"]
        ),

        // ── Flexible spacer ────────────────────────────────────────────────

        ParityCase(
            name: "hstack flexible spacer distributes leftover",
            view: HStack {
                Text("L")
                Spacer()
                Text("R")
            },
            width: 10,
            // The spacer absorbs the 8-column leftover.
            expectedRows: ["L        R"]
        ),

        // ── Fill (consumer semantics) ──────────────────────────────────────

        ParityCase(
            name: "vstack right-aligned Fill claims the proposed width",
            view: VStack(alignment: .right) {
                Text("ab")
                Fill()
            },
            width: 8,
            // Fill claims the 8-column proposal, so the stack is 8 wide and the
            // right-aligned Text sits at offset 6.
            expectedRows: ["      ab"]
        ),

        // ── Clipping ───────────────────────────────────────────────────────

        ParityCase(
            name: "clipped frame masks overflow",
            view: ViewOutput("abcd")
                .frame(width: 2)
                .clipped(),
            width: 4,
            // The frame answers width 2; the 4-wide raster overflows it and the
            // clip masks it.
            expectedRows: ["ab"]
        ),

        // ── Text whitespace ────────────────────────────────────────────────

        ParityCase(
            name: "newline-only Text collapses to nothing",
            view: Text("\n"),
            width: 8,
            // Content with no visible character wraps to empty and measures
            // 0×0 (A1 blank-line rule).
            expectedRows: []
        ),

        // ── HStack Fill rule (phase-4 allocation) ──────────────────────────

        ParityCase(
            name: "hstack trailing Fill claims the remaining width",
            view: HStack {
                Text("x")
                Fill()
            },
            width: 8,
            // The trailing Fill paints nothing and the text sits at col 0. The
            // Fill grows the stack's OCCUPIED width (1 → 8) — invisible here,
            // pinned by `AllocationRulesTests` and by the parent-alignment case
            // below.
            expectedRows: ["x"]
        ),

        ParityCase(
            name: "hstack leading Fill shifts its sibling",
            view: HStack {
                Fill()
                Text("x")
            },
            width: 8,
            // A leading Fill claims columns 0–6, placing "x" at col 7.
            expectedRows: ["       x"]
        ),

        ParityCase(
            name: "trailing Fill grows the stack's occupied width",
            view: VStack(alignment: .right) {
                HStack {
                    Text("x")
                    Fill()
                }
                Text("y")
            },
            width: 8,
            // The HStack occupies the assigned 8 columns, so the right-aligned
            // sibling "y" sits at col 7.
            expectedRows: ["x", "       y"]
        ),

        // ── Stage-C wrappers (P4a) ─────────────────────────────────────────

        ParityCase(
            name: "padded text shrink-wraps its content",
            view: Text("x").padded(1),
            width: 8,
            expectedRows: ["", " x", ""]
        ),

        ParityCase(
            name: "bordered vstack draws a content-sized box",
            view: VStack {
                Text("a")
                Text("bb")
            }
            .bordered(.ascii),
            width: 8,
            expectedRows: ["+--+", "|a |", "|bb|", "+--+"]
        ),
    ]
}
