// MARK: - View

/// A type that produces visual content for terminal rendering.
///
/// Conform to `View` to create reusable visual components. The ``body``
/// property returns the component's content as another ``View``.
///
/// For interactive applications that handle input and maintain state, see
/// ``Model`` which extends `View` with the Elm Architecture lifecycle.
///
/// ## Example
///
/// ```swift
/// struct Header: View {
///     let title: String
///
///     var body: some View {
///         Text(title.bold())
///     }
/// }
/// ```
public protocol View: Sendable {
    /// The type of view returned by ``body``.
    ///
    /// Engine-implemented views (containers, leaves) declare no body; their
    /// ``Body`` defaults to ``Empty`` and the `body` requirement is satisfied
    /// by the protocol-extension default. User-facing composite views write
    /// `var body: some View { ... }` as usual.
    associatedtype Body: View = Empty

    /// The visual content of this view.
    ///
    /// The declarative description of a user-facing composite view. The
    /// layout engine does **not** resolve `body` to render: it calls
    /// ``_measure(in:)`` and ``_embed(into:at:)``, whose defaults resolve
    /// through `body` for ordinary composites. Views that implement the
    /// engine SPI directly (containers, leaves) may omit `body`; it then
    /// defaults to ``Empty`` (phase 4 removed the eager
    /// `_resolveToViewOutput()` bridge, so `body` is no longer a render path).
    var body: Body { get }

    /// Measure this view's size for the given query context.
    ///
    /// The default resolves through ``body``, so a view whose `body` is a
    /// ``ViewOutput`` leaf (or another view with its own engine overrides)
    /// measures correctly without any extra code.
    ///
    /// **Phase-4 role: a pure query.** The answer is a *report* with no
    /// authority — containers use it for allocation decisions (and buffer
    /// sizing / clip reservation) but may overrule it. Allocation happens in
    /// ``_embed(into:at:)``; the query never binds. See `docs/history/VIEW-LAYER-MIGRATION-LOG.md`, "Phase 4
    /// — Top-down allocation engine".
    ///
    /// - Parameter available: The query context a parent is asking about; see
    ///   ``AvailableSize`` for the meaning of `nil` dimensions.
    /// - Returns: The size this view reports under that context.
    func _measure(in available: AvailableSize) -> ViewSize

    /// Embed this view into the rect its parent assigned.
    ///
    /// This is the **allocation** entrance: `rect` is what the parent decided,
    /// not a value to negotiate. Under the hard-box contract the rect is also
    /// the painting bound: the kernel clips every write in this subtree to it.
    /// The default resolves through ``body``; leaf views rasterize at the
    /// rect's origin, and containers override this with their allocation
    /// rules (children report, parents decide — see `docs/history/VIEW-LAYER-MIGRATION-LOG.md`, "Phase 4 —
    /// Top-down allocation engine").
    ///
    /// - Parameters:
    ///   - buffer: The buffer to draw into.
    ///   - rect: The rect assigned by the parent (origin + size).
    func _embed(into buffer: inout CellBuffer, at rect: ViewRect)

    /// The views a container should treat as this view's children.
    ///
    /// The default returns `[self]`, so an ordinary composite view presents
    /// itself as a single child. Structural views (``TupleView``,
    /// ``ForEachView``, ``ConditionalContent``, ``OptionalView``) override
    /// this and are **transparent** — they flatten their children's
    /// `_childViews()`, enabling containers such as `HStack` to enumerate
    /// individual children for layout.
    func _childViews() -> [any View]

    /// How much leftover main-axis space this view absorbs in a stack.
    ///
    /// SPI: containers query this to distribute leftover space; regular views
    /// are rigid (``LayoutFlexibility/rigid``). A stack that lays out along an
    /// axis with at least one positively-flexible child fills a non-`nil`
    /// main-axis assignment and splits the leftover proportionally between
    /// the flexible children (``Spacer()`` is the ready-made flexible
    /// view). Outside a stack nothing distributes leftover space, so a
    /// flexible view measures as if it were rigid.
    func _flexibility() -> LayoutFlexibility
}

