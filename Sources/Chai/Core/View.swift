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
    /// at `origin` honoring that assigned size.
    ///
    /// - Parameters:
    ///   - buffer: The buffer to draw into.
    ///   - origin: The top-left position to draw at.
    ///   - size: The size assigned to this view by its parent.
    func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize)

    /// The views a container should treat as this view's children.
    ///
    /// The default returns `[self]`, so an ordinary composite view presents
    /// itself as a single child. Structural views (``TupleView``,
    /// ``ForEachView``, ``ConditionalContent``, ``OptionalView``) override
    /// this and are **transparent** — they flatten their children's
    /// `_childViews()`, enabling containers such as `HStack` to enumerate
    /// individual children for layout.
    func _childViews() -> [any View]
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
    /// `wrapping: false` matches today's eager/inline parity semantics
    /// (truncate at the buffer's right edge instead of stealing rows). The
    /// phase-2 renderer milestone (M3) introduces a buffer-level
    /// wrap-vs-truncate write policy; this call will follow that policy then.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize) {
        buffer.write(content, at: origin.col, row: origin.row, wrapping: false)
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

    /// The default engine implementation resolves through ``body``.
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize) {
        body._render(into: &buffer, at: origin, size: size)
    }

    /// The default treats this view as its own single child.
    public func _childViews() -> [any View] {
        [self]
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
    public func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize) {
        // Blank cells are the buffer's default fill; nothing to draw.
    }
}
