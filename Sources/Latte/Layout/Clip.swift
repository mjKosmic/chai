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
///   including an answer larger than the assigned rect.
/// - **Rendering reserves, draws into a temp, then blits.** The content's
///   occupied size is reserved through the pure sizing pass
///   (``View/_sizeThatFits(_:)`` under the assigned rect's context), the
///   content is embedded into a temporary ``CellBuffer`` of exactly that size
///   (origin ``ViewOrigin/zero``), and the temp is blitted onto the shared
///   buffer at the rect's origin. Overflow in either axis is dropped by the
///   temp's bounds; the temp uses the default truncate write policy, so
///   horizontal overflow is masked rather than reflowed.
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
    /// the content's answer (which may exceed the assigned rect).
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        content._sizeThatFits(proposal)
    }

    /// Mask the content at the rect it occupies.
    ///
    /// The mask size is the child's **reserved** size from the pure sizing
    /// pass (`_sizeThatFits` under the assigned rect's context). The child is
    /// embedded into a temp buffer of exactly that size (truncate policy:
    /// horizontal overflow and wide-character-straddling drops stay unchanged),
    /// then the whole temp is blitted blank-inclusive at the rect origin
    /// (painter order).
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let reserved = content._sizeThatFits(
            ProposedSize(width: rect.size.width, height: rect.size.height)
        )
        var clipped = CellBuffer(width: reserved.width, height: reserved.height)
        content._embed(into: &clipped, at: ViewRect(origin: .zero, size: reserved))
        blit(clipped, into: &buffer, at: rect.origin)
    }

    /// Copy a temp buffer onto the shared buffer at `origin`, preserving the
    /// buffer's wide-character invariants (continuation cells are skipped:
    /// setting a primary already creates its continuation).
    private func blit(_ clipped: CellBuffer, into buffer: inout CellBuffer, at origin: ViewOrigin) {
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
