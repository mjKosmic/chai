import Testing
import Chai
import Latte

// MARK: - SCRATCH (phase-4 top-down allocation spike)
//
// UNCOMMITTED SCRATCH for the phase-4 investigation; see TOP-DOWN-SPIKE.md in
// the repo root for the full report. Delete this directory when the spike
// lands or dies.
//
// This file prototypes the project owner's thesis: a layout engine where
// AUTHORITATIVE ALLOCATION flows top-down (Elm/Bubble Tea/Ratatui-style)
// while intrinsic measurement is demoted to a PURE QUERY — children report,
// parents decide.
//
// It is implemented entirely over the CURRENT public SPI, never calling
// `body` or `_resolveToViewOutput()`:
//
//   `_childViews()`            — child enumeration (unchanged role)
//   `view._sizeThatFits(...)`  — intrinsic query ONLY (no authority: the
//                                allocator may overrule the answer)
//   `view._render(...)`        — rasterization at the assigned rect
//   `view._flexibility()`      — pure child REPORT of leftover absorption
//
// What is new is entirely in this file: the allocator dispatches per view
// type and assigns every child an explicit rect. Production containers'
// `_render` implementations (which embed the bottom-up negotiation) are
// bypassed; their `_sizeThatFits` remains available as the query channel for
// leaves and nested containers.
//
// Generic containers (`VStack<Content>` etc.) cannot be downcast from
// `any View`, so the spike identifies them via `Mirror` member extraction —
// acceptable for a spike; a real phase 4 would add an SPI marker instead.

// MARK: - Spike layout values

/// The assigned rect: what a container gives a child, first-class.
struct SpikeRect: Sendable, Equatable {
    var origin: ViewOrigin
    var size: ViewSize
}

// MARK: - The top-down allocator

enum TopDownSpike {

    // ── Pure intrinsic queries ────────────────────────────────────────────
    //
    // The ONLY uses of `_sizeThatFits` in the allocator. No authority:
    // callers treat answers as reports and may overrule them (fill, clamp,
    // stretch, ignore). Today's accidental child-proposal rules become
    // EXPLICIT allocator choices (per-type rules documented in `allocate`).

    /// Main-axis width report (a VStack row at the assigned width context).
    private static func widthReport(_ view: any View, offeredWidth: Int?) -> ViewSize {
        view._sizeThatFits(ProposedSize(width: offeredWidth, height: nil))
    }

    /// Height report for an HStack column (width ideal — the pinned
    /// "HStack never proposes width" contract, now an allocator rule).
    private static func heightReport(_ view: any View, offeredHeight: Int?) -> ViewSize {
        view._sizeThatFits(ProposedSize(width: nil, height: offeredHeight))
    }

    // ── Flex share distribution ───────────────────────────────────────────
    //
    // `_flexibility()` is used as a pure child REPORT (same SPI, no
    // authority: a share only changes that child's own allocated size; it can
    // never grow the container beyond the container's own occupancy
    // decision). Semantics mirror the current engine's `distributedMainAxis`:
    // normalized shares, `Int()` truncation, remainder unallocated.

    private static func distributeLeftover(_ rigid: [Int], fractions: [Double?], leftover: Int) -> [Int] {
        guard leftover > 0 else { return rigid }
        let shares = fractions.map { f -> Double in
            guard let f, f > 0, f.isFinite else { return 0 }
            return f
        }
        let totalFlex = shares.reduce(0, +)
        guard totalFlex > 0 else { return rigid }
        return zip(rigid, shares).map { size, share -> Int in
            guard share > 0 else { return size }
            return size + Int(Double(leftover) * (share / totalFlex))
        }
    }

    private static func flexibilityFraction(_ view: any View, axis: KeyPath<LayoutFlexibility, Double?>) -> Double? {
        let f = view._flexibility()[keyPath: axis]
        guard let f, f > 0, f.isFinite else { return nil }
        return f
    }

