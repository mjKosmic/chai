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
/// ## Overflow is clipped (hard-box contract)
///
/// The frame is a hard box: its fixed dimensions are its painting bounds. A
/// child that reports larger than the box is clipped to it by the allocation
/// kernel, and the frame itself is clamped to the rect its parent assigned.
/// Shrinking content to fit is still the wrapping/flex story — a frame is a
/// box, not a reflow instruction — but nothing paints outside it.
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
    ///     width that fills the parent's assignment.
    ///   - height: The fixed frame height in rows, or `nil` for a flexible
    ///     height that fills the parent's assignment.
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
        self.width = width.map { max(0, $0) }
        self.height = height.map { max(0, $0) }
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.content = content()
    }
}

// MARK: - FrameView engine implementation
//
// Phase 4: fixed dimensions are ALLOCATION data — the frame owns them and
// allocates the child box verbatim; flexible dimensions pass the assigned rect
// through. `_measure` remains the pure query (fixed dims verbatim;
// flexible axes fill a non-`nil` offer, else the child's ideal). Placement is
// the alignment fraction of the shortage on each axis
// (`Int(Double(shortage) * fraction)`). Hard-box contract: the box is clamped
// to the allocation and the child is clipped to the box.

extension FrameView {
    /// Answer the frame's own size: fixed dimensions verbatim; flexible
    /// dimensions fill a non-`nil` offer, else the child's ideal.
    public func _measure(in available: AvailableSize) -> ViewSize {
        let childSize = content._measure(in: 
            AvailableSize(width: width ?? available.width, height: height ?? available.height)
        )
        return ViewSize(
            width: width ?? (available.width ?? childSize.width),
            height: height ?? (available.height ?? childSize.height)
        )
    }

    /// Allocate the content inside the frame's rect.
    ///
    /// Fixed dimensions are **allocation data**: the frame owns them verbatim
    /// and allocates the child the same fixed box, so the phase-3
    /// `width ?? proposal` reconstruction is gone.
    /// Flexible dimensions pass the parent's assignment through.
    ///
    /// The child is measured with the frame's visible box as its query
    /// context — a fixed height reaches a height-flexible child — then
    /// clamped to the box and anchored at the alignment fraction of the
    /// shortage per axis. Nothing paints outside the box.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        // The frame's box: fixed dimensions are owned verbatim; flexible axes
        // are the parent's assignment. Under the hard-box contract the box is
        // additionally clamped to the allocation, so a frame that is handed
        // less than it declared cannot paint outside.
        let declared = ViewSize(
            width: width ?? rect.size.width,
            height: height ?? rect.size.height
        )
        let box = ViewRect(origin: rect.origin, size: declared).intersection(rect)
        guard !box.isEmpty else { return }

        let childProposal = AvailableSize(width: box.size.width, height: box.size.height)
        let reported = content._measure(in: childProposal)
        let childSize = ViewSize(
            width: min(reported.width, box.size.width),
            height: min(reported.height, box.size.height)
        )

        let colShortage = max(0, box.size.width - childSize.width)
        let col = box.origin.col + Int(Double(colShortage) * horizontalAlignment.fraction)
        let rowShortage = max(0, box.size.height - childSize.height)
        let row = box.origin.row + Int(Double(rowShortage) * verticalAlignment.fraction)
        let childRect = ViewRect(
            origin: ViewOrigin(col: col, row: row),
            size: childSize
        ).intersection(box)

        if !childRect.isEmpty {
            buffer.embed(content, at: childRect)
        }
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
    /// The frame is a **hard box**: content larger than the frame is clipped
    /// to it (the hard-box contract), and the frame itself is clamped to the
    /// rect its parent assigned.
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
    ///     width that fills the parent's assignment.
    ///   - height: The fixed frame height in rows, or `nil` for a flexible
    ///     height that fills the parent's assignment.
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