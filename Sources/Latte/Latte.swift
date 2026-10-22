/// Latte — Terminal layout and styling library for Swift.
///
/// Latte provides composable, string-based layout primitives and ANSI text
/// styling for building terminal UIs. It is framework-agnostic: functions
/// accept and return plain `String` values, so they work with any TUI
/// framework (or no framework at all).
///
/// ## Core concepts
///
/// All layout is performed on regular strings that may contain ANSI escape
/// sequences. Every measurement operation uses ``visibleWidth(of:)`` to count
/// only printable terminal columns, so styled text (bold, colored, etc.) is
/// handled transparently.
///
/// ## Styling
///
/// ``Style`` is a composable value type that builds ANSI SGR sequences for
/// colors and text attributes. ``Color`` supports ANSI 16, extended 256-color,
/// and 24-bit true color, with automatic downsampling to match the connected
/// terminal via ``ColorProfile``.
///
/// ```swift
/// let warning = Style().foreground(.ansi(.yellow)).bold()
/// let output  = warning.render("Caution!")
/// // → \e[33;1mCaution!\e[0m
///
/// // Auto-detect terminal capability and downsample colors automatically
/// let profile = ColorProfile.detect()
/// let safe    = warning.render("Caution!", profile: profile)
///
/// // Strip all styling for piped / file output
/// let plain   = warning.render("Caution!", profile: .noColor)  // "Caution!"
/// ```
///
/// ## Typical usage
///
/// Latte offers two equivalent calling styles — free functions and chainable
/// String extensions — so you can choose whichever reads best:
///
/// ```swift
/// import Latte
///
/// // Free-function style (inside-out)
/// let panel = border(pad(align("Groceries", width: 20, .center),
///                        top: 1, right: 2, bottom: 1, left: 2), .rounded)
///
/// // Chainable style (left-to-right)
/// let panel = "Groceries"
///     .aligned(width: 20, .center)
///     .padded(1, 2)
///     .bordered(.rounded)
///
/// // Side-by-side columns
/// let left  = border("Column A\nItem 1\nItem 2", .normal)
/// let right = border("Column B\nItem 3\nItem 4", .normal)
/// let layout = joinHorizontal(.top, left, right)
/// ```
///
/// ## Styled borders
///
/// Pass a ``Style`` directly to any border parameter — no closures needed:
///
/// ```swift
/// let cyan = Style().foreground(.ansi(.cyan))
/// let red  = Style().foreground(.ansi(.red))
/// let blue = Style().foreground(.ansi(.blue))
///
/// // Uniform border color
/// border("text", .rounded, borderStyle: cyan)
///
/// // Per-side styling
/// border("text", .rounded, topStyle: red, bottomStyle: blue)
///
/// // Chainable
/// "text".bordered(.rounded, borderStyle: cyan)
/// ```
///
/// ## Module organisation
///
/// | Group | Types / Functions |
/// |---|---|
/// | **Styling** | ``Style``, ``Color``, ``ANSIColor``, ``ColorProfile`` |
/// | **Measurement** | ``visibleWidth(of:)``, ``height(of:)``, ``size(of:)``, ``truncateToVisibleWidth(_:maxWidth:)`` |
/// | **Alignment** | ``align(_:width:_:)`` |
/// | **Padding** | ``pad(_:top:right:bottom:left:fill:)`` and shorthand overloads |
/// | **Margin** | ``margin(_:top:right:bottom:left:fill:)`` and shorthand overloads |
/// | **Size** | ``enforceWidth(_:_:alignment:)``, ``enforceHeight(_:_:alignment:)``, ``clampWidth(_:_:)``, ``clampHeight(_:_:)``, ``clamp(_:maxWidth:maxHeight:)`` |
/// | **Borders** | ``border(_:_:top:right:bottom:left:borderStyle:topStyle:bottomStyle:leftStyle:rightStyle:)``, ``Border`` |
/// | **Utilities** | ``expandTabs(_:tabWidth:)``, ``inline(_:)``, ``wrap(_:width:breakCharacter:)`` |
/// | **Composition** | ``joinHorizontal(_:_:)-5h7fk``, ``joinVertical(_:_:)-3zco8`` |
/// | **String Extensions** | Chainable versions of all the above: `.padded()`, `.bordered()`, `.margined()`, `.aligned()`, `.enforced()`, `.clamped()`, `.truncated()`, `.tabsExpanded()`, `.inlined()`, `.wrapped()` |
/// | **View Modifiers** | Tree-based layout: `.padded()`, `.margined()`, `.bordered()`, `.frame()`, `.beside()`, `.above()` |
/// | **ViewOutput Extensions** | Raster helpers: `.clampedWidth()`, `.clampedHeight()` |
public enum Latte {}
