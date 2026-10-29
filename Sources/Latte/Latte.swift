/// Latte — terminal layout and styling for Chai.
///
/// Latte provides composable styling values and the declarative containers
/// that render through Chai's allocation engine. Layout is expressed as a
/// view tree: every leaf, container, and modifier participates in
/// measurement and allocation.
///
/// ## Styling
///
/// ``Style`` is a composable value that describes colors and text attributes.
/// ``Color`` supports ANSI 16, extended 256-color, and 24-bit true color, with
/// downsampling through ``ColorProfile``.
///
/// ```swift
/// let warning = Style().foreground(.ansi(.yellow)).bold()
/// Text(warning.styledText("Caution!"))
/// ```
///
/// ``Style/textAttributes`` carries styling as structured values for the
/// cell-buffer renderer. ``Style/render(_:profile:)`` produces an ANSI string
/// for output written outside the live view, such as
/// ``Chai/Command/println(_:)``.
///
/// ## Composition
///
/// ```swift
/// VStack {
///     Text("Groceries".bold())
///     HStack {
///         Text("milk")
///         Spacer()
///         Text("2")
///     }
/// }
/// .padded(1)
/// .bordered(
///     .rounded,
///     borderStyle: Style().foreground(.ansi(.cyan))
/// )
/// .frame(width: 40, horizontalAlignment: .center)
/// ```
///
/// Containers shrink-wrap their content. Use ``View/frame(width:height:horizontalAlignment:verticalAlignment:)``
/// to opt into a fixed allocation, and ``Spacer`` or ``Fill`` to absorb
/// leftover space. Content larger than its allocated rect is clipped to it.
///
/// ## Styled borders
///
/// Border glyphs accept the same styling values as text. A shared
/// `borderStyle` applies to every edge; per-side styles override it, and
/// corners inherit their horizontal edge's style:
///
/// ```swift
/// let cyan = Style().foreground(.ansi(.cyan))
/// let red  = Style().foreground(.ansi(.red))
///
/// Text("text").bordered(.rounded, borderStyle: cyan)
/// Text("text").bordered(.normal, topStyle: red, bottomStyle: cyan)
/// ```
///
/// ## Tab expansion
///
/// Tabs have no display width and are skipped by the cell renderer, so
/// tab-indented text must be expanded before it enters a view:
///
/// ```swift
/// Text(expandTabs("\\tindented"))
/// // or
/// Text("\\tindented".tabsExpanded())
/// ```
///
/// ## Module organisation
///
/// | Group | Types / Functions |
/// |---|---|
/// | **Styling** | ``Style``, ``Color``, ``ANSIColor``, ``ColorProfile`` |
/// | **Containers** | ``VStack``, ``HStack``, ``FrameView`` |
/// | **Modifiers** | `.padded`, `.margined`, `.bordered`, `.frame`, `.beside`, `.above` |
/// | **Borders** | ``Border`` and its presets |
/// | **Text utilities** | ``expandTabs(_:tabWidth:)``, ``String/tabsExpanded(tabWidth:)`` |
///
/// Raster clamping for finished content lives in Chai on ``Chai/ViewOutput``
/// as `clampedWidth(_:)` and `clampedHeight(_:)`.
public enum Latte {}