    // ── Type-keyed allocation policies ────────────────────────────────────
    //
    // Detect fill/flexibility BY TYPE (all concrete public structs, so `is`
    // works). Top-down translation: the child's TYPE states its policy; the
    // container applies it. A real phase 4 would generalise via the
    // `_flexibility()` SPI (already used for shares) plus a fill marker.

    private static func isFill(_ view: any View) -> Bool { view is Fill }
    private static func isFlexibleSpacer(_ view: any View) -> Bool { view is FlexibleSpacer }

    // ── Container identification ──────────────────────────────────────────

    private enum Kinds {
        case vStack(alignment: HorizontalAlignment, content: any View)
        case hStack(alignment: VerticalAlignment, content: any View)
        case frame(
            width: Int?, height: Int?,
            horizontal: HorizontalAlignment, vertical: VerticalAlignment,
            content: any View
        )
        case clip(content: any View)
        case structural(children: [any View])
        case leaf
    }

    private static func inspect(_ view: any View) -> Kinds {
        let typeName = String(describing: Mirror(reflecting: view).subjectType)
        var members: [String: Any] = [:]
        for child in Mirror(reflecting: view).children {
            if let label = child.label { members[label] = child.value }
        }
        if typeName.hasPrefix("VStack<"),
           let alignment = members["alignment"] as? HorizontalAlignment,
           let content = members["content"] as? (any View) {
            return .vStack(alignment: alignment, content: content)
        }
        if typeName.hasPrefix("HStack<"),
           let alignment = members["alignment"] as? VerticalAlignment,
           let content = members["content"] as? (any View) {
            return .hStack(alignment: alignment, content: content)
        }
        if typeName.hasPrefix("FrameView<"),
           let width = members["width"] as? Int?,
           let height = members["height"] as? Int?,
           let horizontal = members["horizontalAlignment"] as? HorizontalAlignment,
           let vertical = members["verticalAlignment"] as? VerticalAlignment,
           let content = members["content"] as? (any View) {
            return .frame(width: width, height: height, horizontal: horizontal, vertical: vertical, content: content)
        }
        if typeName.hasPrefix("ClipView<"),
           let content = members["content"] as? (any View) {
            return .clip(content: content)
        }
        if typeName.hasPrefix("TupleView<") || typeName.hasPrefix("ForEachView<")
            || typeName.hasPrefix("OptionalView<") || typeName.hasPrefix("ConditionalContent<") {
            return .structural(children: view._childViews())
        }
        return .leaf
    }

    // ── The reservation (pure top-down sizing pass) ───────────────────────
    //
    // The top-down analogue of the fit pass, computed by the SAME allocation
    // rules but without rendering. Exposed only so (a) the root can size its
    // buffer (the renderer's content-sizing policy — unchanged) and (b) a
    // ClipView can size its mask BEFORE rendering. It returns the size the
    // allocator will occupy — a prediction, never a binding answer.

    private static func predictedOccupied(
        _ view: any View,
        offeredWidth: Int?,
        offeredHeight: Int?
    ) -> ViewSize {
        switch inspect(view) {
        case .vStack(_, let content):
            return stackShape(
                mainIsVertical: true, content: content,
                assignedWidth: offeredWidth, assignedHeight: offeredHeight
            ).size
        case .hStack(_, let content):
            return stackShape(
                mainIsVertical: false, content: content,
                assignedWidth: offeredWidth, assignedHeight: offeredHeight
            ).size
        case .frame(let width, let height, _, _, let content):
            return frameShape(width: width, height: height, content: content, offeredWidth: offeredWidth, offeredHeight: offeredHeight).size
        case .clip(let content):
            return predictedOccupied(content, offeredWidth: offeredWidth, offeredHeight: offeredHeight)
        case .structural(let children):
            let sizes = children.map { predictedOccupied($0, offeredWidth: offeredWidth, offeredHeight: nil) }
            return ViewSize(width: sizes.map(\.width).max() ?? 0, height: sizes.reduce(0) { $0 + $1.height })
        case .leaf:
            return view._sizeThatFits(ProposedSize(width: offeredWidth, height: offeredHeight))
        }
    }

