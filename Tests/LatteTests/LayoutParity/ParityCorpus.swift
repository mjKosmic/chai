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

    init(
        name: String,
        view: any View,
        width: Int,
        explicitHeight: Int? = nil,
        expectedRows: [String],
        isKnownDivergent: Bool = false
    ) {
        self.name = name
        self.view = view
        self.width = width
        self.explicitHeight = explicitHeight
        self.expectedRows = expectedRows
        self.isKnownDivergent = isKnownDivergent
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

        ParityCase(
            name: "vstack wide line truncates at buffer width",
            view: VStack {
                Text("abcdefgh")
                Text("x")
            },
            width: 5,
            expectedRows: ["abcde", "x"]
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
            isKnownDivergent: true
        ),
    ]
}