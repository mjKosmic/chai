import Chai

// MARK: - ClipView

/// A view that masks its content to the rect it is assigned.
///
/// ``clipped()`` is the opt-in that accompanies
/// ``View/frame(width:height:horizontalAlignment:verticalAlignment:)``'s
/// pinned no-clip decision (see `Frame.swift`): a frame is *placement*, not
/// shrinking, so content larger than the frame overflows its bounds. Wrapping
/// the frame in `.clipped()` masks that overflow.
///
/// ## Engine semantics
///
/// - **Measurement is a passthrough.** Clipping is a render-time mask; it never
///   changes a size. `.clipped()` reports exactly what its content reports —
///   including an answer larger than the offer (the proposal is an offer, not a
///   bound).
/// - **Rendering draws into a temp buffer, then blits.** The content is
///   rendered into a temporary ``CellBuffer`` of the assigned `size` (origin
///   ``ViewOrigin/zero``, with the *same* `proposal` — the A0 fit/render
///   value-equality contract), and that temp is then blitted onto the shared
///   buffer at `origin`. Overflow in either axis is dropped by the temp's
///   bounds; the temp uses the default truncate write policy, so horizontal
///   overflow is masked rather than reflowed.
/// - **The clipped view owns its assigned rect.** The whole temp — including
///   blank cells the child never painted — replaces whatever was beneath it
///   (painter's-algorithm semantics). Content under a clip's rect is painted
///   over even where the child is blank; rare overlap-under-clip is the
///   documented cost.
/// - **Wide characters straddling the clip boundary are dropped.** A width-2
///   character whose second column would fall outside the rect is not painted,
///   by the temp buffer's wide-character write rules.
///
/// ## Legacy body
///
/// The eager path has no assigned rect, so it cannot clip: `body` resolves the
/// content unchanged. This is allowed divergence #9 in UPGRADE.md.
///
/// ```swift
/// Text("a very long line")
///     .frame(width: 4)
///     .clipped()
/// ```
public struct ClipView<Content: View>: View {
    /// The content to clip.
    let content: Content

    /// Create a clip around the given content.
    ///
    /// - Parameter content: A ``ViewBuilder`` closure providing the content.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    // MARK: Legacy body (eager path)

    /// The eager path cannot clip — it has no assigned rect — so it resolves
    /// the content unchanged. Clipping exists only in the engine (allowed
    /// divergence #9 in UPGRADE.md).
    public var body: ViewOutput {
        content._resolveToViewOutput()
    }
}

// MARK: - ClipView engine implementation

extension ClipView {
    /// Passthrough: clipping never changes measurement, so the size is exactly
    /// the content's answer (which may exceed the offer — an offer, not a
    /// bound).
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        content._sizeThatFits(proposal)
    }

    /// Render the content into a temp buffer of the assigned `size` (origin
    /// zero, same proposal), then blit the whole temp — blanks included — onto
    /// the shared buffer at `origin`.
    ///
    /// The blit uses the public ``CellBuffer/set(col:row:_:)``, which preserves
    /// the buffer's wide-character invariants as each cell lands. Wide
    /// *continuation* cells (`width == 0`) are skipped: setting a primary
    /// already creates its continuation, and setting a continuation directly
    /// would clear the primary it belongs to. The temp buffer's `write` never
    /// produces any other zero-width cell (combining marks are skipped at
    /// write time).
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        var clipped = CellBuffer(width: size.width, height: size.height)
        content._render(into: &clipped, at: .zero, size: size, proposal: proposal)
        for row in 0..<clipped.height {
            for col in 0..<clipped.width {
                let cell = clipped[col, row]
                guard cell.width != 0 else { continue }
                buffer.set(col: origin.col + col, row: origin.row + row, cell)
            }
        }
    }
}

// MARK: - View.clipped modifier

extension View {
    /// Mask this view's rendering to the rect it is assigned.
    ///
    /// Clipping is a render-time mask: it never changes measurement, so the
    /// view answers exactly the size it would without `.clipped()`. It is the
    /// opt-in for ``frame(width:height:horizontalAlignment:verticalAlignment:)``'s
    /// pinned no-clip behavior — a frame is placement, not shrinking.
    ///
    /// ```swift
    /// // Mask a child that is wider than the frame.
    /// Text("a very long line")
    ///     .frame(width: 4)
    ///     .clipped()
    /// ```
    ///
    /// - Returns: A ``ClipView`` wrapping this view.
    public func clipped() -> ClipView<Self> {
        ClipView { self }
    }
}