    // ── Shared stack occupancy computation ────────────────────────────────
    //
    // Both the reservation and the render walk use these rules, so the two
    // can never disagree about sizes; only placement differs (column/row
    // cursor advancement with alignment anchoring).

    private static func stackShape(
        mainIsVertical: Bool,
        content: any View,
        assignedWidth: Int?,
        assignedHeight: Int?
    ) -> (size: ViewSize, childWidths: [Int], childHeights: [Int]) {
        let children = content._childViews()
        let flexWidths = children.map { flexibilityFraction($0, axis: \.width) }
        let flexHeights = children.map { flexibilityFraction($0, axis: \.height) }

        if mainIsVertical {
            // Children report (queries at the ASSIGNED width — the cross
            // axis is not negotiated):
            let reportedWidths = children.map { widthReport($0, offeredWidth: assignedWidth).width }
            let reportedHeights = children.map { widthReport($0, offeredWidth: assignedWidth).height }
            // The container decides:
            let rigidTotal = reportedHeights.reduce(0, +)
            let heights = distributeLeftover(
                reportedHeights,
                fractions: flexHeights,
                leftover: max(0, (assignedHeight ?? rigidTotal) - rigidTotal)
            )
            // Fill-by-type children claim the assigned width on the cross
            // axis (a container decision; their width report is ignored).
            var widths = reportedWidths
            var occupiedWidth = widths.max() ?? 0
            if children.contains(where: isFill) && assignedWidth != nil {
                for index in children.indices where isFill(children[index]) {
                    widths[index] = assignedWidth!
                }
                occupiedWidth = max(occupiedWidth, assignedWidth!)
            }
            return (ViewSize(width: occupiedWidth, height: max(heights.reduce(0, +), assignedHeight ?? heights.reduce(0, +))), widths, heights)
        } else {
            // Columns report at IDEAL width (the cannot-wrap contract, now an
            // explicit allocator rule) and ideal height (no height context
            // crosses the column boundary).
            var reportedWidths = children.map { widthReport($0, offeredWidth: nil).width }
            let reportedHeights = children.map { child in
                isFill(child) ? 0 : heightReport(child, offeredHeight: nil).height
            }
            // The container decides. Main-axis flex shares first (Fill is
            // rigid, so it reports 0 here and claims the remainder below).
            let rigidTotal = zip(reportedWidths, flexWidths).reduce(0) { total, pair in
                total + (pair.1 == nil ? pair.0 : 0)
            }
            var widths = distributeLeftover(
                zip(reportedWidths, flexWidths).map { width, fraction in fraction == nil ? width : 0 },
                fractions: flexWidths,
                leftover: max(0, (assignedWidth ?? rigidTotal) - rigidTotal)
            )
            // Fill-by-type columns absorb what is still unassigned (leftover
            // after flex shares), split evenly among them.
            let unassigned = max(0, (assignedWidth ?? 0) - widths.reduce(0, +))
            if children.contains(where: isFill) && assignedWidth != nil {
                let fills = children.filter(isFill).count
                let share = fills > 0 ? unassigned / fills : 0
                for index in children.indices where isFill(children[index]) {
                    widths[index] = share
                }
                reportedWidths = widths
            }
            let occupiedWidth = widths.reduce(0, +)
            let heights = distributeLeftover(
                reportedHeights,
                fractions: flexHeights,
                leftover: max(0, (assignedHeight ?? (reportedHeights.max() ?? 0)) - (reportedHeights.max() ?? 0))
            )
            return (ViewSize(width: occupiedWidth, height: heights.max() ?? 0), widths, heights)
        }
    }

