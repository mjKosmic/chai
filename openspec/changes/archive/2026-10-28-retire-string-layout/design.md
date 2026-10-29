# Design

## Context

See `proposal.md` → Why. Two properties of the current tree shape drive the
mechanics:

- Latte contains two disjoint populations. The tree containers
  (`Layout/{Stacks,Frame,PaddingView,BorderView,CompositionWrappers}.swift`)
  import Chai and consume its allocation SPI. The string layer
  (`Borders/BorderRenderer`, `Composition`, `Static`, `Measurement`,
  `Utilities`, `Extensions/String+Layout`, and most of `Layout`) imports
  nothing from Chai and operates on `String`.
- The surviving raster clamps (`ViewOutput.clampedWidth(_:)`,
  `.clampedHeight(_:)`) are the one string-facing feature that is not a layout
  model. They truncate already-finished content.

The engine contract and the parity discipline are described in
`ARCHITECTURE.md` → "The Layout Engine" and "The parity discipline"; this
change does not alter either. The phase history that produced the two
populations is in `docs/history/VIEW-LAYER-MIGRATION-LOG.md`; it is not
restated here.

## Goals / Non-Goals

**Goals:**

- Remove the string-level layout API and its public surface without changing
  any rendered output.
- Leave exactly one width/measurement implementation in the codebase.
- Keep the tree DSL, styling values, and `Style.render` behavior identical.
- Record the resulting composition contract in the new `view-api` spec.

**Non-Goals:**

- Moving the surviving Latte code into Chai or removing the product
  (`fold-latte-into-chai`).
- Engine, renderer, input, or terminal changes.
- Changing any parity corpus expectation.
- Adding a `println(StyledText)` overload (noted under Open Questions).

## Decisions

### 1. Delete now; do not deprecate

The API is removed outright, with no deprecation shims. The package is pre-1.0
and the removal is already the kind of break the pre-alpha policy allows.
Deprecation would keep the second layout model, its tests, and its documentation
alive for a release cycle in exchange for a migration that is mechanical.
*Alternative considered:* mark deprecated until 1.0. Rejected: cost without a
consumer.

### 2. Remove the API in place; move modules later

The tree containers and styling values stay in `Latte` for this change. This
keeps the diff a deletion rather than a deletion plus a 2,000-line move, and
keeps the parity corpus as the unchanged proof that no layout behavior moved.
The product removal is the follow-up change.

### 3. Keep `Style.render(_:profile:)` and `ColorProfile`

`Command.println(_:)` accepts a `String`, and `Renderer.flush()` writes queued
lines verbatim, truncating them ANSI-aware. Styling print-above-view output
therefore requires an ANSI-string renderer. Removing `Style.render` would
remove a capability that has no tree-based substitute.
*Alternative considered:* delete it and add `Command.println(_ text: StyledText)`.
Rejected for this change: it needs renderer changes and is not required to
remove the layout API. It remains possible later.

### 4. Keep the raster clamps — and move them into Chai

Clipping and truncating are different operations and neither replaces the
other:

- **Clipping** is a paint-time constraint. The view keeps its reported size;
  the buffer drops cells outside the allocated rect. Used by `frame()` and the
  root allocation.
- **Truncating** is a content transformation. The raster is rewritten to fewer
  columns before layout, so the view *reports* the smaller size and the
  surrounding layout treats it as smaller.

The clamps are the only expression of the second operation. They are not
obsolete; they are orthogonal to the engine.

