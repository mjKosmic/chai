# Upgrade Plan: Declarative View Builders

This document tracks the migration from imperative view composition
(`view() -> ViewOutput` with fluent chaining) to a SwiftUI-inspired
declarative approach built on Swift `@resultBuilder`.

**Phase status:** phase 1 (declarative view tree) merged via PR #19.
Phase 2 (proposal-driven layout engine) **has landed** on
`declarative-phase-2` (PR #20 — all milestones M0–M5 below, including
this docs milestone). **Phase 3 is in progress** on
`declarative-phase-3` — Stage A plan below; the full seed and staging are
in "Deferred to phase 3".

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

**View protocol engine SPI** — replaces `_collectChildOutputs()` (shown
with the A0 signature — phase 3 landed the proposal-carrying `_render`):

```swift
func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize
func _render(into buffer: inout CellBuffer, at origin: ViewOrigin, size: ViewSize, proposal: ProposedSize)
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
  5. Proposal-consuming `Text` wraps instead of truncating (A1): `Text` is
     the first production proposal consumer, so at a positive non-`nil`
     width proposal the engine wraps its content (`StyledText.wrappedToWidth`
     — measure and render share the function), whereas the eager path has no
     proposal context and truncates the over-wide line at the buffer edge.
     Corpus case "DIVERGENT: vstack wide Text line wraps (A1) instead of
     truncating" is marked `isKnownDivergent` with eager `expectedRows`
     `["abcde", "x"]` and wrapped `expectedEngineRows` `["abcde", "fgh",
     "x"]`. This asymmetry self-retires in Stage C when the eager path is
     removed.
  6. A fixed-width `frame()` around `Text` wraps instead of overflowing
     (A1): the frame is a proposal *generator*, so its fixed width reaches
     the proposal-consuming `Text`, which wraps to fit — removing the
     horizontal overflow the pre-A1 frame tests pinned. The eager path keeps
     the unwrapped raster and truncates at the derived buffer width. Corpus
     case "DIVERGENT: fixed frame smaller than Text wraps (A1); eager
     truncates at buffer" (`expectedRows` `["ab"]`, `expectedEngineRows`
     `["ab", "cd"]`). Like #4, this asymmetry self-retires in Stage C.
  7. `FlexibleSpacer` distributes leftover space only in the engine (A2):
     the eager path has no proposal context, so the spacer's `body` resolves
     to empty content and the eager join **skips** the empty component (the
     phase-1 skip-empty semantics). At a 10-column offer,
     `HStack { Text("L"); FlexibleSpacer(); Text("R") }` is `"LR"` eagerly
     and `"L        R"` in the engine (the spacer absorbs the 8 leftover
     columns). Corpus case "DIVERGENT: hstack FlexibleSpacer distributes
     leftover (A2); eager skips empty spacer" (`expectedRows` `["LR"]`,
     `expectedEngineRows` `["L        R"]`). Like #4/#5/#6, it self-retires
     in Stage C.
  8. `Fill` claims the proposed dimensions only in the engine (A2): `Fill`
     answers the offer on both axes, so in a non-left-aligned `VStack` it
     makes the stack as wide as the proposal and shifts its siblings
     (`VStack(alignment: .right) { Text("ab"); Fill() }` at width 8: eager
     `["ab"]`, engine `["      ab"]`). The eager path resolves Fill's empty
     `body` and skips it (skip-empty semantics). Corpus case "DIVERGENT:
     vstack right-aligned Fill claims proposed width (A2)" with
     `expectedRows` `["ab"]` and `expectedEngineRows` `["      ab"]`. Like
     #4–#7, it self-retires in Stage C.
  9. `.clipped()` masks overflow only in the engine (A3): the eager path has
     no assigned rect, so `ClipView.body` resolves its content unchanged —
     clipping is a render-time mask. Corpus case "DIVERGENT: clipped frame
     masks overflow in the engine (A3); eager no-op":
     `ViewOutput("abcd").frame(width: 2).clipped()` at corpus width 4 — eager
     `expectedRows` `["abcd"]` (the eager `.width()` modifier pads to a
     minimum and never truncates, and `.clipped()` is a no-op eagerly), engine
     `expectedEngineRows` `["ab"]` (the frame answers width 2; the clip masks
     the 4-wide raster to the 2-wide rect). Like #4–#8, it self-retires in
     Stage C.

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

---

## Phase 3 — Stage A: first proposal consumers (in progress, branch `declarative-phase-3`)

**Scope (decided):** the proposal-carrying `_render` SPI fix, word-aware
wrapping `Text`, fill/flex views + proportional `Spacer` variants, and
`.clipped()` (plus `ProposedSize.zero` minimum semantics). **Not** in Stage A:
`AnyView` (Stage B), modifier wrappers/eager-path retirement (Stage C).

**Pinned decisions:**

- **SPI: clean break, pre-alpha (landed in A0).** `_render(into:at:size:)` is now
  `_render(into:at:size:proposal:)` across all conformers (the `View`
  default, `ViewOutput`, `Spacer`, `VStack`, `HStack`, `FrameView`). The
  contract changed from "propose identically in structure" to **"the
  proposal passed to a child at render time must equal the proposal used
  to measure it at fit time"** — value-equal, not just structurally
  equal. This closed the phase-2 limitation (FrameView's render-time
  ideal-on-flexible-axes became a faithful reconstruction).
- **Wrapping `Text`: word-aware with a char-level fallback.** Break at
  whitespace (the whitespace is consumed at the break; interior runs are
  preserved) and *after* hyphens (no characters inserted). Each CJK
  character is its own break unit — CJK runs wrap character-by-character
  naturally. A non-CJK word wider than the container falls back to
  char-level wrapping (display-width aware, CJK-safe mid-word). Existing
  newlines are hard breaks — wrapping applies per hard line. Styles are
  preserved: segments split at break points, never re-styled.
- **`ViewOutput` stays a non-wrapping raster leaf** (explicit newlines
  only, proposals ignored) — it is a fully-formed raster. Only `Text`
  consumes width proposals. This keeps every existing `body: ViewOutput`
  model and the string-writing RendererTests byte-identical.
- **Stage A slice:** A0 behavior-preserving refactor → A1 wrapping `Text`
  → A2 fill/flex/Spacer → A3 `.clipped()` + `ProposedSize.zero`.
- **Minimum offers: `ProposedSize.zero` (A3).** The second of SwiftUI's three
  proposal special cases (`unspecified` = ideal, `zero` = minimum). `Text` is
  the only *compressible* view: at a zero (or negative — clamped to zero, one
  rule) width proposal it wraps to its narrowest producible form (the widest
  single character in the content: 1 for ASCII-only, 2 if any wide/CJK
  character is present; at least 1 for non-empty content; empty content stays
  0×0). This replaces A1's "non-positive → unwrapped" behavior — a deliberate
  spec delta (the degenerate tests were re-pinned). Every other view answers
  its minimum by construction (`ViewOutput` its raster — it may exceed the
  offer; `Spacer` its rigid size; `FlexibleSpacer`/`Empty` 0×0; `Fill` the
  offered rect, i.e. `(0, 0)` at `.zero`), and containers follow their normal
  proposal rules — no special-casing. Documented consequence: an `HStack` at
  `.zero` proposes `(nil, 0)` to its children (it measures columns at *ideal*
  width), so a `Text` child answers its ideal width, not its minimum — pinned
  by test, not "fixed".
- **No `.infinity` (A3, docs only).** The third SwiftUI special case is
  deliberately absent: our proposal dimension is `Int?` (no representation for
  infinity) and `ViewSize` is `Int`-based (a view could never answer
  faithfully — a `FlexibleSpacer`'s maximum is "whatever the container decides
  is left", a container-level fact). The functionality maps to existing
  mechanisms: "expand to fill" ≙ `_flexibility()` + stack leftover
  distribution; "measure maximum" ≙ the container's leftover math. See
  ARCHITECTURE.md, "Why there is no `.infinity`".

### Milestones

| # | Deliverable | Exit criteria |
|---|---|---|
| A0 | **Proposal-carrying `_render`** — the clean SPI break across all conformers; `Renderer.flush` passes the fit proposal (width w, height alt-screen h / nil) to the root render; `FrameView` reconstructs its fit proposal on re-measure; docs rewritten (ARCHITECTURE fit/render section, AGENTS pitfall #2 becomes a value-equality contract) | Behavior-preserving: all 1108 suites green unmodified; a test-local proposal-echo consumer view + a renderer-level parity case exercising `assigned ≠ proposed` at the root (the phase-2 harness blind spot) | ✅ landed |
| A1 | **Word-aware wrapping `Text`** — measures wrapped at a non-nil width proposal, renders the wrapped content; algorithm per the pinned rules | New wrapping tests (whitespace/hyphen/CJK/fallback/hard-newline/style preservation); corpus truncation cases re-pinned as **divergences #5/#6** (engine wraps, eager truncates — `expectedRows` eager, `expectedEngineRows` wrapped, `isKnownDivergent`); example uses a wrapping `Text` | ✅ landed |
| A2 | **Fill/flex views + proportional `Spacer`** — minimal fill views answering proposal dimensions; flexible `Spacer` variants taking a fraction of leftover space | Measurement/placement tests; corpus additions where eagable (fill-only engine behavior → divergence if eager can't express it) | ✅ landed |
| A3 | **`.clipped()` + `ProposedSize.zero`** — `ClipView` masks the child to its assigned rect (the opt-in for frame's pinned no-clip decision); `ProposedSize.zero` adds the *minimum* offer with `Text` as its only compressible consumer; the `.infinity` rationale is recorded (docs only) | Clip tests (overflow clipped both axes, rect ownership, wide-char boundary, nesting, composition); minimum-semantics tests (`Text` ASCII/CJK/mixed/styled/empty, non-compressible leaves, `VStack` min composition, the HStack-at-zero observation, `FrameView` at zero); divergence #9; zero-warning suites green | ✅ landed |

Divergence-list updates are expected at A1 (truncation → wrap) and A3
(clipping) — the closed-list mechanism is designed for exactly this;
every change must carry `expectedRows` + `expectedEngineRows` + an
`isKnownDivergent` flag, and the closed list's wording stays. A1 landed
two: #5 (a proposal-consuming `Text` wraps instead of truncating) and #6
(a fixed-width `frame()` around `Text` wraps instead of overflowing) —
both self-retire in Stage C. A2 landed #7 (`FlexibleSpacer` distributes
leftover space only in the engine; the eager join skips the empty spacer) —
also self-retiring. A3 landed #9 (`.clipped()` masks overflow only in the
engine; the eager path has no assigned rect) — also self-retiring. A3 also
added `ProposedSize.zero` and `Text`'s minimum semantics: no corpus impact,
because the harness proposes `(width, nil)` with positive widths — no zero
offers — so the corpus is unaffected (verified).

**A2 SPI note.** A2 adds a fourth SPI method, `View._flexibility()`
(default `.rigid`), queried by the stacks to distribute leftover main-axis
space. A stack is *flexing* on its main axis when at least one child reports
a positive fraction on that axis; it then fills a non-`nil` main-axis
proposal and assigns each flexible child
`rigid + Int(Double(leftover) * (fraction / totalFlex))` (normalized shares,
`Int()` truncation, remainder left unallocated at the trailing end). With no
flexible child the code path is unchanged. Only `FlexibleSpacer` overrides
it in A2; `Fill` is a plain consumer (it answers the proposal verbatim on
both axes) and is *not* flexible.

**Wrapping-wrapper overlap (A1 → Stage C).** The A1 wrapping algorithm
lives in Chai (`StyledText.wrappedToWidth(_:)`) because it operates on
Chai's `StyledText` segment model and must preserve styles exactly. Latte
has its own eager, string-level wrapper (`Latte/Layout/Wrap.swift`) used by
the eager modifiers; the dependency direction (Latte imports Chai) forbids
reusing it in the engine. The two coexist while the eager path lives and
are reconciled in **Stage C**, when the eager path (`_resolveToViewOutput`)
is retired and the eager wrapper goes with it — as noted in the A1 source
file's header.

### Deferred to phase 3 (seed list and suggested staging)

The seed list: `AnyView`; `ModifiedContent`-style modifier wrappers;
proposal-aware `Text` wrapping (the leaf measures unwrapped — the seam
exists); dynamic alt-screen control (per-state fullscreen; today it is a
program-level startup option); proportional `Spacer` variants; and a
`.clipped()` modifier (the opt-in accompanying `frame()`'s pinned no-clip
decision).

Suggested staging from the phase-2 closeout — the ordering constraint is
load-bearing:

1. **Stage A — first proposal consumers.** Carry the proposal into
   `_render` and add a renderer-level parity case exercising
   `assigned ≠ proposed` (the harness never does: `engineBuffer` renders
   at the measured size with the same proposal), *then* land wrapping
   `Text`, fill/flex views, proportional `Spacer` variants, and
   `.clipped()`.
2. **Stage B — `AnyView`** type erasure for heterogenous runtime-built
   children (`buildArray` currently requires one homogeneous `V`).
3. **Stage C — modifiers stay in the tree.** Rebuild
   `.bordered()/.padded()/.beside()/.above()` and the rest of the eager
   family as `ModifiedContent`-style wrappers, retire the eager
   `_resolveToViewOutput()` path and `ViewOutput.frame`, and collapse
   the divergence list — entry #4 self-retires; **preserve the engine
   `Spacer` semantics from entry #1** (exactly N blank rows), never the
   eager doubling quirk.

Dynamic alt-screen control is a runtime concern, not a layout one — scope
it explicitly at kickoff or park it.

Also resolved by A0: carry the proposal into `_render`. `FrameView._render` previously received only the assigned size, never the proposal, so a flexible-axis frame proposed *ideal* to its child on re-measure — observationally identical while children ignored proposals, but a proposal-responsive child (the phase-3 wrapping `Text`) inside a flexible-axis frame would have measured differently between the fit pass (which proposed the offer) and the render pass. A0 landed `_render(into:at:size:proposal:)` and `FrameView` now reconstructs its fit proposal (`width ?? proposal.width` / `height ?? proposal.height`). The value-level gap at the renderer's root is also closed: `flush()` fits with the terminal width and now passes the *same proposal value* to the root render. The parity harness blind spot — `engineBuffer` renders at the measured size with the same proposal, so it never exercised `assigned ≠ proposed` — is closed by the test-local `ProposalEchoView`, which pins the renderer-level (`W:20` at a 20-column terminal for a stack measuring 12) and frame-closure (`W:8` on a flexible-axis frame at an 8-column proposal) cases.

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
