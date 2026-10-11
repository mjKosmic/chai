# Upgrade Plan: Declarative View Builders

This document tracks the migration from imperative view composition
(`view() -> ViewOutput` with fluent chaining) to a SwiftUI-inspired
declarative approach built on Swift `@resultBuilder`.

**Phase status:** phase 1 (declarative view tree) merged via PR #19.
Phase 2 (proposal-driven layout engine) **has landed** on
`declarative-phase-2` (M0–M4; M5 is the docs/cleanup milestone — this
change). **Phase 3 is the next phase;** its seed is the "Deferred to
phase 3" list below.

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
- Structural views are **transparent to containers**: `_childViews()`
  on the `View` protocol lets `TupleView`/`ForEachView` expose one view per
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

## Phase 2 — Proposal-driven layout engine (landed on `declarative-phase-2`)

**Scope (decided):** the engine plus `frame()` as its acceptance feature.
**Not** in phase 2: `AnyView`, modifier wrappers that stay in the tree,
proposal-aware `Text` wrapping, dynamic alt-screen control — those are
phase-3 candidates (listed at the end).
**Seam strategy:** clean break, pre-1.0 — the output-based
`_collectChildOutputs()` seam is replaced outright by a child-**view** seam.
**Spec strategy:** spec-by-test — the existing suites are the spec; the
renderer flip must keep them green without modification.

### Design constraints (from the reverted first attempt)

1. **Layout operates on child *views*, not child *outputs*.** Resolving
   children to `ViewOutput` before measurement flattens the tree, bypasses
   every child's layout overrides, and makes proposals meaningless.
2. **One join strategy.** The engine renders; `body` remains the *spec*
   (and the legacy path for eager modifiers) — engine output must match it,
   verified by a parity harness, with an explicitly closed list of allowed
   divergences.
3. **Containers honor alignment and assigned size in `_render`**, matching
   their `body` behavior.
4. **Every layer is tested** before the renderer flips.

### Architecture

**Layout value types** (`Chai/Core/LayoutTypes.swift`, reintroduced):
`ProposedSize(width: Int?, height: Int?)` (`nil` = ideal), `ViewSize`,
`ViewOrigin`. These were sound in the reverted attempt; only what they
operated on was wrong.

**View protocol engine SPI** — replaces `_collectChildOutputs()`:

```swift
func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize
func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize)
func _childViews() -> [any View]
```

- Defaults resolve through `body`, so every existing view — all Spices,
  user models with `body: ViewOutput` — works with zero changes.
- `_childViews()` semantics: "the views a container should treat as
  children." Default is `[self]`. Structural views (`TupleView`,
  `ForEachView`, `ConditionalContent`, `OptionalView`) override and are
  **transparent** — they flatten their children's `_childViews()`, so
  `for` loops and conditionals inside `HStack` participate in horizontal
  layout. Ordinary composite views (e.g. a nested `VStack`) present
  themselves as a single child. This mirrors the output-seam semantics
  proven in phase 1, but over views.

**Leaf implementation — `ViewOutput`**: `_sizeThatFits` returns the
unwrapped ideal size `(maxLineWidth, lineCount())` (empty content is 0×0 —
`lineCount()` already returns 0 for empty, so skip-empty join semantics
carry over exactly). `_render` rasterizes via `CellBuffer.write` with the
buffer's write policy (below). `maxLineWidth` moves from Latte (dead there)
into Chai's `StyledText`. `Empty` → 0×0 no-op. `Spacer` finally gets real
semantics: `(columns, 1)` / `(0, lines)`, render is a no-op (blank cells are
the buffer default).

**Container implementations**: `VStack` measures children with
`(size.width, nil)`, sizes to (max child width, Σ heights), renders each
child at `col + Int(fraction × (size.width − child.width))` honoring its
alignment. `HStack` dually; column width = each child's own max line width,
which reproduces `beside()`'s per-column normalization naturally. Empty
children measure 0×0 and advance nothing.