    private static func frameShape(
        width: Int?, height: Int?,
        content: any View,
        offeredWidth: Int?, offeredHeight: Int?
    ) -> (size: ViewSize, childWidth: Int?, childHeight: Int?) {
        // Fixed dims are ALLOCATION: owned verbatim, offered down verbatim.
        // Flexible dims fill the assigned rect (floor: the child's report —
        // a frame never occupies less than what it must place).
        let childWidth = width ?? offeredWidth
        let childReport = predictedOccupied(content, offeredWidth: childWidth, offeredHeight: nil)
        let occupiedWidth: Int
        if let width {
            occupiedWidth = width
        } else if let offeredWidth {
            occupiedWidth = max(offeredWidth, childReport.width)
        } else {
            occupiedWidth = childReport.width
        }
        let occupiedHeight: Int
        if let height {
            occupiedHeight = height
        } else if let offeredHeight, offeredHeight > childReport.height {
            occupiedHeight = offeredHeight
        } else {
            occupiedHeight = childReport.height
        }
        return (
            ViewSize(width: occupiedWidth, height: occupiedHeight),
            childWidth,
            height
        )
    }

    // ── The allocation walk — render ──────────────────────────────────────

    /// Allocate the view into the assigned `rect` and render it. Returns the
    /// view's occupied rect (what a ClipView masks).
    ///
    /// Per-type allocator rules (condensed; full rationale in the report):
    ///
    /// - **VStack** — offers its assigned rect width as the intrinsic
    ///   context (queries; never compressed by the stack — overflow stays
    ///   visual). `Fill`-by-type children claim the assigned width;
    ///   height-flex children absorb leftover when the assigned height
    ///   exceeds the rigid total. Occupied width = max child width
    ///   (shrink-wrap); children anchored at the alignment fraction of the
    ///   horizontal shortage (same formula as today).
    /// - **HStack** — columns measure at IDEAL width (the pinned
    ///   cannot-wrap contract, now an allocator rule); width-flex children
    ///   absorb the assigned leftover per `_flexibility()`; `Fill`-by-type
    ///   columns absorb what remains after flexible shares. Occupied width =
    ///   Σ column widths; children anchored by the vertical alignment
    ///   fraction against the occupied height.
    /// - **FrameView** — fixed dimensions are ALLOCATION: owned verbatim,
    ///   offered down verbatim; flexible dimensions pass the assigned rect
    ///   through (fill, floored at the child's report). The child occupies
    ///   its reported size, anchored at the alignment fraction of the
    ///   shortage per axis; overflow is unmasked (no clip).
    /// - **ClipView** — masks at the child's occupied rect: reserve first
    ///   (pure), render the child into a temp buffer of that exact size
    ///   (truncate policy — horizontal overflow masked, wide chars dropped),
    ///   blit blank-cells-included (painter order).
    /// - **Leaf** — `Fill` claims exactly the assigned rect; everything else
    ///   renders via `_render` with the ALLOCATION as the proposal: `Text`
    ///   compresses by wrapping at its assigned width (its minimum is still
    ///   hedgeable via a `.zero` query); `ViewOutput` ignores the offer
    ///   (a fully-formed raster). Allocated-more ⇒ anchored, never
    ///   stretched; allocated-less ⇒ visual overflow, buffer bounds remain
    ///   the backstop.
    @discardableResult
    private static func allocate(
        _ view: any View,
        into buffer: inout CellBuffer,
        at rect: SpikeRect,
        offeredHeight: Int?
    ) -> SpikeRect {
        switch inspect(view) {
        case .vStack(let alignment, let content):
            let children = content._childViews()
            let shape = stackShape(
                mainIsVertical: true, content: content,
                assignedWidth: rect.size.width, assignedHeight: offeredHeight
            )
            var row = rect.origin.row
            for index in shape.childWidths.indices {
                let childSize = ViewSize(width: shape.childWidths[index], height: shape.childHeights[index])
                let shortage = max(0, shape.size.width - childSize.width)
                let col = rect.origin.col + Int(Double(shortage) * alignment.fraction)
                allocate(
                    children[index],
                    into: &buffer,
                    at: SpikeRect(origin: ViewOrigin(col: col, row: row), size: childSize),
                    offeredHeight: childSize.height
                )
                row += childSize.height
            }
            return SpikeRect(origin: rect.origin, size: shape.size)

        case .hStack(let alignment, let content):
            let children = content._childViews()
            let shape = stackShape(
                mainIsVertical: false, content: content,
                assignedWidth: rect.size.width, assignedHeight: offeredHeight
            )
            var col = rect.origin.col
            for index in shape.childWidths.indices {
                let childSize = ViewSize(width: shape.childWidths[index], height: shape.childHeights[index])
                let shortage = max(0, shape.size.height - childSize.height)
                let row = rect.origin.row + Int(Double(shortage) * alignment.fraction)
                allocate(
                    children[index],
                    into: &buffer,
                    at: SpikeRect(origin: ViewOrigin(col: col, row: row), size: childSize),
                    offeredHeight: childSize.height
                )
                col += childSize.width
            }
            return SpikeRect(origin: rect.origin, size: shape.size)

        case .frame(let width, let height, let horizontal, let vertical, let content):
            let shape = frameShape(
                width: width, height: height, content: content,
                offeredWidth: rect.size.width, offeredHeight: offeredHeight
            )
            let childReport = predictedOccupied(content, offeredWidth: shape.childWidth, offeredHeight: nil)
            let colShortage = max(0, shape.size.width - childReport.width)
            let rowShortage = max(0, shape.size.height - childReport.height)
            allocate(
                content,
                into: &buffer,
                at: SpikeRect(
                    origin: ViewOrigin(
                        col: rect.origin.col + Int(Double(colShortage) * horizontal.fraction),
                        row: rect.origin.row + Int(Double(rowShortage) * vertical.fraction)
                    ),
                    size: childReport
                ),
                offeredHeight: height
            )
            return SpikeRect(origin: rect.origin, size: shape.size)

        case .clip(let content):
            let reserved = predictedOccupied(content, offeredWidth: rect.size.width, offeredHeight: offeredHeight)
            var clipped = CellBuffer(width: reserved.width, height: reserved.height)
            allocate(content, into: &clipped, at: SpikeRect(origin: .zero, size: reserved), offeredHeight: offeredHeight)
            for row in 0..<clipped.height {
                for col in 0..<clipped.width {
                    let cell = clipped[col, row]
                    guard cell.width != 0 else { continue }
                    buffer.set(col: rect.origin.col + col, row: rect.origin.row + row, cell)
                }
            }
            return SpikeRect(origin: rect.origin, size: reserved)

        case .structural(let children):
            var row = rect.origin.row
            let sizes = children.map { predictedOccupied($0, offeredWidth: rect.size.width, offeredHeight: nil) }
            for index in children.indices {
                allocate(
                    children[index],
                    into: &buffer,
                    at: SpikeRect(origin: ViewOrigin(col: rect.origin.col, row: row), size: sizes[index]),
                    offeredHeight: nil
                )
                row += sizes[index].height
            }
            return SpikeRect(
                origin: rect.origin,
                size: ViewSize(width: sizes.map(\.width).max() ?? 0, height: sizes.reduce(0) { $0 + $1.height })
            )

        case .leaf:
            if isFill(view) {
                return SpikeRect(origin: rect.origin, size: rect.size)
            }
            view._render(
                into: &buffer,
                at: rect.origin,
                size: rect.size,
                proposal: ProposedSize(width: rect.size.width, height: rect.size.height)
            )
            return rect
        }
    }

