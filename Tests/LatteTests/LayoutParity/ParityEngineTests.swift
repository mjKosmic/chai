import Testing
import Chai
import Latte

// MARK: - Engine spec suite (phase 4, P4b)
//
// The eager `_resolveToViewOutput()` bridge was retired in P4b, so the corpus
// no longer has two renderers to compare: every case asserts its pinned rows
// through the phase-4 allocation walk (`_embed`). The historical
// eager-vs-engine divergence list (#1–#10 in UPGRADE.md) is closed — its rows
// are now simply the engine semantics, pinned here.

@Suite("Layout Parity — engine spec")
struct ParityEngineTests {

    /// Every corpus case asserts its pinned output through the allocation
    /// engine. Nothing is skipped.
    @Test("Engine path matches the pinned rows for every corpus case")
    func engineMatchesPinnedSpec() {
        for parityCase in ParityCase.allCases {
            let rows = visibleRows(
                embedBuffer(
                    parityCase.view,
                    width: parityCase.width,
                    height: parityCase.explicitHeight
                )
            )
            #expect(
                rows == parityCase.expectedRows,
                "Case '\(parityCase.name)': expected \(parityCase.expectedRows), got \(rows)"
            )
        }
    }

    /// The corpus is the spec: names are unique and the corpus is not empty
    /// (a tripwire against an accidentally emptied table).
    @Test("Corpus is complete and uniquely named")
    func corpusIsComplete() {
        let names = ParityCase.allCases.map(\.name)
        #expect(!names.isEmpty)
        #expect(Set(names).count == names.count)
    }
}
