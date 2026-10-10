# Upgrade Plan: Declarative View Builders

This document tracks the migration from imperative view composition
(`view() -> ViewOutput` with fluent chaining) to a SwiftUI-inspired
declarative approach built on Swift `@resultBuilder`.

---

## Motivation

The old imperative composition obscured the visual hierarchy:

```swift
func view() -> ViewOutput {
    picker.view().bordered(.rounded).frame(width: w, height: h).beside(menu.view())
}
```

A declarative approach makes the structure self-evident:

```swift
var body: some View {
    VStack {
        Text("Grocery List").bold()
        picker
        HStack {
            help
            menu
        }
    }
}
```

---

## Status

### Done — terminal state separation (`ViewOutput` stripped)

`ViewOutput` was reduced to `content: StyledText`. Terminal metadata moved:

| Concern      | Old location            | New location                          |
|--------------|-------------------------|---------------------------------------|
| Alt screen   | `ViewOutput.altScreen`  | `ProgramOption.withAltScreen`         |
| Window title | `ViewOutput.windowTitle`| `Command.setWindowTitle(_:)`           |
| Cursor       | `ViewOutput.cursor`     | `Model.cursor` (default `nil`)        |
| Content      | `ViewOutput.content`    | `ViewOutput.content` (unchanged)      |

`ViewOutput` remains a wrapper (not collapsed into `StyledText`) as a
renderer-agnostic abstraction for alternative renderers.

### Done — declarative view tree

- `View` protocol with `associatedtype Body: View`; `ViewOutput: View` is the
  terminal leaf.
- `Model` inherits `View`; the old `func view() -> ViewOutput` became
  `var body`. A model's `body` may be any `View` (including `ViewOutput`).
- One `@ViewBuilder` (in `Chai/Core/ViewBuilder.swift`) producing a
  **structural view tree**: `TupleView` (parameter packs), `OptionalView`
  (`if` without `else`), `ConditionalContent` (`if/else`), `ForEachView`
  (`for...in`).
- Generic containers `VStack<Content>` / `HStack<Content>` in
  `Latte/Layout/Stacks.swift`. The old `@HStackBuilder` was removed — join
  strategy now lives in the container, not the builder.
- Structural views are **transparent to containers**: `_collectChildOutputs()`
  on the `View` protocol lets `TupleView`/`ForEachView` expose one output per
  child, so a `for` loop inside an `HStack` lays out horizontally.
- Primitives: `Text`, `Spacer`, `Empty`.
- `Renderer.write(_:)` accepts any `View` and resolves it.

Rendering currently resolves the tree eagerly via
`View._resolveToViewOutput()` (recursive `body` calls to a `ViewOutput`
leaf). This bridge is the seam for the layout engine below.

### Not yet done — modifiers

`.bordered()`, `.padded()`, `.beside()`, `.above()` etc.
(`Latte/Extensions/ViewOutput+Layout.swift`) still return `ViewOutput` and
resolve eagerly. They work, but they collapse the tree instead of wrapping it.
A `.frame()` modifier does not exist yet.

---

## Layout engine (next phase)

The eager resolve bridge cannot support proposal-driven layout
(terminal-width-aware wrapping, window centering, cell-level borders).
The next phase introduces measurement and rendering on the tree:

```swift
func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize
func _render(at origin: ViewOrigin, size: ViewSize, into buffer: inout CellBuffer)
```

Design constraints learned along the way (a first attempt was reverted):

1. **Layout must operate on child *views*, not child *outputs*.** Containers
   enumerate structural children (generic recursion over `TupleView` packs or
   `any View`) and call `_sizeThatFits`/`_render` on them. Resolving children
   to `ViewOutput` before measurement flattens the tree, bypasses every
   child's layout overrides, and makes proposals meaningless.
2. **One join strategy.** The eager `joinVertically` in `StructuralViews.swift`
   and the engine must not diverge; the engine replaces the eager path, it
   does not run alongside it.
3. **Containers must honor alignment and assigned size in `_render`**
   (clip/pad to the given size), matching their `body` behavior.
4. **Every layer needs tests** (`_sizeThatFits` proposals, `_render` output
   vs. `body` equivalence, alignment/clipping).

Additional API gaps to fill: `AnyView` (type erasure for heterogeneous,
runtime-built children) and modifier wrappers that stay in the tree
(`ModifiedContent`-style) instead of resolving to `ViewOutput`.