    // MARK: Corpus entry points

    /// Run a view through the top-down walker and return the visible rows.
    /// The root rect is the terminal: `(0,0,width,h)` with
    /// `h = explicitHeight ?? predicted content height` (the renderer's
    /// content-sizing policy, unchanged; the root offer height stays `nil`
    /// in inline mode exactly like today's harness proposal `(w, nil)`
    /// unless `offeredHeight` is given for alt-screen-style probes).
    static func runTopDown(_ view: any View, width: Int, explicitHeight: Int?, offeredHeight: Int? = nil) -> [String] {
        let predicted = predictedOccupied(view, offeredWidth: width, offeredHeight: offeredHeight)
        let bufferHeight = explicitHeight ?? max(predicted.height, 0)
        var buffer = CellBuffer(width: width, height: bufferHeight)
        _ = allocate(
            view,
            into: &buffer,
            at: SpikeRect(origin: .zero, size: ViewSize(width: width, height: bufferHeight)),
            offeredHeight: offeredHeight
        )
        return visibleRows(buffer)
    }

    /// The live bottom-up engine path, replicated locally from the parity
    /// harness (identical semantics: proposal `(w, nil)`, buffer at the
    /// measured size, render at that size with the same fit proposal — A0).
    static func runEngine(_ view: any View, width: Int, explicitHeight: Int?) -> [String] {
        let proposal = ProposedSize(width: width, height: nil)
        let size = view._sizeThatFits(proposal)
        var buffer = CellBuffer(width: width, height: explicitHeight ?? size.height)
        view._render(into: &buffer, at: .zero, size: size, proposal: proposal)
        return visibleRows(buffer)
    }