**Buffer write policy**: `CellBuffer` gains a wrap-vs-truncate policy set at
construction, **defaulting to truncate** — the safe choice for
content-sized buffers (wrapping steals rows the constructor didn't
allocate; the old `write` doc comment warned about exactly this). The
`Renderer` sets truncate for inline mode, wrap for alt-screen — keeping the
mode decision renderer-level exactly as today, so leaf SPI stays free of
mode flags and today's truncation behavior is preserved (inline truncation
is pinned by `RendererTests`). `write`'s explicit `wrapping` parameter
became `Bool?` — `nil` (the default) follows the buffer's policy; the free
`layout(StyledText)` function passes its policy explicitly and is
unchanged.

**Renderer integration**: `Renderer.write` stores the tree
(`pendingView: any View`) instead of resolving eagerly. `flush()` proposes
the terminal size, measures, allocates the buffer (inline:
`w × measured height`, keeping the renderer policies — suffix-clamp to
`termHeight`, the 1-row space hack for empty content; alt-screen: fixed
terminal size), renders the tree, then the existing diff/paint machinery
runs unchanged. The free `layout(StyledText)` function remains as the
leaf-level rasterizer.

**`frame()` — the acceptance feature** (`Latte`): `FrameView<Content>` with
engine overrides; `View.frame(width:height:horizontalAlignment:
verticalAlignment:)` returns it. Fixed dimensions propose to the child;
alignment fractions place it within the assigned rect. It cannot be
implemented without proposals — that is the point. Its legacy `body`
delegates to the existing `.width()`/`.height()` modifiers when both
dimensions are fixed.

**`frame()` overflow semantics (decided):** `frame()` does **not** clip.
A child whose truthful answer exceeds the frame's fixed size overflows
the frame's bounds (SwiftUI-consistent), with the terminal buffer as the
final backstop; a `.clipped()` modifier is a phase-3 candidate. Shrinking
content to fit is the phase-3 wrapping/flex story — `frame()` is
placement, not shrinking. Note `frame()` is a proposal *generator*: it
answers its fixed size to its parent regardless of the child's answer,
and proposes that fixed size downward.

### Spec & parity strategy

- Parity harness (M0): for a corpus of trees, render once through the
  engine and once through eager `body` → `layout()`, comparing **visible
  row text**. Raw cell equality is intentionally too strict: eager line
  alignment writes space cells where the engine leaves cells `.empty` —
  both render identically (`eraseLineRight` covers trailing empties).
- **Allowed divergences** (closed list; additions must update this doc):
  1. `Spacer(lines:)` inside a `VStack`: the engine produces exactly N
     blank rows. The eager path adds separator newlines on top (the
     doubling quirk) — unpinned by tests, considered a bug.
  2. `.empty` vs space cells in alignment padding — invisible by
     construction.
  3. Multi-line children under a non-left `VStack` alignment: the engine
     aligns each child as a block (one layout unit), whereas the eager
     path aligned each line individually (an artifact of text joining).
     SwiftUI-consistent; unpinned by pre-existing tests (`StackTests`
     alignment cases use single-line children). Corpus cases are marked
     `isKnownDivergent` with explicit engine-side expectations.
  4. `frame()` flexible-axis fill exists only in the engine: a frame with
     a flexible (`nil`) dimension fills a non-`nil` proposal in
     `_sizeThatFits` ("fill available space"), but the eager `body` has no
     proposal context, so it resolves fixed dimensions only. A
     flexible-axis frame (e.g. `Text("ab").frame(horizontalAlignment:
     .center)` at an 8-column proposal) renders centered in the engine and
     at the child's ideal width in the eager path. Corpus case marked
     `isKnownDivergent` with explicit engine-side expectations. This
     asymmetry self-retires in phase 3 when the eager path is removed.

### Milestones (each a PR-sized commit, TDD, zero warnings, suites green)

