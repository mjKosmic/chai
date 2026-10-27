# Design

> **Archived design record.** This document was the phase-4 kickoff handoff.
> It was moved here on 2026-10-27, after the phase landed, to preserve the design
> evidence of record. Phase 5 later strengthened the allocated rect into a hard
> painting box; the current behavior contract lives in
> `openspec/specs/layout-engine/spec.md` and the design of record remains
> `ARCHITECTURE.md`.

---

# Handoff — Phase 4: Top-Down Allocation Engine (historical kickoff)

> **Status (later): this is the phase-4 *kickoff* handoff and is historical.**
> P0–P3 have since landed on `fixing` (PR #22). The plan of record, current
> status, allocation deltas, and the remaining milestones (P4/PB/PD) are in
> `UPGRADE.md` → "Phase 4 — Top-down allocation engine"; the pickup notes for
> those milestones are in its "Pickup notes for the remaining milestones"
> subsection. The five owner decisions below were settled at P0.
>
> The SPI was later renamed (post-phase-5): `ProposedSize` → `AvailableSize`,
> `_sizeThatFits` → `_measure(in:)`, `.unspecified` → `.unconstrained`. The old
> names in this document are the API as it was at kickoff.

**Date:** Oct 2026 · **State at kickoff:** phase 3 Stage A merged (PR #21, `f8a15a7`); a design
spike validated the direction; the five owner decisions were pending. They were
settled at P0 (see `UPGRADE.md`), and P1–P3 are now landed.

---

## The strategic thread (why phase 4 is on the table)

The owner's diagnosis, raised after PR #21: **the view tree now constructs its
size and layout bottom-up** — every view owns its size (`_sizeThatFits` is
authoritative; proposals are offers that children may overrule) and containers
accommodate child answers. That is SwiftUI's negotiation model. The Elm /
Bubble Tea / Ratatui / Textual pattern is **authoritative top-down**: the root
knows the terminal size (the model has it via `WindowSizeMsg`), carves space
downward, and hands sections explicit allocations. Children report; parents
decide.

Evidence from our own history that the negotiation model was fighting us:

| Friction | What it was |
|---|---|
| A0 fit/render value-equality contract (`_render(into:at:size:proposal:)` SPI break, `ProposalEchoView` ×2 targets, AGENTS pitfall #2) | An entire contract class that exists only because sizing is a negotiation spread across two passes |
| `_flexibility()` SPI + `distributedMainAxis` | Top-down leftover allocation **smuggled into** a bottom-up protocol |
| `FrameView` the "proposal generator" | A size *decision* wearing a negotiation costume |
| `ProposedSize.zero` minimum semantics | A degenerate case of the negotiation channel |
| The 10-entry divergence list | Largely the bottom-up engine reimplementing top-down-ish eager string composition differently |

**The nuance that survived scrutiny (do not lose it):** bottom-up
*measurement* is legitimately needed — content-sized UIs (menus sized to their
longest item, dialogs, stacks as wide as their widest child) are real, and
Ratatui (`Widget::width()`) / lipgloss (`Width()`) query intrinsic sizes too.
The pathology is not the query — it is **measurement-as-authority**. Phase 4
keeps the query kernel; it moves allocation authority to the containers.
"Children report; parents decide."

**Second open thread (from the same discussion): positioning.** Chai's pitch
("inspired by Bubble Tea") vs what it has become (batteries-included, now with
an engine). Three positions were laid out: (a) Bubble Tea-strict minimal
core, (b) **layered** — runtime + string path is the stable core, the engine
is additive and optional-by-construction (recommended), (c) commit to
"SwiftUI for terminals". Whatever is chosen, two guardrails were proposed:
a **simple-path contract** (a tested guarantee that a complete app can be
built with `body: ViewOutput` + strings + Latte helpers, zero engine
concepts) and a **feature freeze** on engine scope (new engine features
need use cases, not SwiftUI symmetry). Fold both into the phase-4 plan
decisions.

---

## The spike (evidence of record)

Artifacts (committed alongside this doc): `TOP-DOWN-SPIKE.md` (full report)
and `Tests/ChaiTests/Spike/` (a ~700-line top-down allocation walker built
entirely over the **current public SPI** — `_childViews()` enumeration,
`_sizeThatFits` used only as an intrinsic query, `_render` as rasterizer,
`_flexibility` as a pure child report; containers identified via `Mirror`,
which is spike-only and needs a real dispatch hook in production.
`SpikeCorpus.swift` is a deliberate duplicate of the parity corpus because
test targets cannot share files).

**Headline result: walker == current engine, bug-for-bug, 38/38 corpus
cases.** Walker == eager: 28/38 — the only deltas are the exact ten
documented divergences, reproduced faithfully. Five hand-probes (vertical
stretch via offered height, non-compressible overflow, wrap-at-allocated-
width, `Fill` inside `HStack`, two-flex sandwich) matched the live engine
byte-identically.

What that proves: **the rearchitecture is feasible with zero user-facing
break** — same API, same corpus, same pins. It is an internals rewrite with
the parity discipline as the oracle, exactly what the corpus was built for.

### What dissolves (spike-grounded)

1. **The A0 fit/render value-equality contract** — the render pass gets a
   rect assignment; the `size:`/`proposal:` duality goes; `ProposalEchoView`
   and the echo tests become obsolete.
2. **`FrameView`-the-generator** — fixed dims become allocations (data), not
   answers; all frame behavior reproduces.
3. **`.zero` minimum negotiation** — compressing becomes a tool the
   allocator applies when it decides to.
4. **Flex moves into the container** — and one case becomes *expressible*
   that today's engine cannot measure: `Fill` under an `HStack`.
5. **`Text` wrap semantics gain an honest sentence** — "wrap at the width
   you were **allocated**" instead of "wrap at whatever proposal reaches you".

### What survives (spike-grounded — do not over-scope phase 4)

- `_sizeThatFits` survives **as the query kernel** (its authority was the
  anti-pattern, not the function).
- `_flexibility()` translates directly.
- A **pure sizing pass** is still needed (buffer height, clip rect
  reservation) — it is the two-pass *authority* that dies, not the second
  pass itself.

### Costs (equally grounded)

- SPI delta: `_embed(into:at:rect:)` replacing `_render(into:at:size:proposal:)`,
  plus a real container-dispatch hook (the `Mirror` probe is spike-only).
- The divergence list does **not** shrink automatically — the walker
  deliberately reproduced today's semantics; reconciling divergences is a
  separate later decision.
- Semantic questions the corpus cannot settle: stack occupancy at width
  (shrink-wrap vs fill), stretch-by-type, dynamic resize / alt-screen /
  painter-order interactions — corpus growth, not blockers.

---

## The five pending owner decisions (with standing recommendations)

| # | Decision | Standing recommendation |
|---|---|---|
| 1 | Stack occupancy at width: shrink-wrap vs fill-the-rect | **Shrink-wrap** (today's effective rule; corpus pins hold; filling is `FlexibleSpacer`/`frame`'s job) |
| 2 | Does any leaf type stretch to its allocated rect? | **No** — leaves render at intrinsic size, top-left in their rect; stretch stays a container decision (preserves all output) |
| 3 | Container-dispatch SPI shape | **Per-conformer allocation methods** (like today's self-implemented `_sizeThatFits`/`_render`) rather than a marker/visitor — fits conventions, keeps Stage C wrappers generic |
| 4 | `Text` compression floor (clamp allocated width to the narrowest producible form) | **Adopt** — one line; prevents the silent single-column CJK character drop the spike caught |
| 5 | Clean break (`_embed` replaces `_render`) vs coexistence | **Clean break** — pre-alpha, matches the A0 precedent |

---

## Recommended path (mirror the phase-2/3 pattern: plan first, then slices)

1. **P0 — plan milestone**: settle the five decisions above (plus the
   positioning guardrails: simple-path contract, feature freeze), write the
   phase-4 section into `UPGRADE.md`, commit. Same rigor as `29b6383` (the
   phase-3 plan commit).
2. **P1 — SPI break**: the allocation kernel (`_embed` + dispatch hook +
   intrinsic-query `_sizeThatFits`), walker graduating out of
   `Tests/ChaiTests/Spike/` into production.
3. **P2 — side-by-side**: the corpus runs through both engines during the
   transition (pins expected to hold unchanged — that is the spike's
   prediction, and the oracle is already in place).
4. **P3 — renderer flip**: the root receives the terminal rect, one
   allocation walk, `flush()` unchanged below the buffer.
5. **P4 — Stage C on the new kernel**: modifier wrappers, eager-path
   retirement, `Spacer` naming unification, the HStack-remaining-width
   candidate (all seeds already in UPGRADE.md "Deferred to phase 3 /
   Stage C"). **Do not build Stage C on the old SPI** — that was the trap
   this spike was started in time to avoid.
6. **Stage B (`AnyView`) re-scopes** on the new kernel: it must forward all
   four SPI methods (`_intrinsicSize`/query kernel, `_embed`, `_childViews`,
   `_flexibility`) — the PR #21 review already flagged `_flexibility`
   forwarding as the silent-failure risk.

Estimated smaller than phase 2: the corpus evidence predicts pins hold.

---

## Standing rules (unchanged, enforced by tests)

- **Parity discipline**: corpus + `visibleRows` + the closed 10-entry
  divergence list; new divergences must be added to UPGRADE.md with
  `isKnownDivergent` + `expectedRows` + `expectedEngineRows`; no corpus case
  is skipped.
- **Zero-warning gate includes test targets** — `swift build` alone does not
  compile tests; use `swift build --build-tests` / `swift test` (only the
  pre-existing SpicesTests `viewAs` deprecations are acceptable).
- **AGENTS.md engine pitfalls** are live rules — pitfall #2 (the value-equality
  contract) **dissolves with phase 4** and must be rewritten for the
  allocation contract.
- ARCHITECTURE.md is the design of record; UPGRADE.md is the migration log and
  plan; the three proposal-semantics sections ("An offer, not a box" etc.)
  will need rewriting for allocation semantics — schedule in the phase-4
  docs slice, and preserve the parts that stay true (the buffer is still the
  only hard wall; overflow semantics).
- `body: ViewOutput` + strings + Latte helpers is a complete, supported path
  (the simple path). Nothing may regress it.

## Baseline

`swift build` / `swift build --build-tests`: zero warnings (beyond the known
SpicesTests `viewAs` deprecations). `swift test`: **1245 tests / 106
suites** (1239/105 production + 6 spike diagnostics).
