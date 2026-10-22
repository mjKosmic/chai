# TOP-DOWN SPIKE — phase-4 investigation report

**Status: retired (documented history).** The report below is the design
evidence of record for phase 4. Its walker and corpus copy
(`Tests/ChaiTests/Spike/`) were **deleted in P1** when the rules graduated
into production `_embed` implementations; the production suites
(`Tests/LatteTests/LayoutParity/ParityEngineTests.swift`,
`AllocationRulesTests.swift`, `Tests/ChaiTests/EmbedKernelTests.swift`) now
carry the assertions this spike ran as diagnostics. The spike's five probes are
assertions in `AllocationRulesTests`.

**Companion:** the spike suite is `TopDownSpikeComparisonTests` in
`Tests/ChaiTests/Spike/TopDownSpike.swift` (all diagnostic: the corpus table
is data, not a gate). With the scratch present the tree builds and tests green
at 1245 tests / 106 suites (baseline 1239/105 + 6 spike tests). Production
code untouched.

---

## TL;DR

A top-down authoritative allocator was prototyped **over the current public
SPI** (no production changes, no `body`/eager calls): `_childViews()` for
enumeration, `_sizeThatFits(...)` demoted to a **pure intrinsic query**, `_render`
as the leaf rasterizer, `_flexibility()` as a pure child report. The walker
plus per-type allocation rules reproduce **all 38 corpus cases bug-for-bug**
(`<walker> == engine` on every non-divergent case *and* every divergent case's
`expectedEngineRows`), and all five semantic probes (stretch, overflow,
compression, HStack fill, multi-flex) reproduced the live engine byte-identically.

The owner's diagnosis holds up where the predicted machinery is concerned, but
not quite the way it's framed:

- **The two-pass shape survives, in a much weaker form.** A top-down engine
  still needs a sizing pass (the renderer's buffer-height policy needs a
  content height before any buffer exists, and `ClipView` needs its mask's
  size before it renders). What dies is not "two passes" but the **fit/render
  value-equality contract**: the render pass no longer re-measures
  children with a *proposal* it must remember; it makes its own allocation,
  and queries are only ever read, never negotiated.
- **`_sizeThatFits` survives as the query kernel.** It was never the
  anti-pattern; its *authority* was. The same function, reinterpreted as a
  report, feeds every allocation decision in the spike.
- **`_flexibility` survives** unchanged as a report (the share math consults
  it exactly like today).
- **`FrameView`-the-generator, "offer, not a bound"-as-authority, and
  `ProposedSize.zero` minimum semantics all dissolve** into typed ALLOCATION
  rules — fixed dims are properties of the rect, not of a proposal that must
  be echoed.
- **What the corpus could not settle:** stretch (corpus never offers a
  height), the stack "fill vs shrink-wrap" decision at width (every corpus
  stack is shrink-wrap-directed), and dynamic resize/alt-screen integration.

The recommendation below is the **hybrid, exactly as the task's counter-nuance
anticipated**: top-down allocation authority for stacking/frame/clip; pure
queries for intrinsic sizing; `_flexibility` retained for leftover shares; and
no measurement authority anywhere.

---

## 1. The proposed top-down SPI (sketch)

The spike runs everything over today's SPI, but a real phase 4 needs three
concrete SPI deltas. Sketch (public signatures only):

