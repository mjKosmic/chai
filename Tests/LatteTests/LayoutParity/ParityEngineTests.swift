import Testing
import Chai
import Latte

// MARK: - Engine parity suite (phase 4: the allocation path)
//
// The phase-2 M2 suite, re-roled in P3: the engine path is now the single
// phase-4 allocation walk (`_embed`), so every corpus case asserts its
// **documented** rows (`expectedEmbedRows ?? expectedEngineRows ??
// expectedRows`).
//
// - Non-divergent cases must also reproduce the pinned eager spec and the live
//   eager buffer, except for cases carrying a documented **allocation delta**
//   (UPGRADE.md, "Phase 4 — allocation deltas") — the delta is asserted
//   explicitly, never tolerated silently.
// - `isKnownDivergent` cases must reproduce their documented engine rows
//   (`expectedEngineRows`): the closed divergence list #1–#10 (UPGRADE.md) —
//   #1 Spacer doubling, #3 multi-line VStack children aligned as blocks, #4
//   flexible-axis fill, #5/#6 proposal-consuming `Text` wraps, #7
//   `FlexibleSpacer`, #8 `Fill`, #9 `.clipped()`, #10 newline-only `Text`.
//   No case is skipped.

@Suite("Layout Parity — engine path")
struct ParityEngineTests {

    /// Assert that a buffer's visible rows equal a case's documented rows.
    private func assertVisibleRows(
        _ parityCase: ParityCase,
        build: (ParityCase) -> CellBuffer
    ) {
        let rows = visibleRows(build(parityCase))
        #expect(
            rows == parityCase.documentedRows,
            "Case '\(parityCase.name)': expected \(parityCase.documentedRows), got \(rows)"
        )
    }

    /// Every corpus case — divergent or not — asserts its documented output
    /// through the allocation engine.
    @Test("Engine path matches the documented rows for every corpus case")
    func engineMatchesPinnedSpec() {
        for parityCase in ParityCase.allCases {
            assertVisibleRows(parityCase) { item in
                embedBuffer(item.view, width: item.width, height: item.explicitHeight)
            }
        }
    }

    /// The engine must reproduce today's eager output for every non-divergent
    /// case without an allocation delta (engine-vs-eager parity, independent
    /// of the pinned rows).
    @Test("Engine path matches eager path for every corpus case")
    func engineMatchesEager() {
        for parityCase in ParityCase.allCases
        where !parityCase.isKnownDivergent && parityCase.expectedEmbedRows == nil {
            let engine = visibleRows(
                embedBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
            )
            let eager = visibleRows(
                eagerBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
            )
            #expect(
                engine == eager,
                "Case '\(parityCase.name)': engine \(engine) != eager \(eager)"
            )
        }
    }

    /// Every divergent case asserts its documented engine output explicitly —
    /// nothing is skipped.
    @Test("Divergent cases match documented engine rows")
    func divergentCasesMatchDocumentedEngineRows() {
        for parityCase in ParityCase.allCases where parityCase.isKnownDivergent {
            #expect(
                parityCase.expectedEngineRows != nil,
                "Case '\(parityCase.name)': divergent case must document engine rows"
            )
            assertVisibleRows(parityCase) { item in
                embedBuffer(item.view, width: item.width, height: item.explicitHeight)
            }
        }
    }

    /// Documented allocation deltas are on record with explicit rows and
    /// actually differ from the eager path (the delta is the point).
    @Test("Documented allocation deltas are on record")
    func allocationDeltasAreOnRecord() {
        let deltas = ParityCase.allCases.filter { $0.expectedEmbedRows != nil }
        #expect(!deltas.isEmpty, "expected at least one documented allocation delta")
        for parityCase in deltas {
            let engine = visibleRows(
                embedBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
            )
            #expect(
                engine == parityCase.expectedEmbedRows,
                "Case '\(parityCase.name)': expected \(parityCase.expectedEmbedRows ?? []), got \(engine)"
            )
            #expect(
                engine != parityCase.expectedRows,
                "Case '\(parityCase.name)': expected an allocation delta, but the path matched the eager pin"
            )
        }
    }
}
