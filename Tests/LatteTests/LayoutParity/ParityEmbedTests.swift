import Testing
import Chai
import Latte

// MARK: - P1/P2 allocation-path parity suite
//
// Phase 4 P1/P2: the corpus runs through the allocation (`_embed`) walk
// side-by-side with the phase-3 engine. The spike's prediction — walker ==
// engine, bug-for-bug — is the acceptance bar (`TOP-DOWN-SPIKE.md`).
//
// Classification:
// - Every case must reproduce its documented allocation rows:
//   `expectedEmbedRows ?? expectedEngineRows ?? expectedRows`.
// - Cases WITHOUT `expectedEmbedRows` must match the live phase-3 engine
//   byte-for-byte on visible rows (the side-by-side window).
// - Cases WITH `expectedEmbedRows` are documented *allocation deltas*
//   (UPGRADE.md, "Phase 4 — allocation deltas") and must differ from the
//   phase-3 engine — the delta is the point, so it is asserted, not tolerated.

@Suite("Layout Parity — allocation (embed) path")
struct ParityEmbedTests {

    private func embedRows(_ parityCase: ParityCase) -> [String] {
        visibleRows(
            embedBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
        )
    }

    private func engineRows(_ parityCase: ParityCase) -> [String] {
        visibleRows(
            engineBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
        )
    }

    private func documentedRows(_ parityCase: ParityCase) -> [String] {
        parityCase.expectedEmbedRows
            ?? parityCase.expectedEngineRows
            ?? parityCase.expectedRows
    }

    /// Every corpus case — divergent or not — asserts its documented
    /// allocation output. Nothing is skipped.
    @Test("Allocation path reproduces every corpus case's documented rows")
    func embedMatchesPinnedRows() {
        for parityCase in ParityCase.allCases {
            #expect(
                embedRows(parityCase) == documentedRows(parityCase),
                "Case '\(parityCase.name)': expected \(documentedRows(parityCase)), got \(embedRows(parityCase))"
            )
        }
    }

    /// The side-by-side window: with the phase-3 engine still live, every
    /// case without a documented allocation delta must produce identical
    /// visible rows through both engines.
    @Test("Allocation path matches the phase-3 engine except documented deltas")
    func embedMatchesEngine() {
        for parityCase in ParityCase.allCases where parityCase.expectedEmbedRows == nil {
            #expect(
                embedRows(parityCase) == engineRows(parityCase),
                "Case '\(parityCase.name)': allocation \(embedRows(parityCase)) != engine \(engineRows(parityCase))"
            )
        }
    }

    /// Documented allocation deltas must actually be deltas — and must be on
    /// record with explicit rows (no silent drift between the two engines).
    @Test("Documented allocation deltas diverge from the phase-3 engine")
    func allocationDeltasAreOnRecord() {
        let deltas = ParityCase.allCases.filter { $0.expectedEmbedRows != nil }
        #expect(!deltas.isEmpty, "expected at least one documented allocation delta")
        for parityCase in deltas {
            #expect(
                embedRows(parityCase) == parityCase.expectedEmbedRows,
                "Case '\(parityCase.name)': expected \(parityCase.expectedEmbedRows ?? []), got \(embedRows(parityCase))"
            )
            #expect(
                embedRows(parityCase) != engineRows(parityCase),
                "Case '\(parityCase.name)': expected an allocation delta, but both paths produced \(engineRows(parityCase))"
            )
        }
    }

    /// The allocation path must also agree with the eager spec wherever the
    /// phase-3 engine does (no new eager divergence is introduced).
    @Test("Allocation path matches the eager path for non-divergent cases")
    func embedMatchesEager() {
        for parityCase in ParityCase.allCases
        where !parityCase.isKnownDivergent && parityCase.expectedEmbedRows == nil {
            let eager = visibleRows(
                eagerBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
            )
            #expect(
                embedRows(parityCase) == eager,
                "Case '\(parityCase.name)': allocation \(embedRows(parityCase)) != eager \(eager)"
            )
        }
    }
}
