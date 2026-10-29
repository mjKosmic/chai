# Proposal

## Why

Latte currently ships two layout systems. The first is the declarative view
tree (`VStack`, `HStack`, `frame`, `.padded`, `.bordered`) that renders through
Chai's allocation engine. The second is a string-level layout API
(`border`, `pad`, `align`, `joinHorizontal`, `wrap`, `Compositor`, static list
and tree renderers) inherited from the pre-engine design.

The string API has no production consumer in this repository. Spices uses only
Latte's styling types, and the example app uses only the tree DSL. The string
API also duplicates Chai's ANSI-aware width and wrapping code, and doubles
Latte's public surface with operations whose tree equivalents already exist.
Keeping it means maintaining, testing, and documenting a second layout model,
and reconciling every future layout change in two places.

The package is pre-1.0 (`0.1.0` is unreleased), so removing the API now costs
only a pre-alpha source break. Removing it after 1.0 would require a
deprecation cycle and a compatibility window.

## What Changes

- **BREAKING** Remove the string-level layout API from the `Latte` product:
  - layout functions: `border`, `pad`, `margin`, `align`, `enforceWidth`,
    `enforceHeight`, `clampWidth`, `clampHeight`, `clamp`, `wrap`, `inline`,
    `joinHorizontal`, `joinVertical`
  - composition and static types: `Compositor`, `Layer`, `ListRenderer`,
    `TreeRenderer`, and their renderer-support types
  - measurement helpers: `visibleWidth`, `height`, `size`, `displayWidth`,
    `truncateToVisibleWidth`
  - utilities: internal split-line helpers
  - `String` extensions: `padded`, `margined`, `bordered`, `aligned`,
    `enforced`, `clamped`, `truncated(toVisibleWidth:)`, `wrapped`, `inlined`
- Preserve styled borders, which the string renderer is currently the only
  way to produce: extend `BorderView` and the `.bordered` modifier with
  per-side `Style?` parameters (`borderStyle`, `topStyle`, `bottomStyle`,
  `leftStyle`, `rightStyle`) and move the `Style` → `TextAttributes` bridge
  from Spices into Latte so the container can paint styled glyph cells.
- Keep `expandTabs` and `String.tabsExpanded()`. They are text preparation,
  not layout: tab characters are zero-width and are skipped by the cell
  buffer, so the view path has no substitute for expanding them.
- **BREAKING** Remove the deprecated `Progress.viewAs(_:)` and its two private
  String gradient helpers. `Progress.viewAsStyledText(_:)` remains.
- Retain, unchanged:
  - styling values: `Style`, `Color`, `ANSIColor`, `ColorProfile`, color
    utilities and the 256-color palette
  - the declarative containers and modifiers: `VStack`, `HStack`, `FrameView`,
    `.frame`, `.padded`, `.margined`, `.bordered`, `.beside`, `.above`
  - `Border` glyph sets and the alignment value types
  - the `ViewOutput` raster clamps `clampedWidth(_:)` and `clampedHeight(_:)`
  - text preparation: `expandTabs` and `String.tabsExpanded()`
  - `Style.render(_:profile:)`, because it is the supported way to style
    `Command.println` output that is written outside the cell buffer
- Narrow the simple-path contract: the tree path (`body: some View` with a
  `ViewOutput` leaf plus modifiers) remains; the String path (`body: ViewOutput`
  built from String layout helpers) is removed.
- Add a `view-api` capability spec describing the supported public composition
  surface.
- Delete the string-API test suites, retarget the width/truncation tests at
  Chai's internal implementations, and move the border-style cases onto
  `BorderView` while keeping its glyph-set tests.

**Non-goals**

- Consolidating the surviving Latte code into Chai and removing the `Latte`
  product. That is the follow-up change `fold-latte-into-chai`.
- Any change to the allocation engine, the renderer, or the layout parity
  corpus expectations.
- Rewriting Spices components to build their bodies from the view tree.
- Removing `Style.render` or terminal color-profile downsampling.
- Public DocC site work; only source documentation is updated.

**Affected products and modules:** Latte (removals, plus the styled-border
extension and the imported style bridge), Spices (`Progress` removal and the
`StyleBridge` move), Chai (no source change; tests receive the width/truncation
coverage), the GroceryList example (no code change, must keep building), and
project documentation (`README.md`, `ARCHITECTURE.md`, `AGENTS.md`,
`docs/ROADMAP.md`, `CHANGELOG.md`, `openspec/config.yaml`).

## Capabilities

### New Capabilities

- `view-api`: the supported public composition surface — view-tree leaves,
  containers and modifiers, styling values, the custom-container SPI, raster
  clamping, and the explicit absence of a parallel string-level layout API.

### Modified Capabilities

- None. `layout-engine` behavior is unchanged; the parity corpus expectations
  must stay identical.

## Impact

- **Source-breaking** for anyone calling the removed string helpers, static
  renderers, or `Progress.viewAs(_:)`. Pre-alpha policy applies: the API may
  change without a deprecation cycle until 1.0.
- The `Style` → `TextAttributes` bridge moves from
  `Sources/Spices/Internal/StyleBridge.swift` to `Sources/Latte/Style/`. The
  module graph is unchanged: Latte still depends on Chai, and Spices still
  depends on Chai and Latte.
- Styled borders move from `border(..., borderStyle:)` to
  `.bordered(..., borderStyle:)`. The string renderer's `profile:` parameter
  is not carried; the tree path has no color-profile stage for any styled
  content, so this matches existing behavior rather than introducing a gap.
- `Tests/LatteTests` loses ten suites; `Tests/ChaiTests` gains the
  width/truncation coverage (`@testable import Chai`). `SimplePathContractTests`
  keeps only its tree-path shape.
- No dependency graph change: Latte still depends on Chai, and Spices still
  depends on Chai and Latte.
- No runtime behavior change for the view tree, renderer, input, or terminal
  layers. No change to `swift test` warning requirements.