    /// The eager path, replicated locally (resolve to `ViewOutput`, rasterize
    /// with the truncate policy — the parity harness's `eagerBuffer`).
    static func runEager(_ view: any View, width: Int, explicitHeight: Int?) -> [String] {
        let output = view._resolveToViewOutput()
        let h = explicitHeight ?? output.content.lineCount()
        var buffer = CellBuffer(width: width, height: h, wrapping: false)
        buffer.write(output.content, wrapping: false)
        return visibleRows(buffer)
    }

    /// Visible-row comparison semantics, copied from the parity harness.
    private static func visibleRows(_ buffer: CellBuffer) -> [String] {
        var rows: [String] = []
        for row in 0..<buffer.height {
            var line = ""
            for col in 0..<buffer.width {
                let cell = buffer[col, row]
                if cell.width == 0 { continue }
                line.append(cell.character)
            }
            rows.append(rstripSpaces(line))
        }
        return rows
    }

    private static func rstripSpaces(_ string: String) -> String {
        var end = string.endIndex
        while end > string.startIndex {
            let prev = string.index(before: end)
            if string[prev] != " " { break }
            end = prev
        }
        return String(string[..<end])
    }
}

// MARK: - The empirical comparison (corpus + probes)

/// One row of the spike's comparison table: what the top-down walker produced
/// vs what the current engine pins/produces for the same case, live-computed
/// during the run.
struct SpikeRow: Sendable {
    let name: String
    let width: Int
    let divergent: Bool
    /// Top-down walker output.
    let walkerRows: [String]
    /// The case's pinned engine expectation (`expectedEngineRows ?? expectedRows`).
    let pinnedEngineRows: [String]
    /// The case's pinned eager expectation (`expectedRows`).
    let pinnedEagerRows: [String]
    /// The current engine, live-computed (sanity vs the pins).
    let liveEngineRows: [String]
    /// The eager path, live-computed (sanity vs the pins).
    let liveEagerRows: [String]
}

extension SpikeRow {
    var walkerMatchesPinnedEngine: Bool { walkerRows == pinnedEngineRows }
    var walkerMatchesPinnedEager: Bool { walkerRows == pinnedEagerRows }
    var walkerMatchesLiveEngine: Bool { walkerRows == liveEngineRows }
    var enginePinsStillHold: Bool { pinnedEngineRows == liveEngineRows }
    var eagerPinsStillHold: Bool { pinnedEagerRows == liveEagerRows }
}

@Suite("Top-down allocation spike (SCRATCH — phase-4 investigation)", .serialized)
struct TopDownSpikeComparisonTests {

