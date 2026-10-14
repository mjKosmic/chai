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
    associatedtype Body: View

    /// The visual content of this view.
    var body: Body { get }

    /// Measure this view's size for the given proposal.
    ///
    /// The default resolves through ``body``, so a view whose `body` is a
    /// ``ViewOutput`` leaf (or another view with its own engine overrides)
    /// measures correctly without any extra code.
    ///
    /// - Parameter proposal: The size a parent is offering; see
    ///   ``ProposedSize`` for the meaning of `nil` dimensions.
    /// - Returns: The size this view would take under the proposal.
    func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize

    /// Render this view into a cell buffer.
    ///
    /// The default resolves through ``body``. `size` is the concrete size
    /// assigned by the parent after measurement; the view places its content
    /// at `origin` honoring that assigned size. `proposal` is the proposal
    /// this view was measured with in the fit pass — containers must forward
    /// it unchanged so proposal-consuming children measure and render
    /// identically (the fit/render value-equality contract; see
    /// ARCHITECTURE.md "Fit/render consistency").
    ///
    /// - Parameters:
    ///   - buffer: The buffer to draw into.
    ///   - origin: The top-left position to draw at.
    ///   - size: The size assigned to this view by its parent.
    ///   - proposal: The proposal used to measure this view in the fit pass.
    func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize)

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
    /// proposal on that axis and splits the leftover proportionally between
    /// the flexible children (``FlexibleSpacer`` is the ready-made flexible
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
    /// returns 0 for empty content — so an empty output occupies nothing,
    /// which is what the eager join semantics assumed all along.
    ///
    /// Proposals are ignored: a `ViewOutput` is a fully-formed raster; the
    /// layout engine measures it unwrapped (proposal-aware `Text` wrapping is
    /// a phase-3 candidate). The ideal size is the unwrapped size.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        ViewSize(width: content.maxLineWidth, height: content.lineCount())
    }

    /// Rasterize the output's content into the buffer.
    ///
    /// The write follows the buffer's wrap-vs-truncate policy
    /// (``CellBuffer/init(width:height:fill:wrapping:)``): inline-mode buffers
    /// truncate at the right edge, alt-screen buffers wrap. The mode decision
    /// stays renderer-level while the leaf SPI stays free of mode flags.
    ///
    /// A `ViewOutput` is a fully-formed raster: the proposal is ignored.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        buffer.write(content, at: origin.col, row: origin.row)
    }
}

// MARK: - View resolution

extension View {
    /// Resolve this view tree to a ``ViewOutput`` by recursively calling
    /// ``body`` until a ``ViewOutput`` leaf is reached.
    ///
    /// This is the bridge between the declarative view tree and the eager
    /// styled-text renderer. The layout engine resolves the tree through
    /// measurement and incremental rendering instead; see `UPGRADE.md`.
    public func _resolveToViewOutput() -> ViewOutput {
        if let output = self as? ViewOutput {
            return output
        }
        return body._resolveToViewOutput()
    }

