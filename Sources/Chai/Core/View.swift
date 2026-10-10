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

    /// Collect the resolved ``ViewOutput`` for each direct child.
    ///
    /// The default returns a single-element array containing this view's
    /// fully-resolved output. Structural views (``TupleView``,
    /// ``ForEachView``) override this to return one element per child,
    /// enabling containers such as `HStack` to enumerate children for
    /// layout.
    func _collectChildOutputs() -> [ViewOutput]
}

// MARK: - ViewOutput: View

extension ViewOutput: View {
    /// `ViewOutput` is the terminal leaf of the view hierarchy.
    /// Resolution stops here and its ``StyledText`` content is rendered.
    public typealias Body = ViewOutput
    public var body: ViewOutput { self }
}

// MARK: - View resolution

extension View {
    /// Resolve this view tree to a ``ViewOutput`` by recursively calling
    /// ``body`` until a ``ViewOutput`` leaf is reached.
    ///
    /// This is the bridge between the declarative view tree and the eager
    /// styled-text renderer. A future layout engine will resolve the tree
    /// through measurement and incremental rendering instead; see
    /// `UPGRADE.md`.
    public func _resolveToViewOutput() -> ViewOutput {
        if let output = self as? ViewOutput {
            return output
        }
        return body._resolveToViewOutput()
    }

    public func _collectChildOutputs() -> [ViewOutput] {
        [_resolveToViewOutput()]
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