// MARK: - ViewOutput: View

extension ViewOutput: View {
    /// `ViewOutput` is the terminal leaf of the view hierarchy.
    /// Resolution stops here and its ``StyledText`` content is rendered.
    public typealias Body = ViewOutput
    public var body: ViewOutput { self }

    /// The ideal size of the output: `(maxLineWidth, lineCount())`.
    ///
    /// Empty content measures 0×0 because ``StyledText/lineCount()`` already
    /// returns 0 for empty content — an empty output occupies nothing.
    ///
    /// The query context is ignored: a `ViewOutput` is a fully-formed raster. The
    /// ideal size is the unwrapped size; `Text` is the view that wraps at an
    /// allocated width.
    public func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: content.maxLineWidth, height: content.lineCount())
    }

    /// Rasterize the content at the assigned rect's origin.
    ///
    /// A `ViewOutput` is a fully-formed raster: it renders at its intrinsic
    /// size anchored top-left in the rect (leaves do not stretch — the phase-4
    /// decision). The hard-box contract clips the write to the rect, so the
    /// raster can never paint outside its allocation.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        buffer.write(content, at: rect.origin.col, row: rect.origin.row)
    }
}

// MARK: - View resolution

extension View {
    /// The default declares no body: engine-implemented views are their own
    /// render path. A composite view overrides this with `var body: some View`.
    public var body: Empty { Empty() }

    /// The default engine implementation resolves through ``body``.
    public func _measure(in available: AvailableSize) -> ViewSize {
        body._measure(in: available)
    }

    /// The default allocation entrance resolves through ``body``.
    ///
    /// A view whose `body` is a ``ViewOutput`` therefore embeds correctly with
    /// no engine code — the simple path (`body: ViewOutput` + strings) stays
    /// complete and supported (see docs/history/VIEW-LAYER-MIGRATION-LOG.md, "Simple-path contract").
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        body._embed(into: &buffer, at: rect)
    }

    /// The default treats this view as its own single child.
    public func _childViews() -> [any View] {
        [self]
    }

    /// The default is rigid: an ordinary view never absorbs leftover space.
    /// Only flexible views (``Spacer()``) override this.
    public func _flexibility() -> LayoutFlexibility {
        .rigid
    }
}

// MARK: - Text

/// A view that displays styled text.
///
/// ```swift
/// Text("Hello, world!")
/// Text("Error".fg(.red))
/// ```
public struct Text: View {
    private let content: StyledText

    /// Create a text view from a ``StyledText`` value.
    public init(_ content: StyledText) {
        self.content = content
    }

    /// Create a text view from a plain string.
    public init(_ string: String) {
        self.content = StyledText(string)
    }

    public var body: ViewOutput {
        ViewOutput(content)
    }
}

// MARK: - Text engine implementation

extension Text {
    /// The content to measure or paint at a given width context.
    ///
    /// `nil` is ideal (unwrapped). A positive width wraps at
    /// `max(width, minimumWrapWidth())` — the **compression floor** (phase-4
    /// decision 4): the query and the allocation use this SAME rule, so a
    /// report's line count always matches what ``_embed(into:at:)`` paints.
    /// A zero or negative width is the A3 minimum context: the content wraps
    /// to its narrowest producible width (``minimumWrapWidth()``). Empty
    /// content stays empty in every case.
    private func resolvedContent(width: Int?) -> StyledText {
        guard let width else { return content }
        let minimumWidth = minimumWrapWidth()
        if width <= 0 {
            guard minimumWidth > 0 else { return content }
            return content.wrappedToWidth(minimumWidth)
        }
        return content.wrappedToWidth(max(width, minimumWidth))
    }

    /// The narrowest width at which this content can still be produced: the
    /// widest single character in it, or `0` for empty content.
    ///
    /// Wrapping at this width puts every character on a line of its own
    /// (display-width aware), so no character is ever split. ASCII-only
    /// content yields `1`; the presence of any wide/CJK character raises it to
    /// `2`. Non-empty content always yields at least `1` — whitespace-only
    /// content then wraps to empty (0×0), matching the wrapping contract.
    private func minimumWrapWidth() -> Int {
        guard !content.isEmpty else { return 0 }
        var widest = 0
        for segment in content.segments {
            for character in segment.text {
                widest = max(widest, displayWidth(of: character))
            }
        }
        return max(1, widest)
    }