    /// The default engine implementation resolves through ``body``.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        body._sizeThatFits(proposal)
    }

    /// The default engine implementation resolves through ``body``,
    /// forwarding the proposal along.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        body._render(into: &buffer, at: origin, size: size, proposal: proposal)
    }

    /// The default treats this view as its own single child.
    public func _childViews() -> [any View] {
        [self]
    }

    /// The default is rigid: an ordinary view never absorbs leftover space.
    /// Only flexible views (``FlexibleSpacer``) override this.
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
    /// The content to measure and write for a given proposal.
    ///
    /// Fit and render both resolve through this single function, so the two
    /// passes agree by construction — the A0 fit/render value-equality
    /// contract holds for `Text` without the render pass re-deriving anything.
    ///
    /// - `nil` width is ideal: the content is returned unwrapped.
    /// - A positive width wraps the content to that width
    ///   (``StyledText/wrappedToWidth(_:)``).
    /// - A **zero or negative** width is the *minimum offer* (one rule; a
    ///   negative offer clamps to zero): the content wraps to its narrowest
    ///   producible width — ``minimumWrapWidth()``. This is the phase-3 A3
    ///   minimum semantics (``ProposedSize/zero``); it replaces A1's
    ///   "non-positive → unwrapped" behavior.
    private func resolvedContent(for proposal: ProposedSize) -> StyledText {
        guard let width = proposal.width else { return content }
        if width > 0 { return content.wrappedToWidth(width) }
        let minimumWidth = minimumWrapWidth()
        guard minimumWidth > 0 else { return content }
        return content.wrappedToWidth(minimumWidth)
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

    /// Proposal-aware measurement (phase-3 A1, extended in A3): the measured
    /// size is the **resolved** content's `(maxLineWidth, lineCount())` — the
    /// wrapped result for a positive width, the minimum form for a zero or
    /// negative width, and the unwrapped ideal for `nil`.
    ///
    /// Measurement and rendering resolve with the SAME function
    /// (``resolvedContent(for:)``), so the two passes agree by construction.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        let resolved = resolvedContent(for: proposal)
        return ViewSize(width: resolved.maxLineWidth, height: resolved.lineCount())
    }

    /// Proposal-aware rendering (phase-3 A1, extended in A3): writes the
    /// **resolved** content — the wrapped form for a positive width, the
    /// minimum form for a zero or negative width, the unwrapped content for
    /// `nil`. The write follows the buffer's wrap-vs-truncate policy at the
    /// right edge, so a degenerate line wider than the resolved width (e.g. a
    /// single CJK character) is clipped by the buffer.
    ///
    /// The resolved content is computed exactly once per pass and never
    /// cached: the fit pass measured the same value, so the render is
    /// consistent by construction (see ``_sizeThatFits(_:)``).
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        buffer.write(resolvedContent(for: proposal), at: origin.col, row: origin.row)
    }
}

// MARK: - Spacer

/// A view that produces empty space.
///
/// In a vertical context, produces blank lines. In a horizontal context,
/// produces space characters.
///
/// - Note: Inside an `HStack`, use `Spacer(columns:)` — a line-based spacer
///   produces newline characters, which have no horizontal width and are
///   ignored during horizontal joins.
///
/// ```swift
/// VStack {
///     Text("Top")
///     Spacer(lines: 2)
///     Text("Bottom")
/// }
/// ```
public struct Spacer: View {
    private let lines: Int
    private let columns: Int

    /// Create a vertical spacer with the given number of blank lines.
    public init(lines: Int = 1) {
        self.lines = max(0, lines)
        self.columns = 0
    }

    /// Create a horizontal spacer with the given number of space columns.
    public init(columns: Int) {
        self.lines = 0
        self.columns = max(0, columns)
    }

    public var body: ViewOutput {
        if columns > 0 {
            return ViewOutput(String(repeating: " ", count: columns))
        }
        if lines > 0 {
            return ViewOutput(String(repeating: "\n", count: lines))
        }
        return ViewOutput("")
    }
}

// MARK: - FlexibleSpacer

/// A view that absorbs a share of a stack's leftover main-axis space.
///
/// Unlike ``Spacer``, which occupies a *fixed* number of blank lines or
/// columns, a `FlexibleSpacer` takes a proportional share of the space the
/// enclosing stack has left over after every child's rigid size is
/// accounted for. Two `FlexibleSpacer()`s split evenly; a
/// `FlexibleSpacer(fraction: 2)` next to a `FlexibleSpacer(fraction: 1)`
/// takes twice the space.
///
/// ```swift
/// HStack {
///     Text("Left")
///     FlexibleSpacer()
///     Text("Right")
/// }
/// ```
///
/// ## Outside a stack it is empty
///
/// Leftover distribution is a **stack** behavior: only `VStack`/`HStack`
/// query ``View/_flexibility()``. Anywhere else (as a root view, inside a
/// ``FrameView``, ...) nothing distributes leftover space, so a
/// `FlexibleSpacer` measures 0×0 and renders nothing — exactly like
/// ``Empty``.
///
/// ## Rigid measurement
///
/// A stack still measures every child *rigidly* before distributing: a
/// `FlexibleSpacer` answers 0×0 (its flexible axis contributes nothing to the
/// rigid total), and the stack adds its share of the leftover afterwards.
///
/// - Note: A `fraction` that is not positive makes the spacer rigid
///   (``LayoutFlexibility/rigid``), so it behaves exactly like ``Empty``.
public struct FlexibleSpacer: View {
    private let fraction: Double

