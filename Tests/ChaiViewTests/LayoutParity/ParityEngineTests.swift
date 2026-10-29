import Testing
import Chai

// MARK: - Engine spec suite
//
// There is one renderer: every case asserts its pinned rows through the
// allocation walk (`_embed`). The rows are the engine semantics, pinned here.

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