    /// Query-aware measurement: the measured size is the **resolved**
    /// content's `(maxLineWidth, lineCount())` — the wrapped result for a
    /// positive width (floored at the minimum producible width), the minimum
    /// form for a zero or negative width, and the unwrapped ideal for `nil`.
    ///
    /// Measurement and allocation resolve with the SAME function
    /// (``resolvedContent(width:)``), so the report's line count always matches
    /// the painted rows — including the mixed ASCII/wide case where the
    /// minimum floor is wider than the queried width.
    public func _measure(in available: AvailableSize) -> ViewSize {
        let resolved = resolvedContent(width: available.width)
        return ViewSize(width: resolved.maxLineWidth, height: resolved.lineCount())
    }

    /// Render at the allocated width (phase 4): the content wraps at the
    /// width the container decided, with the compression floor applied (see
    /// ``resolvedContent(width:)``). Content taller than the rect is clipped
    /// to the rect (hard-box contract); the buffer is the final backstop.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        buffer.write(
            resolvedContent(width: rect.size.width),
            at: rect.origin.col,
            row: rect.origin.row
        )
    }
}

// MARK: - Spacer

/// A view that produces space in a stack.
///
/// `Spacer()` is the **flexible** spacer (SwiftUI-style): it absorbs a share
/// of the stack's leftover main-axis space after every child's rigid size is
/// accounted for. Two `Spacer()`s split evenly; `Spacer(fraction: 2)` next to
/// `Spacer(fraction: 1)` takes twice the share.
///
/// The fixed variants reserve an exact amount — ``init(lines:)`` blank rows in
/// a `VStack`, ``init(columns:)`` blank columns in an `HStack`:
///
/// ```swift
/// HStack {
///     Text("Left")
///     Spacer()
///     Text("Right")
/// }
///
/// VStack {
///     Text("Top")
///     Spacer(lines: 2)
///     Text("Bottom")
/// }
/// ```
///
/// ## Outside a stack it is empty
///
/// Leftover distribution is a **stack** behavior: only `VStack`/`HStack`
/// query ``View/_flexibility()``. Anywhere else (as a root view, inside a
/// ``FrameView``, ...) nothing distributes leftover space, so a flexible
/// `Spacer()` measures 0×0 and renders nothing — exactly like ``Empty``.
///
/// ## Rigid measurement
///
/// A stack still measures every child *rigidly* before distributing: a
/// flexible spacer answers 0×0 (its flexible axis contributes nothing to the
/// rigid total), and the stack adds its share of the leftover afterwards.
///
/// - Note: A `fraction` that is not positive makes the spacer rigid
///   (``LayoutFlexibility/rigid``), so it behaves exactly like ``Empty``.
public struct Spacer: View {

    /// The spacer's mode: flexible with a share fraction, or a fixed cell
    /// count on one axis.
    private enum Kind: Sendable {
        case flexible(Double)
        case lines(Int)
        case columns(Int)
    }

    private let kind: Kind

    /// Create a flexible spacer (fraction 1): it absorbs a share of the
    /// enclosing stack's leftover main-axis space.
    public init() {
        self.kind = .flexible(1)
    }

    /// Create a flexible spacer with a proportional share.
    ///
    /// - Parameter fraction: This spacer's share of the stack's leftover
    ///   main-axis space, relative to its flexible siblings. A non-positive
    ///   value makes the spacer rigid.
    public init(fraction: Double) {
        self.kind = .flexible(fraction)
    }

    /// Create a vertical spacer that reserves an exact number of blank lines.
    ///
    /// - Parameter lines: The number of blank rows (clamped at 0).
    public init(lines: Int) {
        self.kind = .lines(max(0, lines))
    }

