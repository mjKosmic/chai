import Testing
import Chai
import Latte

// MARK: - M0 golden spec
//
// Runs every corpus case through the *today* eager path (`eagerBuffer` +
// `visibleRows`) and asserts the pinned expected rows. This is the golden
// spec that Milestone M2's layout engine must reproduce — except for the
// cases marked `isKnownDivergent` (UPGRADE.md "Allowed divergences").
//
// M2 integration: the parity flip (engine buffer vs eager buffer) is a
// second assertion per case. Use `assertVisibleRows(_:build:)` so the engine
// leg can be added with one line (phase 4: the engine leg is the allocation
// walk via `embedBuffer`):
//
//     @Test("Engine path matches eager path")
//     func engineMatchesEager() {
//         for parityCase in ParityCase.allCases where !parityCase.isKnownDivergent {
//             let eager = eagerBuffer(parityCase.view, width: parityCase.width)
//             assertVisibleRows(
//                 eagerBuffer(parityCase.view, width: parityCase.width),
//                 build: { embedBuffer($0.view, width: $0.width, height: $0.explicitHeight) }
//             )
//         }
//     }

@Suite("Layout Parity — M0 golden spec")
struct ParitySpecTests {

    /// Assert that a buffer's visible rows equal a case's pinned spec.
    ///
    /// Takes a buffer-builder closure so the same assertion can drive both
    /// the eager leg (M0) and the engine leg (M2) with minimal churn.
    private func assertVisibleRows(
        _ parityCase: ParityCase,
        build: (ParityCase) -> CellBuffer
    ) {
        let rows = visibleRows(build(parityCase))
        #expect(
            rows == parityCase.expectedRows,
            "Case '\(parityCase.name)': expected \(parityCase.expectedRows), got \(rows)"
        )
    }

    /// The eager path must reproduce every corpus case's pinned spec.
    @Test("Eager path matches pinned spec for every corpus case")
    func eagerMatchesPinnedSpec() {
        for parityCase in ParityCase.allCases {
            assertVisibleRows(parityCase) { item in
                eagerBuffer(
                    item.view,
                    width: item.width,
                    height: item.explicitHeight
                )
            }
        }
    }
}