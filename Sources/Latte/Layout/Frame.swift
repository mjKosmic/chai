import Chai

// MARK: - FrameView

/// A view that assigns a fixed (or flexible) frame size to its content and
/// aligns the content within that rect.
///
/// ``frame(width:height:horizontalAlignment:verticalAlignment:)`` is the
/// phase-2 acceptance feature, re-expressed in phase 4 as an **allocator**
/// (UPGRADE.md, "Phase 4"): a fixed dimension is an allocation decision the
/// frame owns and hands down; a flexible dimension passes the parent's
/// assignment through.
///
/// ## Frame is an allocator
///
/// - Fixed dimensions (non-`nil` `width`/`height`) are **allocation data**: the
///   frame owns them and allocates the child that fixed box — `frame(width:
///   40)` is 40 columns wide no matter what the child measures.
/// - Flexible dimensions (`nil`, the default) pass the assigned rect through
///   to the child and keep it — the frame fills the space its parent assigned —
///   falling back to the child's report when the assignment is degenerate.
///   This "fill available space" semantics is what lets a root view center
///   itself in the terminal: the renderer assigns the terminal width, the
///   frame keeps it, and the alignment fraction places the content inside it.
/// - Alignment fractions place the child within the frame's occupied rect
///   using the same `Int(Double(shortage) * fraction)` formula as the stacks
///   (``VStack``/``HStack``), with the same `max(0, ...)` guard.
///
/// ## Overflow is not clipped (pinned decision)
///
/// ``frame(width:height:horizontalAlignment:verticalAlignment:)`` does **not**
/// clip. A child whose truthful answer exceeds the frame's fixed size
/// overflows the frame's bounds (SwiftUI-consistent), with the terminal
/// buffer as the final backstop; ``View/clipped()`` is the opt-in that masks
/// that overflow. Shrinking content to fit is the wrapping/flex story — a
/// frame is placement, not shrinking.
///
/// The legacy ``body`` cannot express flexible-fill: it has no assignment, so
/// it applies the existing ``ViewOutput/width(_:align:)`` /
/// ``ViewOutput/height(_:align:)`` modifiers for **fixed** dimensions only.
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
// Phase 4: fixed dimensions are ALLOCATION data — the frame owns them and
// allocates the child box verbatim; flexible dimensions pass the assigned rect
// through, floored by the child's report. `_sizeThatFits` remains the pure
// query (fixed dims verbatim; flexible axes fill a non-`nil` offer, else the
// child's ideal). Placement is the alignment fraction of the shortage on each
// axis (`Int(Double(shortage) * fraction)`). No clipping: a child larger than
// the frame overflows its bounds (the buffer is the backstop; `.clipped()` is
// the opt-in).

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

    /// Allocate the content inside the frame's rect.
    ///
    /// Fixed dimensions are **allocation data**: the frame owns them verbatim
    /// and allocates the child the same fixed box, so the `width ?? proposal`
    /// reconstruction and proposal echoing of the phase-3 engine are gone.
    /// Flexible dimensions pass the parent's assignment through.
    ///
    /// The child is measured with the frame's own box as its query context —
    /// a fixed height reaches a height-flexible child, matching the phase-3
    /// fit proposal — then anchored at the alignment fraction of the shortage
    /// per axis. Overflow is unmasked (`.clipped()` remains the opt-in).
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        let childProposal = ProposedSize(
            width: width ?? rect.size.width,
            height: height ?? rect.size.height
        )
        let childSize = content._sizeThatFits(childProposal)
        // The frame's occupied rect is its allocation: fixed dimensions are
        // owned verbatim; flexible axes are the parent's assignment. A child
        // larger than the frame renders from the alignment offset with the
        // shortage clamped to 0 and overflows visibly (no clip).
        let occupied = ViewSize(
            width: width ?? rect.size.width,
            height: height ?? rect.size.height
        )
        let colShortage = max(0, occupied.width - childSize.width)
        let col = rect.origin.col + Int(Double(colShortage) * horizontalAlignment.fraction)
        let rowShortage = max(0, occupied.height - childSize.height)
        let row = rect.origin.row + Int(Double(rowShortage) * verticalAlignment.fraction)
        content._embed(
            into: &buffer,
            at: ViewRect(origin: ViewOrigin(col: col, row: row), size: childSize)
        )
    }
}

// MARK: - View.frame modifier

extension View {
    /// Surround this view with a frame of the given size and alignment.
    ///
    /// The frame owns its fixed dimensions and allocates them to the content;
    /// flexible dimensions (`nil`) pass the parent's assignment through. The
    /// content is placed within the frame's rect according to the alignment
    /// fractions.
    ///
    /// A frame does **not** clip: content larger than the frame overflows its
    /// bounds, with the terminal buffer as the final backstop. Use
    /// ``View/clipped()`` to mask that overflow.
    ///
    /// - Note: On a ``ViewOutput`` receiver, calling `frame(width:height:)`
    ///   with **both** dimensions resolves to the pre-existing eager
    ///   `ViewOutput.frame` overload (minimum-enforcing, returns `ViewOutput`)
    ///   rather than this one — width-only calls, or any non-`ViewOutput`
    ///   receiver, use this tree-based frame. The eager overload is retired
    ///   in Stage C (UPGRADE.md), which removes the ambiguity.
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