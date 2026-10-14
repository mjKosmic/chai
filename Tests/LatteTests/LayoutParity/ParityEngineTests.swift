import Testing
import Chai
import Latte

// MARK: - M2 engine parity suite
//
// Milestone M2 of the phase-2 layout engine: the container overrides
// (`VStack`/`HStack` `_sizeThatFits`/`_render`) running the full M0 corpus.
//
// Every corpus case is asserted on the engine path:
// - Non-divergent cases must reproduce BOTH the pinned eager spec
//   (`expectedRows`) and the live eager buffer (`eagerBuffer`).
// - `isKnownDivergent` cases must reproduce their documented engine rows
//   (`expectedEngineRows`): the closed divergence list #1–#9 (UPGRADE.md) —
//   #1 Spacer doubling, #3 multi-line VStack children aligned as blocks, #4
//   flexible-axis fill, #5/#6 proposal-consuming `Text` wraps, #7
//   `FlexibleSpacer`, #8 `Fill`, #9 `.clipped()`. No case is skipped: every
//   divergent case has a positive engine-side expectation.

@Suite("Layout Parity — M2 engine path")
struct ParityEngineTests {

    /// Assert that a buffer's visible rows equal a case's expected rows.
    private func assertVisibleRows(
        _ parityCase: ParityCase,
        build: (ParityCase) -> CellBuffer
    ) {
        let rows = visibleRows(build(parityCase))
        let expected = parityCase.expectedEngineRows ?? parityCase.expectedRows
        #expect(
            rows == expected,
            "Case '\(parityCase.name)': expected \(expected), got \(rows)"
        )
    }

    /// The engine must reproduce every non-divergent case's pinned spec.
    @Test("Engine path matches pinned spec for every corpus case")
    func engineMatchesPinnedSpec() {
        for parityCase in ParityCase.allCases where !parityCase.isKnownDivergent {
            assertVisibleRows(parityCase) { item in
                engineBuffer(item.view, width: item.width, height: item.explicitHeight)
            }
        }
    }

    /// The engine must reproduce today's eager output for every non-divergent
    /// case (engine-vs-eager parity, independent of the pinned rows).
    @Test("Engine path matches eager path for every corpus case")
    func engineMatchesEager() {
        for parityCase in ParityCase.allCases where !parityCase.isKnownDivergent {
            let engine = visibleRows(
                engineBuffer(parityCase.view, width: parityCase.width, height: parityCase.explicitHeight)
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
                engineBuffer(item.view, width: item.width, height: item.explicitHeight)
            }
        }
    }
}