    // MARK: Corpus comparison — the empirical heart

    @Test("Corpus cases run through the top-down walker vs current pins")
    func corpusComparison() {
        var rows: [SpikeRow] = []
        for parityCase in ParityCase.allCases {
            let walker = TopDownSpike.runTopDown(
                parityCase.view, width: parityCase.width, explicitHeight: parityCase.explicitHeight
            )
            let liveEngine = TopDownSpike.runEngine(
                parityCase.view, width: parityCase.width, explicitHeight: parityCase.explicitHeight
            )
            let liveEager = TopDownSpike.runEager(
                parityCase.view, width: parityCase.width, explicitHeight: parityCase.explicitHeight
            )
            rows.append(SpikeRow(
                name: parityCase.name,
                width: parityCase.width,
                divergent: parityCase.isKnownDivergent,
                walkerRows: walker,
                pinnedEngineRows: parityCase.expectedEngineRows ?? parityCase.expectedRows,
                pinnedEagerRows: parityCase.expectedRows,
                liveEngineRows: liveEngine,
                liveEagerRows: liveEager
            ))
        }

        // ── Print the full case-by-case table (the deliverable) ────────────
        print(SpikeRow.markdownTable(rows))

        // ── Sanity: the pins still hold against the live paths ─────────────
        for row in rows where !row.enginePinsStillHold {
            #expect(Bool(false), "engine pin drifted for '\(row.name)'")
        }
        for row in rows where !row.eagerPinsStillHold {
            #expect(Bool(false), "eager pin drifted for '\(row.name)'")
        }
        // ── DATA: walker vs the pins. Intentionally diagnostic — a mismatch
        //    is a finding in TOP-DOWN-SPIKE.md's verdict table, not a gate.
        let walkerMatchesEngine = rows.filter(\.walkerMatchesPinnedEngine)
        let walkerMatchesEager = rows.filter(\.walkerMatchesPinnedEager)
        let walkerMatchesEverything = rows.filter { $0.walkerMatchesPinnedEngine && $0.walkerMatchesPinnedEager }
        let walkerMatchesNeither = rows.filter { !$0.walkerMatchesPinnedEngine && !$0.walkerMatchesPinnedEager }
        print("""
        ── walker vs pins summary ──
        total cases:            \(rows.count)
        walker == engine pin:   \(walkerMatchesEngine.count)  (\(walkerMatchesEngine.map(\.name).joined(separator: "; ")))
        walker == eager pin:    \(walkerMatchesEager.count)
        walker == BOTH pins:    \(walkerMatchesEverything.count)
        walker == neither:      \(walkerMatchesNeither.count)  (\(walkerMatchesNeither.map(\.name).joined(separator: "; ")))
        """)

        // Structural invariants only (always true; the data lives in the report):
        #expect(rows.count == ParityCase.allCases.count)
    }

    // MARK: Probes for the semantic questions the corpus cannot answer

    /// Probe: a child assigned a rect TALLER than its content (stretch). With
    /// a positive height offer a FlexibleSpacer absorbs the leftover — the
    /// top-down height allocation the corpus never exercises (harness always
    /// offers height `nil`).
    @Test("Probe: vertical stretch via offered height")
    func probeVerticalStretch() {
        let view = VStack(alignment: .right) {
            Text("ab")
            FlexibleSpacer()
        }
        let walker = TopDownSpike.runTopDown(view, width: 8, explicitHeight: 6, offeredHeight: 6)
        let engine = TopDownSpike.runEngine(view, width: 8, explicitHeight: 6)
        // Engine replica: measured height distributes to 6; the right-aligned
        // Text sits at col 6, row 0; rows 1–5 blank.
        // (Buffer height 6: visible rows rstrip blanks.)
        print("probeVerticalStretch walker=\(walker) engine=\(engine)")
    }