```swift
public protocol View: Sendable {
    var body: Body { get }                       // unchanged

    /// 1. PURE QUERY (role change, signature unchanged). View types answer
    ///    what they would need under this much context; the answer carries
    ///    no authority — it can be overruled by any container. `.zero`
    ///    remains the "minimum" query context a container issues when IT
    ///    decides to compress.
    func _sizeThatFits(_ proposal: ProposedSize) -> ViewSize

    /// 2. PURE REPORT (unchanged). The share of a container's leftover
    ///    main-axis space this view would absorb, if the container decides
    ///    to distribute any.
    func _flexibility() -> LayoutFlexibility

    /// 3. NEW — THE assignment entrance. Replaces
    ///    `_render(into:at:size:proposal:)`: there is no `size:`/`proposal:`
    ///    dual bookkeeping because the assignment IS the allocated rect.
    ///    Default implementation keeps conformers working:
    ///      _embed { leaf._render(into: &$0, at: rect.origin,
    ///                             size: rect.size,
    ///                             proposal: ProposedSize(rect.size)) }
    func _embed(into buffer: inout CellBuffer, at rect: SPIRect)

    /// 4. NEW (containers only) — the allocator dispatch marker. The spike
    ///    used `Mirror` + type-name probing to identify `VStack`/`HStack`
    ///    /`FrameView`/`ClipView` inside an `any View`; production code
    ///    needs a real hook, e.g. a visitor:
    ///      func _accept(_ allocator: inout some AllocatorVisitor)
    ///    …or a `_layoutPolicy -> LayoutPolicy?` marker. Without it, the
    ///    engine cannot see *through* `ModifiedContent`-style Stage-C
    ///    wrappers generically.
    func _childViews() -> [any View]             // unchanged
}
```

Supporting value types are unchanged: `ProposedSize`, `ViewSize`,
`ViewOrigin`, `LayoutFlexibility`. One new value type appears — the assigned
rect (spike: `SpikeRect(origin:size:)`); in production it could never be a
public struct with a different name than needed, so either widen `ViewOrigin`
+ `ViewSize` to a `ViewRect` or pass `(origin: ViewOrigin, size: ViewSize)`.

### Deletions relative to today's SPI