| # | Deliverable | Exit criteria | Status |
|---|---|---|---|
| M0 | Parity harness + tree corpus | utilities + corpus committed; no production changes | ✅ `f838b54` |
| M1 | Types + seam: `LayoutTypes.swift`, `_childViews()` clean break, engine protocol with body-resolving defaults, leaf impls, `maxLineWidth` move | measurement/render unit tests pass (incl. CJK widths, empty → 0×0); nothing consumes the engine yet; all suites green | ✅ `a093465` |
| M2 | Container engine: `VStack`/`HStack`/structural overrides honoring alignment + size | full corpus parity green (minus allowed divergences); fraction-math and skip-empty tests | ✅ `edb7517` |
| M3 | Renderer flip: buffer policy, `pendingView: any View`, engine-built buffers | **all suites green unmodified** — the phase's proof point | ✅ `3eb19e7` |
| M4 | `frame()`: `FrameView` + modifier | frame unit tests (fixed/one-dim/ideal/alignment/nesting); GroceryList centers via `.frame(...)` — the migration's motivating scenario | ✅ `1120006` |
| M5 | Docs & cleanup: ARCHITECTURE.md engine section, status flip, AGENTS.md pitfalls | review-ready | ✅ `4cf6076` |

### Risks & mitigations

- **Wrapping/truncation regressions** → buffer write policy keeps the
  decision renderer-level; M3 exits only with `RendererTests` green.
- **Join-semantics divergence** → parity harness lands first (M0) and runs
  against every container change (M2).
- **`any View` allocations per frame** → acceptable at terminal frame rates;
  revisit only if profiling says otherwise.
- **Dual paths during phase 2** → `body` stays authoritative for eager
  modifiers; the engine is authoritative for the renderer. Phase 3 retires
  the duality.

### Deferred to phase 3

`AnyView`; `ModifiedContent`-style modifier wrappers; proposal-aware `Text`
wrapping (the leaf measures unwrapped — the seam now exists to add it);
dynamic alt-screen control; proportional `Spacer` variants.
Also: carry the proposal into `_render`. `FrameView._render` receives only
the assigned size, never the proposal, so a flexible-axis frame proposes
*ideal* to its child on re-measure — observationally identical today
(children ignore proposals), but a proposal-responsive child (the phase-3
wrapping `Text`) inside a flexible-axis frame would measure differently
between the fit pass (which proposed the offer) and the render pass. If
that class of child lands, `_render(into:at:size:proposal:)` (or similar)
is the SPI extension point; `FrameView`'s doc comment records the same
limitation. Note the value-level gap already exists at the renderer's
root: `flush()` fits with the terminal width but renders at the measured
size, so a root stack proposes `termWidth` at fit and its own width at
render — inert while leaves ignore proposals. The parity harness never
exercises assigned ≠ proposed (`engineBuffer` renders at the measured
size with the same proposal); add a renderer-level parity case when
proposal-consuming children land.

---

## Breaking changes (vs. `main`)

- `func view() -> ViewOutput` became `var body` (any `View`). All ready-made
  components in **Spices** were renamed accordingly; user conformers must
  rename too.
- Call sites like `picker.view()` become the view value itself inside
  `@ViewBuilder` contexts, or `picker.body` when a `ViewOutput` is needed
  explicitly.
- `ViewOutput` no longer carries `altScreen` / `windowTitle` / `cursor` — its
  initializer lost those parameters. Set them via
  `ProgramOption.withAltScreen`, `Command.setWindowTitle(_:)`, and
  `Model.cursor`.
- String literals and interpolations work as `@ViewBuilder` expressions
  (`buildExpression(_:)` accepts `ViewOutput`, which is
  `ExpressibleByStringInterpolation`).
- Each `Spices` component's doc examples now show the new `body` usage; copy
  them when migrating.
- Minor behavior note from the migration: in the GroceryList example, the
  `q`-key check moved *before* the `picker`/`menu` updates so the key can't
  be consumed by a child first. In your own models, handle global quit keys
  before delegating to component `update`s.
- **Two `frame()`s coexist during phase 2** (detailed in ARCHITECTURE.md,
  "Two `frame()`s coexisting"): the eager
  `ViewOutput.frame(width:height:horizontalAlignment:verticalAlignment:)`
  (non-optional `Int`s, minimum-enforcing, returns `ViewOutput`) and the
  tree-based `View.frame(width:height:horizontalAlignment:verticalAlignment:)`
  (`Int?` dimensions, proposal semantics, returns `FrameView`). Overload
  resolution sends `ViewOutput` receivers to the eager one, so existing
  code is unaffected. Phase 3 may retire the eager one.