They move to Chai in this change because the alternative is worse. Once
Latte's public width helpers are deleted, the clamp internals in
`StyledText+Layout.swift` would have no cross-module width function to call
(Chai's `displayWidth` is internal). Keeping a private copy of width logic in
Latte would preserve exactly the duplication this change removes. Moving the
surviving helpers (`Line`, `splitLines`, `truncated`, `clampWidth`,
`clampHeight`) and `ViewOutput+Layout.swift` into `Chai/Core/` lets them use
Chai's existing implementation, and the duplicate is deleted outright.

### 5. Remove the public measurement API; keep one internal width function until the fold

`Measurement/DisplayWidth.swift` exists to serve the string layer, but two
surviving consumers remain: `BorderView.paint` advances columns by the display
width of each border glyph, and `expandTabs` tracks the display column while
expanding tab stops. Both call Latte's `displayWidth`. Chai's equivalent is
`internal`, so they cannot call it across the module boundary.

The public measurement API (`visibleWidth`, `height`, `size`,
`truncateToVisibleWidth`, the public `displayWidth` overloads) is deleted in
this change. A single internal `displayWidth(of:)` implementation stays in
Latte, used only by `BorderView` and `TabExpansion`, and is deleted when both
move into Chai in the follow-up. Keeping it is the smaller cost than moving the border
container early or publishing a width helper on Chai's API surface that the
`view-api` spec deliberately does not include.

### 6. Keep `Border` glyph sets and alignment value types in place

`Border` is consumed by `BorderView`, and `HorizontalAlignment` /
`VerticalAlignment` by stacks and frames. They are part of the tree population
even though they are declared in files that also feed the string layer. The
string-only declarations in those files (the `border()` renderer, `align()`)
are deleted; the value types stay until the follow-up move.

### 7. Preserve styled borders by extending the tree modifier

`border(...)` is currently the only way to style border glyphs: `BorderView`
paints unstyled cells and `.bordered` takes only a `Border`. Removing the
string renderer without an equivalent would drop a capability, not just a
syntax. `BorderView` and `.bordered` gain per-side `Style?` parameters, painted
as structured `TextAttributes` on the glyph cells; corners inherit the
horizontal edge's style, matching the string renderer's rules.

This needs `Style.textAttributes` inside Latte, so the bridge moves from
`Spices/Internal/StyleBridge.swift` to `Sources/Latte/Style/`. That also
removes the layering inversion where the styling library's adapter lived above
the components that consume it. The string renderer's `profile:` parameter is
not carried: the tree path has no color-profile stage, and styled content has
always rendered at full fidelity there.

*Alternative considered:* keep `border()` alive for styling only. Rejected: it
preserves a string layout function after the layout API is retired.

### 8. Keep tab expansion

`expandTabs` and `String.tabsExpanded()` are text preparation, not layout. A
tab is a C0 control character with display width 0, and `CellBuffer.write`
skips zero-width characters, so a tab inside a view is dropped silently. The
view path has no tab-stop logic; deleting the helper would remove the only
supported way to render tab-indented text. Both stay in Latte and move into
Chai with the surviving styling and text helpers in the follow-up.

### 9. Test disposition

| Suite | Action |
|---|---|
| `AlignmentTests`, `CompositorTests`, `InlineTests`, `JoinTests`, `ListRendererTests`, `PaddingTests`, `SizeTests`, `StringExtensionTests`, `TreeRendererTests`, `WrapTests` | Delete with the API |
| `BorderTests` | Keep the glyph-set and equatable tests; port the style-application cases to `BorderView` as structured-attribute assertions, and drop the profile-specific cases |
| `TabExpansionTests` | Keep; absorb the `tabsExpanded` cases from `StringExtensionTests` |
| `DisplayWidthTests` | Split: move the `displayWidth` / `visibleWidth` / `truncateToVisibleWidth` cases to `Tests/ChaiTests` against `@testable import Chai`; delete the `height` / `size` cases with the helpers |
| `ViewOutputLayoutTests` | Move to `Tests/ChaiTests` with the clamps |
| `SimplePathContractTests` | Keep the tree-path app; delete the String-path app and its assertions |
| Remaining layout/style suites (`Stacks`, `Frame`, `HardBox`, `AllocationRules`, `SpacerAndFill`, `ModifierWrapper`, `LayoutParity/*`, `Style*`, `ColorUtilities`, `Hyperlink`, `UnderlineStyle`) | Unchanged |

No suite is skipped or weakened; the four moved/trimmed suites keep their
assertions against the surviving implementation.

## Risks / Trade-offs

- **External pre-alpha users lose source compatibility.** → Marked
  **BREAKING** in the proposal and changelog; no shim by design.
- **A helper still used by the tree layer is deleted by mistake.** → The build
  fails first; the parity corpus then proves layout output is unchanged. The
  file lists above are exhaustive of the string-only population.
- **Width coverage silently drops.** → `DisplayWidthTests` moves rather than
  being deleted, and runs against `@testable import Chai`.
- **`Style.render` becomes public API with no in-repo caller** once
  `Progress.viewAs` is removed. → Kept deliberately for `Command.println`;
  documented in the `Style.render` doc comment and in the README styling
  section.
- **Border styling loses the string renderer's `profile:` downsampling
  stage.** → The tree path has never applied a color profile to styled
  content, so this removes an inconsistency rather than introducing one.
  Document that tree styling is full-fidelity and that `ColorProfile` remains
  for `Style.render` / `println`.
- **The styled-border extension adds public modifier parameters.** → Pinned by
  the `view-api` "Styled border edges" scenario and the ported `BorderView`
  tests.
- **Docs drift** (`README`, `ARCHITECTURE` Latte section, `AGENTS` layout,
  `ROADMAP`, `config.yaml` context, module DocC). → Dedicated documentation
  tasks with the code they describe.

## Migration Plan

No persistent state or data migration. Source migration for pre-alpha users:

| Removed | Replacement |
|---|---|
| `"x".padded(...)`, `pad(...)` | `.padded(...)` on the view |
| `"x".margined(...)`, `margin(...)` | `.margined(...)` on the view |
| `border(...)`, `"x".bordered(...)` | `.bordered(..., borderStyle:topStyle:bottomStyle:leftStyle:rightStyle:)` on the view |
| `"x".aligned(...)`, `align(...)` | `.frame(width:horizontalAlignment:)` |
| `"x".enforced(...)`, `enforceWidth/Height` | `.frame(width:height:)` |
| `"x".clamped(...)`, `clampWidth/Height` | `ViewOutput.clampedWidth(_:)` / `.clampedHeight(_:)` for finished rasters; `.frame` for allocation |
| `"x".wrapped(...)`, `wrap(...)` | `Text`, which wraps at its allocated width |
| `joinHorizontal/Vertical` | `HStack` / `VStack` |
| `Compositor`, `Layer` | Not replaced in this change (no consumer; future `ZStack` is roadmap R15) |
| `ListRenderer`, `TreeRenderer` | Compose lists/trees from views in application code |
| `visibleWidth`/`size`/`height` helpers | `StyledText.columnWidth` / `lineCount()` |
| `expandTabs`, `"x".tabsExpanded()` | Retained (text preparation) |
| `Progress.viewAs(_:)` | `Progress.viewAsStyledText(_:)` |

Rollback is a revert of the change; no runtime or schema state is involved.

## Scenario coverage

Every `view-api` scenario maps to an owning test (or, for the ANSI-content
scenario, a documented non-test assertion):

| Scenario | Owning test |
|---|---|
| Body with a single leaf | `SimplePathContractTests.bodyWithASingleLeafIsACompleteFrame` |
| Nested containers | `StacksEngineTests.threeLevelNestingThroughStructuralChildren` |
| Padded and bordered content | `SimplePathContractTests.treePathRendersTheApp` |
| No string layout unit | `LayoutEngineTests.textMeasuresIdealSizeAtUnconstrainedQuery` (a string enters layout as a leaf) |
| Styling survives layout | `StackTests.styledContentSurvivesVStackAlignment` |
| ANSI text is rejected as view content | Enforced by the `ViewOutput(String)` initializer assertion; not unit-testable without crashing the process |
| Styled border edges | `BorderTests.borderStyleAppliedToAllEdges` |
| A custom container lays out its child | `RendererEnginePathTests.allocationEchoSeesItsAssignedRectAtRootRender` |
| Custom container inside a built-in stack | `StacksEngineTests.vstackAllocatesEachChildItsOwnRect` |
| Clamping columns | `ViewOutputRasterHelperTests.clampedWidthHandlesWideCharacters` |
| Clamping rows | `ViewOutputRasterHelperTests.clampedHeightDropsExtraLines` |
| Clamping does not pad | `ViewOutputRasterHelperTests.clampedWidthLeavesShortLinesAlone` |

## Open Questions

- Whether to add `Command.println(_ text: StyledText)` so styled out-of-band
  output does not depend on `Style.render`. Deferrable: it changes no
  requirement in this change and can be proposed separately.
