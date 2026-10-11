import Chai

// MARK: - FrameView

/// A view that proposes a fixed (or flexible) frame size to its content and
/// aligns the content within the assigned rect.
///
/// ``frame(width:height:horizontalAlignment:verticalAlignment:)`` is the
/// acceptance feature of the phase-2 proposal-driven layout engine
/// (UPGRADE.md, "Phase 2"): it *cannot* be implemented without proposals —
/// a fixed dimension must be forced down to the child during measurement and
/// answered to the parent regardless of the child's answer.
///
/// ## Frame is a proposal generator
///
/// - Fixed dimensions (non-`nil` `width`/`height`) are proposed to the child
///   and answered to the parent verbatim: `frame(width: 40)` reports 40
///   columns wide no matter what the child measures.
/// - Flexible dimensions (`nil`, the default) pass the parent's offer through
///   to the child and **fill** a non-`nil` offer — the frame takes all the
///   space the parent is offering — falling back to the child's ideal size
///   when the offer is `nil`. This "fill available space" semantics is what
///   lets a root view center itself in the terminal: the renderer proposes
///   the terminal size, the frame answers it, and the alignment fraction
///   places the content inside it.
/// - Alignment fractions place the child within the assigned rect using the
///   same `Int(Double(shortage) * fraction)` formula as the stacks
///   (``VStack``/``HStack``), with the same `max(0, ...)` guard.
///
/// ## Overflow is not clipped (pinned decision)
///
/// ``frame(width:height:horizontalAlignment:verticalAlignment:)`` does **not**
/// clip. A child whose truthful answer exceeds the frame's fixed size
/// overflows the frame's bounds (SwiftUI-consistent), with the terminal
/// buffer as the final backstop; the `.clipped()` modifier is a phase-3
/// candidate. Shrinking content to fit is the phase-3 wrapping/flex story —
/// a frame is placement, not shrinking.
///
/// ## Known SPI limitation (fit vs render proposal)
///
/// ``View/_render(into:at:size:)`` receives only the assigned size, not the
/// proposal, so a flexible axis cannot reconstruct what the fit pass offered
/// — ``_render(into:at:size:)`` proposes *ideal* on flexible axes instead.
/// With today's proposal-ignoring children (``ViewOutput`` measures unwrapped)
/// this is observationally identical to proposing the offer. A
/// proposal-responsive child (phase-3 wrapping `Text`) inside a flexible-axis
/// frame may need the proposal carried into `_render` — a phase-3 SPI
/// extension candidate (recorded in UPGRADE.md).
///
/// The legacy ``body`` cannot express flexible-fill either: it has no
/// proposal context, so it applies the existing ``ViewOutput/width(_:align:)``
/// / ``ViewOutput/height(_:align:)`` modifiers for **fixed** dimensions only.
/// Flexible-fill exists only in the engine (allowed divergence #4).
public struct FrameView<Content: View>: View {
    /// The fixed width, or `nil` for a flexible width that fills the parent's
    /// offer.
    let width: Int?
    /// The fixed height, or `nil` for a flexible height that fills the
    /// parent's offer.
    let height: Int?
    /// How the content is aligned horizontally within the frame's width.
    /// Defaults to ``HorizontalAlignment/left``.
    let horizontalAlignment: HorizontalAlignment
    /// How the content is aligned vertically within the frame's height.
    /// Defaults to ``VerticalAlignment/top``.
    let verticalAlignment: VerticalAlignment
    /// The content to place within the frame.
    let content: Content

    /// Create a frame around the given content.
    ///
    /// - Parameters:
    ///   - width: The fixed frame width in columns, or `nil` for a flexible
    ///     width that fills the parent's proposal.
    ///   - height: The fixed frame height in rows, or `nil` for a flexible
    ///     height that fills the parent's proposal.
    ///   - horizontalAlignment: How the content is aligned horizontally.
    ///     Defaults to `.left`.
    ///   - verticalAlignment: How the content is aligned vertically.
    ///     Defaults to `.top`.
    ///   - content: A ``ViewBuilder`` closure providing the content.
    public init(
        width: Int? = nil,
        height: Int? = nil,
        horizontalAlignment: HorizontalAlignment = .left,
        verticalAlignment: VerticalAlignment = .top,
        @ViewBuilder content: () -> Content
    ) {
        self.width = width
        self.height = height
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.content = content()
    }

    // MARK: Legacy body (eager path)

