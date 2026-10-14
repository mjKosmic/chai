import Chai

// MARK: - Proposal-echo test consumer (test-local only)

/// A proposal-*consuming* test child: measures `min(proposal.width ?? 12, 12)`
/// wide (height 1) and renders the literal text `W:<proposal.width>` (or
/// `W:-1` when the width proposal is `nil`) at its origin.
///
/// This is the first proposal-consuming view in the codebase, used ONLY by
/// tests to observe the proposal a child receives at render time — the A0
/// fit/render value-equality contract is pinned by what this view echoes.
/// (Duplicated in the ChaiTests target, which cannot see this file.)
struct ProposalEchoView: View {
    var body: ViewOutput { ViewOutput("") }

    func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let width = min(proposal.width ?? 12, 12)
        return ViewSize(width: width, height: 1)
    }

    func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        buffer.write(StyledText("W:\(proposal.width ?? -1)"), at: origin.col, row: origin.row)
    }
}