    /// Probe: a child assigned LESS than it needs — non-compressible leaves.
    /// `HStack { Text("你"); Text("好") }` at width 3: the pinned cannot-wrap
    /// rule keeps both columns at intrinsic 2 + 2 = 4 → visual overflow, the
    /// buffer truncates the second character.
    @Test("Probe: overflow when the assigned rect is smaller than content")
    func probeHorizontalOverflow() {
        let view = HStack {
            Text("你")
            Text("好")
        }
        let walker = TopDownSpike.runTopDown(view, width: 3, explicitHeight: nil)
        let engine = TopDownSpike.runEngine(view, width: 3, explicitHeight: nil)
        print("probeHorizontalOverflow walker=\(walker) engine=\(engine)")
    }

    /// Probe: `Text` compresses to its allocated width (top-down wrap), and
    /// the minimum floor at a `.zero` query — a child allocated 1 column but
    /// needing a 2-wide CJK minimum.
    @Test("Probe: compression floor (minimum width query)")
    func probeCompressionFloor() {
        let view = VStack {
            Text("hello world")
        }
        let narrow = TopDownSpike.runTopDown(view, width: 5, explicitHeight: nil)
        let engine = TopDownSpike.runEngine(view, width: 5, explicitHeight: nil)
        // CJK minimum: allocation 1, content minimum 2 → the child overflows
        // its rect; the buffer keeps the full char (width-2 cell at col 0).
        let cjk = TopDownSpike.runTopDown(VStack { Text("你") }, width: 1, explicitHeight: nil)
        let cjkEngine = TopDownSpike.runEngine(VStack { Text("你") }, width: 1, explicitHeight: nil)
        print("probeCompressionFloor narrow walker=\(narrow) engine=\(engine); cjk walker=\(cjk) engine=\(cjkEngine)")
    }

    /// Probe: Fill inside an HStack — the top-down rule (fill = leftover
    /// after flexible shares) vs the bottom-up rule (Fill answers the whole
    /// width proposal and inflates the stack's measured width). Visible rows
    /// are identical here; only the stack's measured width differs, which
    /// matters for a parent's alignment math (e.g. a frame around it).
    @Test("Probe: Fill distributes leftover inside an HStack")
    func probeHStackFill() {
        let view = HStack {
            Text("x")
            Fill()
        }
        let walker = TopDownSpike.runTopDown(view, width: 8, explicitHeight: nil)
        let engine = TopDownSpike.runEngine(view, width: 8, explicitHeight: nil)
        let engineMeasured = view._sizeThatFits(ProposedSize(width: 8, height: nil))
        print("probeHStackFill walker=\(walker) engine=\(engine) engineMeasuredSize=\(engineMeasured)")
    }

    /// Probe: nested flexible spacers — `HStack { L; Spacer; R }` where the
    /// spacer's share is computed by the CONTAINER from the assigned rect,
    /// not by a proposal round-trip.
    @Test("Probe: triple sandwich with two flexible spacers")
    func probeMultipleFlex() {
        let view = HStack {
            FlexibleSpacer()
            Text("mid")
            FlexibleSpacer()
        }
        let walker = TopDownSpike.runTopDown(view, width: 20, explicitHeight: nil)
        let engine = TopDownSpike.runEngine(view, width: 20, explicitHeight: nil)
        print("probeMultipleFlex walker=\(walker) engine=\(engine)")
    }
}

extension SpikeRow {
    /// Markdown table for the report (verbatim per-case verdicts).
    static func markdownTable(_ rows: [SpikeRow]) -> String {
        var out = """
        | case | w | engine pin verdict | eager vs walker |
        |---|---|---|---|
        """
        for row in rows {
            let engineVerdict = row.walkerMatchesPinnedEngine ? "match" : "DIFF "
            let eagerVerdict = row.walkerMatchesPinnedEager ? "match" : "diff"
            out += "\n| \(row.name) | \(row.width) | \(engineVerdict) | \(eagerVerdict) |"
        }
        return out
    }
}