    /// Create a horizontal spacer that reserves an exact number of blank
    /// columns.
    ///
    /// - Parameter columns: The number of blank columns (clamped at 0).
    public init(columns: Int) {
        self.kind = .columns(max(0, columns))
    }
}

// MARK: - Fill

/// A view that claims the rect it is allocated, rendering nothing.
///
/// `Fill` reports the query context verbatim on both axes — it is a
/// *consumer*: its size is undefined without a context. Containers decide the
/// rect it claims (a leading `Fill` in an `HStack` absorbs the remainder; a
/// fixed ``View/frame(width:height:horizontalAlignment:verticalAlignment:)``
/// hands it the frame's box).
///
/// ```swift
/// HStack {
///     Text("x")
///     Fill()
/// }
/// .frame(width: 20, height: 3)
/// ```
///
/// A `nil` query dimension is ideal, not a context, so `Fill` reports 0 on
/// that axis: outside any non-`nil` context it is 0×0 (like ``Empty``).
public struct Fill: View {
    public init() {}
}

// MARK: - Fill engine implementation

extension Fill {
    /// Report the query context on both axes: `(available.width ?? 0, available.height ?? 0)`.
    /// A `nil` dimension is ideal, not a context, so it reports 0 there.
    public func _measure(in available: AvailableSize) -> ViewSize {
        ViewSize(width: available.width ?? 0, height: available.height ?? 0)
    }

    /// `Fill` claims exactly the rect it is allocated: the container's
    /// decision defines it, and the claim is a no-op paint. As a *consumer*,
    /// `Fill` has no intrinsic size — its report answers the query context,
    /// and containers allocate it the rect they decide on (see the HStack
    /// remainder rule in `Stacks.swift`).
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        // Blank cells are the buffer's default fill; nothing to draw.
    }
}

// MARK: - Empty

/// A view that produces no visible content.
///
/// Useful as a placeholder or in conditional branches:
///
/// ```swift
/// if showHelp {
///     helpView
/// } else {
///     Empty()
/// }
/// ```
public struct Empty: View {
    public init() {}
}

// MARK: - Empty engine implementation
//
// `Empty` is also the default `View.Body`: a conformer that declares neither a
// body nor engine methods inherits `var body: Empty`, whose defaults resolve
// through `body` → this view. Overriding both engine methods here terminates
// that resolution (an accidental body-less view is a 0×0 no-op, never a
// recursion).

extension Empty {
    /// Empty occupies no space under any query context.
    public func _measure(in available: AvailableSize) -> ViewSize {
        .zero
    }

    /// Empty paints nothing.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        // Nothing to draw.
    }
}

// MARK: - Spacer engine implementation

extension Spacer {
    /// Flexible spacers measure 0×0: their share is decided by the stack and
    /// added to the allocation afterwards. Fixed spacers measure exactly the
    /// cells they request: `(columns, 1)` for a horizontal spacer and
    /// `(0, lines)` for a vertical one; a zero-count fixed spacer is 0×0.
    ///
    /// The query context is ignored: a spacer's size is explicit, never context-dependent.
    public func _measure(in available: AvailableSize) -> ViewSize {
        switch kind {
        case .flexible:
            return .zero
        case .lines(let lines):
            return lines > 0 ? ViewSize(width: 0, height: lines) : .zero
        case .columns(let columns):
            return columns > 0 ? ViewSize(width: columns, height: 1) : .zero
        }
    }

    /// A spacer claims its allocated rect by painting nothing: the cells are
    /// already blank, so the rect is occupied without a write.
    public func _embed(into buffer: inout CellBuffer, at rect: ViewRect) {
        // Blank cells are the buffer's default fill; nothing to draw.
    }

    /// A flexible spacer reports its fraction on both axes: a stack consults
    /// only the axis it lays out along (`HStack`: width; `VStack`: height).
    /// Fixed spacers and non-positive fractions are rigid.
    public func _flexibility() -> LayoutFlexibility {
        guard case .flexible(let fraction) = kind,
              fraction > 0,
              fraction.isFinite
        else {
            return .rigid
        }
        return LayoutFlexibility(width: fraction, height: fraction)
    }
}
