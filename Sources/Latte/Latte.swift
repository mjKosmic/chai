/// Latte — Terminal layout library for Swift.
///
/// Latte provides composable, string-based layout primitives for building
/// terminal UIs. It is framework-agnostic: functions accept plain `String`
/// values and return plain `String` values, so they work with any TUI
/// framework (or no framework at all).
///
/// ## Core concepts
///
/// All layout is performed on regular strings that may contain ANSI escape
/// sequences. Every measurement operation uses ``visibleWidth(of:)`` to count
/// only printable terminal columns, so styled text (bold, colored, etc.) is
/// handled transparently.
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
/// Border characters can be styled with closures, keeping Latte free of
/// any dependency on Spices or any other styling library:
///
/// ```swift
/// // Latte-only: raw ANSI escape codes
/// border("text", .rounded, borderStyle: { "\u{1B}[36m\($0)\u{1B}[0m" })
///
/// // With Spices (import Spices) — Style.render(_:) is (String) -> String
/// import Spices
/// let cyan = Style().foreground(.ansi(.cyan))
/// border("text", .rounded, borderStyle: cyan.render)
///
/// // Per-side styling (top = red, bottom = blue)
/// "text".bordered(.rounded,
///     topStyle:    { "\u{1B}[31m\($0)\u{1B}[0m" },
///     bottomStyle: { "\u{1B}[34m\($0)\u{1B}[0m" })
/// ```
///
/// ## Module organisation
///
/// | Group | Functions |
/// |---|---|
/// | **Measurement** | ``visibleWidth(of:)``, ``height(of:)``, ``size(of:)``, ``truncateToVisibleWidth(_:maxWidth:)`` |
/// | **Alignment** | ``align(_:width:_:)`` |
/// | **Padding** | ``pad(_:top:right:bottom:left:)`` (and variants with ``fill:``), ``pad(_:_:)``, ``pad(_:_:_:)``, ``pad(_:_:_:_:)`` |
/// | **Margin** | ``margin(_:top:right:bottom:left:)`` (and variants with ``fill:``), ``margin(_:_:)``, ``margin(_:_:_:)``, ``margin(_:_:_:_:)`` |
/// | **Size** | ``enforceWidth(_:_:alignment:)``, ``enforceHeight(_:_:alignment:)``, ``clampWidth(_:_:)``, ``clampHeight(_:_:)``, ``clamp(_:maxWidth:maxHeight:)`` |
/// | **Borders** | ``border(_:_:top:right:bottom:left:borderStyle:topStyle:bottomStyle:leftStyle:rightStyle:)``, ``Border`` |
/// | **Utilities** | ``expandTabs(_:tabWidth:)``, ``inline(_:)``, ``wrap(_:width:breakCharacter:)`` |
/// | **Composition** | ``joinHorizontal(_:_:)-5h7fk``, ``joinVertical(_:_:)-3zco8``, ``place(width:height:horizontal:vertical:_:)``, ``placeHorizontal(width:_:_:)``, ``placeVertical(height:_:_:)`` |
/// | **String Extensions** | Chainable versions of all the above, including `fill:` variants of `.padded()` / `.margined()` and `.wrapped()`: `.padded()`, `.bordered()`, `.margined()`, `.aligned()`, `.enforced()`, `.clamped()`, `.placed()`, `.truncated()`, `.tabsExpanded()`, `.inlined()`, `.wrapped()` |
public enum Latte {}