| Today's SPI item | Top-down fate | Why (spike-grounded) |
|---|---|---|
| `_render(into:at:size:proposal:)` | **renamed/shaped** into `_embed(into:at:rect)` | the `proposal` argument existed only to carry the fit pass's answer into the render pass (A0). Top-down assignment is a rect — the render pass renders at what it was TOLD. |
| Fit/render value-equality contract (A0) | **dissolves** | no second value to hold equal — the render walk does not re-measure with a remembered proposal; containers compute child rects from their own rules. Note: `ProposalEchoView` (duplicated in the Latte and Chai test targets) and its renderer/frame echo tests become obsolete. |
| `FrameView`-as-generator semantics | **dissolves into data** | `width`/`height` ARE allocations; the "answers fixed dims verbatim … reconstructs its fit proposal" story — the whole A0 `width ?? proposal.width` reconstruction — is gone. The spike's `frameShape`/`frame-allocate` branch is 2 rules and no proposal bookkeeping. |
| `ProposedSize`'s `.zero` minimum semantics | **retired as a *negotiation rule*** (kept as a query convention) | `Text`'s minimum-wrap remains useful only as the answer to the container's `.zero` query when the container decides to compress. The A3 "containers follow their normal proposal rules at .zero — no special-casing … documented consequence of the column model, pinned by test" paragraph collapses. The `hstackNeverProposesWidthSoTextCannotWrapInsideIt` pin becomes an ALLOCATOR RULE statement ("columns measure at ideal width"), not a proposal artifact. |
| "An offer, not a bound" four-stage hardness table | **collapses to three stages** with the same semantics | the four stages were: proposal (parent's advice) → answer (child's want) → assigned size (parent's decision) → buffer (hard wall). Top-down retains: query (child's report — never clamped, still an *honest overflow signal*) → ALLOCATION (the container's binding rect) → buffer bounds. The A0 *value-equality* stage is precisely the one that vanishes. |
| `distributedMainAxis` (stacks' fill machinery) | **kept, but as a type-level rule** | the share math is byte-equal to today's (normalized shares, `Int()` truncation, trailing remainder — verified by the `FlexibleSpacer` distribution + two-flex-sandwich probes); it stops being "a leftover smuggled into a bottom-up protocol" because the *stack occupancy* decision (`max(proposal ?? rigidTotal, rigidTotal)`) becomes `max(assignedRect ? assigned : rigidTotal, rigidTotal)` — no proposal involved. |

---

## 2. The allocator rules (per view type, as implemented in the spike)

These are the spike's literal rules — the same rigor as the phase-2
"Architecture" section, but authority lives only here:

**VStack** — assigns each child a RECT.
- Cross axis (width): each child is queried at the ASSIGNED width context
  (`_sizeThatFits((row's rect.width, nil))` — a query, not an offer; the
  cross axis is never negotiated). Reported width becomes the child's rect
  width; **`Fill`-by-type children are overruled to the full assigned width**
  (query ignored — allocation authority).
- Main axis (height): each child's reported height is its allocated row
  height (the stack NEVER compresses a row: overflow stays visual). If any
  child reports a positive height flexibility AND the stack was assigned
  more height than its rigid total, flexible children absorb the leftover
  (current `distributedMainAxis` math — `Int()`-truncated normalized shares).
- Occupied width = max child width (shrink-wrap) — the stack still decides
  its WIDTH from child queries; nothing else is delegated.
- Rendering: children anchored at
  `Int(Double(shortage) * alignment.fraction)` with rows advancing by
  ALLOCATED heights (same formula as today).

**HStack** — assignments per column.
- Main axis (width): columns are measured at **IDEAL width** (`(nil, …)`
  width context — the `hstackNeverProposesWidth…` contract, now an explicit
  allocator rule rather than a proposal artifact). Width-flex children (by
  `_flexibility()` report) absorb the leftover: `max(0, rect.width −
  rigidTotal)`; **`Fill`-by-type columns absorb what remains AFTER flexible
  shares** (split evenly). Overflow (Σ reported > assigned) is never
  compressed — columns keep their width and the buffer backs the overflow.
- Cross axis (height): each child's reported height; vertically anchored by
  the alignment fraction against the stack's MAX child height (occupied).

**FrameView** — fixed dimensions are ALLOCATION decisions.
- Fixed width/height: the frame OWNS those dims verbatim (its occupied rect)
  and offers exactly them down.
- Flexible (`nil`): the frame PASSES its assigned rect dims through (fill),
  floored by the child's query (never occupies less than what it must
  place).
- The child occupies its own QUERY-reported size, anchored per the two
  alignment fractions of the shortage; overflow is NOT masked (`.clipped()`
  is the opt-in — identical pinned decision to today).

**ClipView** — masks at the child's occupied rect.
- Reserve-first: the child's occupied size is computed by the same rules
  (pure pass), the child is rendered into a temp buffer of exactly that
  size (today's truncate write policy — horizontal overflow masked, wide
  chars dropped at the boundary), then the temp is blitted blank-inclusive
  (painter order; today's semantics retained).

**Leaves** —
- `Fill` claims exactly its assigned rect (the container's decision defines
  it; no query round-trip).
- `Text` renders **wrapped at its ALLOCATED width** (`Text._render` already
  resolves its content from the proposal — in a top-down tree what it
  receives IS the rect width). Compression floor: the allocator can query
  `_sizeThatFits(.zero)` for the minimum and clamp the rect; the spike did
  NOT implement the clamp (to match today's degenerate CJK-at-width-1 loss)
  — a top-down world could fix it with one rule; recorded as a designer's
  option in §5.
- `ViewOutput` ignores the offer (a fully-formed raster); overshoot → buffer
  bounds; undershoot → anchored, never stretched.
- `Spacer`/`Empty`/`FlexibleSpacer` — unchanged: `FlexibleSpacer` is 0×0 at
  render; the container owns the share.

**Structural views** — `_childViews()` flattening unchanged (the spike walks
the flattened primitive children; structural views never appear as walk
nodes in the corpus — they are transparent exactly as in phase 1).

---

## 3. The empirical heart: corpus comparison (verbatim)

Run: every corpus case through the top-down walker (proposal `(width, nil)`,
buffer width = case width, buffer height = explicit height OR
top-down-predicted content height) vs the pins. Full table:

| case | w | engine pin verdict | eager vs walker |
|---|---|---|---|
| vstack multiple texts | 8 | match | match |
| vstack single child | 8 | match | match |
| vstack skips empty child | 8 | match | match |
| vstack center alignment pads every line to max width | 8 | match | match |
| vstack right alignment pads every line to max width | 8 | match | match |
| hstack multiple children | 8 | match | match |
| hstack differing heights pads shorter child rows | 8 | match | match |
| hstack bottom alignment | 8 | match | match |
| hstack middle alignment | 8 | match | match |
| hstack lays out for loop horizontally | 8 | match | match |
| hstack includes spacer columns | 8 | match | match |
| hstack with if true (no else) includes branch | 8 | match | match |
| hstack with if false (no else) omits branch | 8 | match | match |
| three level nesting: vstack of hstacks with for loop | 8 | match | match |
| styled child in vstack center | 8 | match | match |
| styled child in hstack | 8 | match | match |
| cjk wide chars in hstack extract as single characters | 8 | match | match |
| cjk wide chars in vstack | 8 | match | match |
| string literal expression inside vstack | 16 | match | match |
| viewoutput used directly as child | 8 | match | match |
| vstack with explicit height pads buffer with blank rows | 8 | match | match |
| DIVERGENT: vstack wide Text line wraps (A1) instead of truncating | 5 | match | diff |
| DIVERGENT: vstack with spacer lines 2 doubles blank rows | 8 | match | diff |
| DIVERGENT: vstack center aligns multiline child as block | 8 | match | diff |
| DIVERGENT: vstack right aligns multiline child as block | 8 | match | diff |
| hstack bottom nests vstack inside | 8 | match | match |
| three level hstack vstack hstack with for loop | 8 | match | match |
| hstack all empty children | 8 | match | match |
| fixed frame left top around small vstack | 6 | match | match |
| fixed frame right bottom around small vstack | 8 | match | match |
| fixed frame center middle around text | 8 | match | match |
| fixed frame center middle around hstack | 6 | match | match |
| DIVERGENT: fixed frame smaller than Text wraps (A1); eager truncates at buffer | 2 | match | diff |
| DIVERGENT: flexible width frame fills proposal and centers | 8 | match | diff |
| DIVERGENT: hstack FlexibleSpacer distributes leftover (A2); eager skips empty spacer | 10 | match | diff |
| DIVERGENT: vstack right-aligned Fill claims proposed width (A2) | 8 | match | diff |
| DIVERGENT: clipped frame masks overflow in the engine (A3); eager no-op | 4 | match | diff |
| DIVERGENT: newline-only Text collapses to nothing (A1); eager measures two blank rows | 8 | match | diff |

Summary line from the run: **walker == engine pin: 38/38; walker == eager
pin: 28/38; walker == neither: 0.** The 10 `diff`s in the third column are the
exact ten pinned allowed divergences — engine-vs-EAGER divergences, captured
bug-for-bug by the top-down walker. **No new divergences appeared, and none
disappeared** (none could: divergences #4–#9 exist only because the eager
path has no proposal context — the corpus topology can't distinguish
"engine-negotiates" from "top-down-allocates" *outputs* on these trees).

### Probes (what the corpus cannot pin, reproduced live)

| probe | result (walker vs live engine) |
|---|---|
| vertical stretch: `VStack(right){Text;FlexibleSpacer}` at width 8, offered height 6 | **identical** `["ab","","","","",""]` — the height-flex share is container-computed top-down; note both put the text at col 0 (the vertical FlexibleSpacer occupies zero width, and NO mechanism widens the stack — shrink-wrap is pinned in both worlds) |
| overflow: `HStack{Text "你";Text "好"}` width 3 | **identical** `["你"]` — columns keep intrinsic widths (cannot-wrap), buffer truncates the second wide char |
| compression: `VStack{Text "hello world"}` width 5 | **identical** `["hello","world"]` — Text wraps at its ALLOCATED width |
| Fill in HStack: `HStack{Text "x"; Fill}` width 8 | **identical rows** `["x"]` but **different measured width**: engine measures the stack 1×1 (Fill's query answers 0 at a nil-width context), the walker's stack IS 8 wide |
| multi-flex sandwich: `HStack{FlexibleSpacer;Text "mid";FlexibleSpacer}` width 20 | **identical** `["        mid"]` — 8-col shares either side, truncation remainder unallocated (current engine's trailing-remainder rule, byte-equal) |

---

## 4. Machinery verdicts (grounded, not rhetorical)

| Item | Verdict in a top-down world | Spike evidence |
|---|---|---|
| **A0 fit/render value-equality contract** (SPI break + `ProposalEchoView` ×2 targets + echo corpus/tests) | **BECOMES UNNECESSARY.** The obligation disappears because the render pass no longer re-measures with a remembered proposal — the assignment IS the fact. The echo *tests* obsolete; the *same* echo view still renders correctly under `_embed` (the rect carries everything) with no pin. | Walker reaches the same outputs with no proposal forwarding at all: `SpikeRect` is the only bookkeeping. No echo machinery exists in the spike; every corpus case renders from a rect computed once per node. |
| **`_flexibility()` SPI** | **TRANSLATES DIRECTLY.** | The share math (`distributeLeftover`) consults `_flexibility()` exactly like `distributedMainAxis`; probes reproduce the engine's normalized-share/truncation-remainder math byte-for-byte. |
| **`FrameView` as proposal generator** (the `width ?? proposal.width` reconstruction) | **DISSOLVES.** Fixed dims are allocation properties, not answers. | The spike's frame branch: 12 lines, no proposal variable, reproduces all four fixed-frame corpus cases AND both frame divergences (#4, #6). |
| **`ProposedSize.zero` minimum semantics** (A3's degenerate-case machinery) | **Semantics retire as a negotiation rule; the query context survives as an option.** `.zero` stops being a special case a container *must* interpret during negotiation and becomes an explicit tool the allocator uses when IT decides to compress. The A3 pinned HStack-at-zero "documented consequence" paragraph collapses entirely. | The corpus never exercises `.zero` (harness widths all positive) — not corpus-observable, but the spike's allocator contains NO special-casing for it and reproduces every width behavior it exercised. `Text`'s minimum facts stay available through the same query. |
| **"Offer, not a bound" / `overrule`-as-authority** (the child overruling measurement) | **Reshaped, not lost.** Queries stay honest (never clamped — `ViewOutput`'s-overflow signal survives), but a query answer no longer binds a container. The *observable* class of "child overrules the offer" ONLY survives as report-vs-allocation divergence; the engine's own assigned-vs-proposed duality (the root render case) disappears. | Divergence #9 (clipped frame) reproduced with the child's reported size overruled nowhere — the clip reserves by rule. Corpus #5/#6 wrap cases reproduce with `Text` wrapping at its ALLOCATED width rather than at a proposal value. |
| **`distributedMainAxis` / `_flexibility` leftover smuggling** | **BECOMES UNNECESSARY AS A PROTOCOL SMUGGLE.** Leftover distribution becomes a container-internal rule (the same math). | Fill-in-HStack probe: the walker's fill claims leftover *inside the stack* — a place today's engine cannot express it (Fill answers a width proposal that HStack never makes; the engine measured that stack 1×1). |
| **Two-pass (fit then render)** | **TRANSLATES, weakened.** A sizing pass is still needed (renderer buffer height policy; `ClipView`'s mask), but it is pure query with no authority — no `proposal` correctness obligation between passes. | The spike has `predictedOccupied` (pure, non-binding) + `allocate` (render). No echo/value-equality machinery is needed to keep them consistent. |
| **`_childViews()` transparency / structural flattening** | **TRANSLATES DIRECTLY.** | The spike enumerates flattened tree children per container exactly like the engine; corpus `for`-loop/`if`/`if-else` cases (4 of them) all reproduce. |
| **Buffer write policy (inline truncate / alt wrap) + suffix clamp** | **TRANSLATES DIRECTLY (renderer-owned, untouched).** | The spike retains the same buffer policy and the same content-height buffer-sizing path. |

### Bottom-up's rent (all grounded)

1. **The whole A0 SPI break + echo test apparatus** was rent collected by the
   fit/render *dual bookkeeping* of `size:`/`proposal:`. Top-down assigns
   rects; one value type, no contract, no echo views in two targets.
2. **`FrameView`'s generator protocol story** (answer-verbatim +
   reconstruct-proposal) reduced to two allocation rules.
3. **The A3 zero-paragraph**, the HStack-at-zero "documented consequence" pin,
   and the "no special-casing" contortion — replaced by typed rules with no
   zero special-casing at all.
4. **`Fill`/`FlexibleSpacer` semantics expressed where they belong** (in the
   container's allocation), including one case the engine cannot express
   today (`Fill` under an HStack — the only probe where the *measured sizes*
   differ visibly; rows agree).
5. **Text-wrapping-in-stacks ambiguity resolved to intent**: "wrap at the
   width you were ALLOCATED" is a defensible spec sentence; today's spec
   sentence is "wrap at whatever a proposal happens to reach you" — which is
   what spawns propositions like the Stage-C "consider proposing remaining
   width to HStack children" candidate. Top-down makes the current answer a
   statement about allocation, and lets the future change (if the owner
   wants it) be a change to one rule.

### Top-down costs (honest)

1. **A new SPI shape.** `_embed(into:at:)` replaces `_render(into:at:size:
   proposal:)`, and a container-dispatch hook (visited or marker protocol) is
   REQUIRED — the spike's `Mirror` probe is unacceptable in production and a
   substituted SPI is a breaking change for custom containers/conformers
   (Stage-C `ModifiedContent` wrappers especially). The blast radius is
   moderate but real; see §5.
2. **Stack occupancy is a DESIGN decision in a top-down world.** The corpus
   is silent on "does a stack occupy the full assigned rect or shrink-wrap?"
   — the walker (and today's engine, in effect) shrink-wraps; a top-down
   spec might fill. Deciding is the owner's call; whichever, the parity
   corpus must GROW to pin it (corpus additions would be needed).
3. **Stretch semantics (allocated MORE).** Today NOTHING stretches children
   geometrically except leftover-share spacers and Fill; a top-down engine
   COULD define stretch-by-type (e.g. `Text` stretching to the allocated
   width). The spike deliberately did not. Any stretch rule = pin changes =
   corpus additions. The conservative choice (as today) reproduces
   everything; that's what the spike encodes.
4. **`_sizeThatFits` semantics must be re-documented as a query**, because a
   `ViewSize` answer still leaks through the SPI as a custom-conformer
   "want" — this re-documentation is a Docs task, but a real one: the
   "offer-not-bound" framing that the docs currently sell must be rewritten
   (the semantics are the same; the *authority story* changes).
5. **Not corpus-settleable:** painter-order/overlap under clip (corpus only
   has one clip case), dynamic resize (corpus is snapshot-only), alt-screen
   integration, `println` interplay, and any future `AnyView`/identity work.
   Those are exactly the today-parity risks the phase-2 movers hit — treat
   them as corpus GROWTH work, not as blockers.

---

## 5. Migration sketch (phase 4, effort + risks)

**Approach: same discipline as phase 2 — engine-side, corpus oracle, one
PR-sized slice at a time.**

- **4.0 — SPI shape (foundation).** Add `_embed(into:at:)` (default
  delegating to today's `_render` with the widened interpretation), keep
  `_sizeThatFits`/`_flexibility`/`_childViews` unchanged, introduce the
  container-dispatch hook replacing the spike's `Mirror` probe. **No
  behavior change anywhere**; suites green, corpus untouched. Effort: 1 PR.
- **4.1 — Allocator kernel in Chai.** Port the spike's
  `SpikeRect`/`stackShape`/`frameShape`/allocation rules into production
  types (`Layout/`), side-by-side with today's `_render` implementations
  (they can coexist; the renderer still uses the old path). Unit tests on
  the allocator against the corpus *without* flipping anything. Effort: 1–2
  PRs; the spike's corpus copy is the seed for pins.
- **4.2 — Renderer flip.** `Renderer.flush` proposes/allocates the ROOT rect,
  calls root._embed, retains buffer policy + suffix clamp — byte-identical
  inline/alt-screen semantics (corpus + all `Renderer*Tests` stay green
  unmodified; expect the ProposalEcho renderer tests to be RE-PINNED to the
  rect contract rather than dropped silently). Effort: 1 PR — this is the
  spike-validated "everything reproduces" point.
- **4.3 — Stage-C overlap work (modifiers, eager retirement,
  `Spacer` rename, fill/stretch spec) continues, re-skimmed:** Stage-C's
  `ModifiedContent` wrappers become leaf-like views that ALLOCATE an inner
  rect inset by borders/padding — arguably SIMPLER top-down than
  proposal-forwarding. Nothing in Stage-C's plan needs redesign, though the
  `_render`–to-`_embed` rename touches each wrapper.
- **4.4 — Docs & deletion.** ARCHITECTURE.md "The Layout Engine" rewrite
  (rect-first), Remove `ViewOutput.frame` ambiguity (already a Stage-C
  target), and rewrite UPGRADE.md's phase-2 Architectural "fit/render
  value-equality" + "proposal semantics" sections to the query/rect story.

Total: roughly 5–6 PR-sized slices, smaller than phase 2 (no builders/tree
work, no eager-path parity dilemma — the corpus already carries the
divergences and the top-down walker matched the ENGINE on all 38). The
production surface touched: `View.swift`, `LayoutTypes.swift` (add a rect
type), `Stacks.swift`, `Frame.swift`, `Clip.swift`, `Renderer.flush`, plus
the leaf `_render`→`_embed` rename across ~6 conformers. The parity corpus
pins are expected to hold unchanged (spike evidence); the sweep to change
them should be zero-up unless an owner-decided spec delta (stretch/fill/rule
changes) is folded into phase 4.

**Risks to flag to the owner:**

1. `_sizeThatFits`'s doc story must change ("offer" → "report"); custom
   conformers in the wild (Spices users) rely on the *semantics staying the
   same at the query level* — which the spike shows is stable.
2. The container-dispatch SPI decision (visited protocol vs marker property)
   is an API-shape decision worth pinning FIRST (it constrains fold-order for
   Stage-C wrappers).
3. `Fill`-in-HStack's measured-size change (1 vs 8) is INVISIBLE at
   visibleRows level but visible to any parent-aligning math around such a
   tree; one corpus addition (a width-context case) would pin it either way.
4. Anything not corpus-shaped: rendering-order/painter semantics, dynamic
   resize, alt-screen/`println` integration, `AnyView`-forward work — corpus
   growth now, not later.

---

## 6. Recommendation

**Proceed — but as the hybrid.** The evidence says:

- The traversal shape the owner describes is NOT just implementable; it is
  implementable **over the existing SPI kernels** with all 38 corpus cases
  reproducing exactly. No contract machinery, no proposal bookkeeping. The
  engine's hardest inherited constraints (A0 value-equality, `FrameView`
  the generator, the zero-paragraph) dissolve under typed allocation rules
  — each verified by the corpus, not by hope.
- BUT the counter-nuance is also empirically validated: `_sizeThatFits`
  continues doing the heavy lifting as a pure query, `_flexibility`
  survives, the sizing pass survives (renderer buffer policy + clip
  reservation), and the two-pass SHAPE (query pass + render pass) is
  actually still there — it's the two-pass *authority* that dies. A pure
  "single-traversal, no-second-pass" phase 4 would actually be a WALK-BACK
  to recomputing everything blindly in one pass, with re-measure costs
  hiding inside it.
- So the phase-4 lens is: **children report; parents decide; queries stay
  pure; allocation is the new authority.** Concretely: adopt
  `_embed(into:at:)` + the allocator kernel + typed rules, keep
  `_sizeThatFits`/`_flexibility`, keep the corpus discipline, and go through
  the 5–6-slice migration sketch in §5.

**Decisions the owner should make explicitly before kickoff:**

1. **Stack occupancy at width: shrink-wrap (today's effective rule, spike's
   rule, "children decide" in disguise) vs fill-the-rect (Ratatui-style)?**
   Determines several later rules. Then pin it with corpus additions.
2. **Stretch: does any leaf type stretch to its allocated rect?** The spike
   says "no" (conservative, corpus-green); Ratatui/SwiftUI-style would
   differ. If yes — which leaves, and it becomes a corpus addition.
3. **The container-dispatch SPI for containers**: visitor/`_accept` vs a
   `_layoutPolicy` marker — driven by Stage-C's `ModifiedContent` wrappers.
4. **The compression floor**: add the (one-line) allocator rule that
   clamps allocated width to `Text`'s minimum (query at `.zero`) — today's
   engine silently drops a wide char in a one-column rect. It's a corpus
   add, not a breakage — but is a win caught in passing (the spike chose to
   reproduce the loss; one-line delta upon request).
5. **Do `_render(into:at:size:proposal:)` and `_embed` coexist perma- or
   is the rename a single clean break** (pre-alpha, so probably clean)?