    /// The eager resolution path, which has no proposal context.
    ///
    /// Fixed dimensions delegate to the existing ``ViewOutput/width(_:align:)``
    /// and ``ViewOutput/height(_:align:)`` modifiers; a frame with no fixed
    /// dimensions resolves to its content unchanged. Flexible-fill behavior
    /// is impossible here — it exists only in the engine (allowed
    /// divergence #4 in UPGRADE.md).
    public var body: ViewOutput {
        let resolved = content._resolveToViewOutput()
        if let w = width, let h = height {
            return resolved.width(w, align: horizontalAlignment)
                .height(h, align: verticalAlignment)
        }
        if let w = width {
            return resolved.width(w, align: horizontalAlignment)
        }
        if let h = height {
            return resolved.height(h, align: verticalAlignment)
        }
        return resolved
    }
}

// MARK: - FrameView engine implementation
//
// Phase-2 layout engine (UPGRADE.md): the frame is a proposal *generator*.
// `_sizeThatFits` answers fixed dimensions verbatim, fills non-`nil` offers
// on flexible axes, and falls back to the child's ideal when the offer is
// `nil`. `_render` re-measures the child with fixed dimensions constant and
// flexible axes ideal, then places it at the alignment fraction of the
// shortage — mirroring the stacks' `Int(Double(shortage) * fraction)`
// formula and `max(0, ...)` guard. No clipping: a child larger than the
// frame overflows its bounds (the buffer is the backstop).

extension FrameView {
    /// Answer the frame's own size: fixed dimensions verbatim; flexible
    /// dimensions fill a non-`nil` offer, else the child's ideal.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let childSize = content._sizeThatFits(
            ProposedSize(width: width ?? proposal.width, height: height ?? proposal.height)
        )
        return ViewSize(
            width: width ?? (proposal.width ?? childSize.width),
            height: height ?? (proposal.height ?? childSize.height)
        )
    }

    /// Re-measure the child (fixed dims constant, flexible axes ideal), then
    /// place it at the alignment fraction of the shortage per axis.
    ///
    /// A child larger than the frame renders from its alignment offset
    /// (shortage clamped to 0) and overflows the frame's bounds — no
    /// clipping, the buffer is the backstop.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize) {
        let childSize = content._sizeThatFits(ProposedSize(width: width, height: height))
        let colShortage = max(0, size.width - childSize.width)
        let col = origin.col + Int(Double(colShortage) * horizontalAlignment.fraction)
        let rowShortage = max(0, size.height - childSize.height)
        let row = origin.row + Int(Double(rowShortage) * verticalAlignment.fraction)
        content._render(into: &buffer, at: ViewOrigin(col: col, row: row), size: childSize)
    }
}

// MARK: - View.frame modifier

extension View {
    /// Surround this view with a frame of the given size and alignment.
    ///
    /// The frame proposes its fixed dimensions to the content and answers
    /// them to the parent verbatim; flexible dimensions (`nil`) pass the
    /// parent's offer through and fill it. The content is placed within the
    /// assigned rect according to the alignment fractions.
    ///
    /// A frame does **not** clip: content larger than the frame overflows its
    /// bounds, with the terminal buffer as the final backstop.
    ///
    /// ```swift
    /// // Center a small view in the terminal window.
    /// VStack {
    ///     Text("Hello")
    /// }
    /// .frame(
    ///     width: termWidth,
    ///     height: termHeight,
    ///     horizontalAlignment: .center,
    ///     verticalAlignment: .middle
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - width: The fixed frame width in columns, or `nil` for a flexible
    ///     width that fills the parent's proposal.
    ///   - height: The fixed frame height in rows, or `nil` for a flexible
    ///     height that fills the parent's proposal.
    ///   - horizontalAlignment: How the content is aligned horizontally.
    ///     Defaults to `.left`.
    ///   - verticalAlignment: How the content is aligned vertically.
    ///     Defaults to `.top`.
    /// - Returns: A ``FrameView`` wrapping this view.
    public func frame(
        width: Int? = nil,
        height: Int? = nil,
        horizontalAlignment: HorizontalAlignment = .left,
        verticalAlignment: VerticalAlignment = .top
    ) -> FrameView<Self> {
        FrameView(
            width: width,
            height: height,
            horizontalAlignment: horizontalAlignment,
            verticalAlignment: verticalAlignment
        ) { self }
    }
}