    /// Create a flexible spacer.
    ///
    /// - Parameter fraction: This spacer's share of the stack's leftover
    ///   main-axis space, relative to its flexible siblings. Defaults to `1`.
    ///   A non-positive value makes the spacer rigid.
    public init(fraction: Double = 1) {
        self.fraction = fraction
    }

    /// The eager path has no proposal context and no stack to distribute
    /// leftover space, so the spacer resolves to empty content — an enclosing
    /// eager join skips it (allowed divergence #7 in UPGRADE.md).
    public var body: ViewOutput {
        ViewOutput("")
    }
}

// MARK: - FlexibleSpacer engine implementation

extension FlexibleSpacer {
    /// Rigid measurement is 0×0: the spacer's contribution to a stack's rigid
    /// total is nothing; the stack adds the distributed leftover to this size
    /// (see ``VStack``/``HStack``). Outside a stack, that distribution never
    /// happens, so the spacer measures 0×0. The proposal is ignored.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        .zero
    }

    /// Rendering a spacer is a no-op: blank cells are the buffer default.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        // Blank cells are the buffer's default fill; nothing to draw.
    }

    /// Both axes report the fraction: a stack consults only the axis it lays
    /// out along (`HStack`: width; `VStack`: height). A non-positive fraction
    /// is rigid.
    public func _flexibility() -> LayoutFlexibility {
        guard fraction > 0 else { return .rigid }
        return LayoutFlexibility(width: fraction, height: fraction)
    }
}

// MARK: - Fill

/// A view that occupies exactly the space it is offered, rendering nothing.
///
/// `Fill` answers the proposal verbatim on both axes — it is a *consumer*:
/// its size is undefined without an offer. Use it as a blank filler inside a
/// fixed ``View/frame(width:height:horizontalAlignment:verticalAlignment:)``,
/// or anywhere a view should claim the full offered rect while painting
/// nothing.
///
/// ```swift
/// HStack {
///     Text("x")
///     Fill()
/// }
/// .frame(width: 20, height: 3)
/// ```
///
/// A `nil` proposal dimension is not an offer, so `Fill` reports 0 on that
/// axis: outside any non-`nil` proposal it is 0×0 (like ``Empty``).
public struct Fill: View {
    public init() {}

    /// The eager path has no proposal context, so `Fill` resolves to empty
    /// content. It claims space only in the engine.
    public var body: ViewOutput {
        ViewOutput("")
    }
}

// MARK: - Fill engine implementation

extension Fill {
    /// Answer the offer on both axes: `(proposal.width ?? 0, proposal.height ?? 0)`.
    /// A `nil` dimension is ideal, not an offer, so it reports 0 there.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        ViewSize(width: proposal.width ?? 0, height: proposal.height ?? 0)
    }

    /// Filling is invisible: the cells it claims are the buffer's blank
    /// default, so there is nothing to draw.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
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

    public var body: ViewOutput {
        ViewOutput("")
    }
}

// MARK: - Spacer engine implementation

extension Spacer {
    /// A spacer measures its requested blank space: `(columns, 1)` for a
    /// horizontal spacer, `(0, lines)` for a vertical one, and `.zero` when
    /// both dimensions are zero (e.g. `Spacer(columns: 0)`).
    ///
    /// This is the fix for the eager measurement quirk where `Spacer(lines: 2)`
    /// resolves to a `"\n\n"` body that `lineCount()` miscounts as 3 lines.
    /// The engine measures the requested count directly. Note `Spacer()` is
    /// `Spacer(lines: 1)` — one blank line.
    public func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize {
        if columns > 0 {
            return ViewSize(width: columns, height: 1)
        }
        if lines > 0 {
            return ViewSize(width: 0, height: lines)
        }
        return .zero
    }

    /// Rendering a spacer is a no-op: blank cells are the buffer default.
    /// The proposal is ignored.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize) {
        // Blank cells are the buffer's default fill; nothing to draw.
    }
}
