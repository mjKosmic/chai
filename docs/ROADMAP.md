# Chai Roadmap — High-Impact Improvements

**Status:** Draft · **Last updated:** 2026-10-29 · **Scope:** Chai (this repository)

This roadmap turns the Chai vs. SwifTeaUI comparison into a sequenced set of
improvements. It favors work that either removes an adoption blocker, closes a
correctness or operational gap, or increases day-to-day developer leverage
without weakening Chai's architectural advantages.

Each change becomes an OpenSpec change (`/opsx-propose`) before
implementation. This document is a planning artifact, not a behavior spec.

---

## North Star

Make Chai the most trustworthy Swift TUI foundation: predictable layout,
correct terminal behavior, strict concurrency, and a batteries-included
component layer — without runtime dependencies or view identity/diffing.

## What we are protecting

These are Chai's current advantages. The roadmap must not regress them:

- The top-down allocation engine and the hard-box contract
  (`_measure` reports, `_embed` allocates, painting is clipped to the rect).
- The cell-buffer renderer with per-cell diffing.
- The actor-based renderer and `Sendable` model/view model.
- Zero runtime dependencies.
- The parity corpus as the mechanical layout spec.
- The OpenSpec workflow and the zero-warning production build.

## Guardrails / non-goals

- **No runtime dependencies.** Swift stdlib, Foundation, and POSIX only.
- **Value semantics for application state.** No SwiftUI-style hidden
  reference storage in the core API.
- **No view identity or structural view diffing.** Full-frame layout at
  terminal frame rates is a deliberate simplification; treat identity work as
  separate scope creep.
- **No global runtime.** Programs stay instance-scoped.
- **No feature parity for its own sake.** Prefer terminal correctness,
  accessibility, and developer leverage over matching another framework's
  surface area.

---

## Prioritization model

- **Impact (1–5):** user-visible value, adoption leverage, or risk reduction.
- **Effort (1–5):** 1 ≈ days; 5 ≈ multi-week design + implementation + tests.
- **Priority:** P0 = release blocker; P1 = next; P2 = planned; P3 = opportunistic.

Every initiative must ship with tests, keep `swift test` green, and keep the
production targets warning-free.

---

## Roadmap at a glance

| ID | Initiative | Why it matters | Impact | Effort | Priority |
|----|------------|----------------|:------:|:------:|:--------:|
| R1 | Add a license | No `LICENSE` file is a legal adoption blocker | 5 | 1 | P0 |
| R2 | CI on macOS + Linux | The Linux support claim is currently unverified; regressions land silently | 5 | 2 | P0 |
| R3 | Release metadata and SemVer | Tags, changelog, and a version policy make the package installable and trustworthy | 4 | 1 | P0 |
| R4 | Clear the deprecation warnings | Restores a genuinely zero-warning `swift test` gate | 3 | 1 | P0 |
| R5 | Render invalidation and idle throttle | Avoids measuring/embedding every frame when nothing changed | 5 | 3 | P1 |
| R6 | Bracketed paste end-to-end | Real-world input safety; pasted newlines must not fire actions | 4 | 2 | P1 |
| R7 | Signal and lifecycle hardening | Guarantees terminal restoration on every catchable exit path | 5 | 3 | P1 |
| R8 | Behavior specs for core runtime | Only `layout-engine` is specified today; the rest is test-only contract | 4 | 3 | P1 |
| R9 | Performance harness and budgets | Makes performance claims measurable and regression-proof | 3 | 2 | P2 |
| R10 | Focus management primitives | Forms and multi-pane apps need traversal and visible focus | 4 | 3 | P2 |
| R11 | Component gallery and previews | Fast onboarding and discoverability of Spices | 4 | 3 | P2 |
| R12 | Mouse and focus reporting | Completes the terminal capability set | 3 | 3 | P2 |
| R13 | Parser fuzz/property tests | Input parsing is a crash surface; prove it never drops or crashes | 3 | 2 | P2 |
| R14 | Styling and theme ergonomics | Reduces friction on the first screen of code | 3 | 2 | P3 |
| R15 | Overlay, Toast/Modal | App-shell components users otherwise build ad hoc | 3 | 4 | P3 |
| R16 | Layout completeness | HStack remaining-width and viewport measurement contract | 3 | 4 | P3 |
| R17 | Component breadth | Forms, table columns/selection, list sections | 3 | 4 | P3 |
| R18 | Published DocC documentation | API discoverability beyond source comments | 3 | 2 | P3 |
| R19 | 1.0 API audit | Naming, SPI boundaries, deprecations, migration guide | 4 | 3 | P3 |

### If you only do five things

1. **R1 + R2** — license and CI. Nothing else matters if the package is not
   legally adoptable or regressions are invisible.
2. **R5** — render invalidation. It is the largest everyday runtime
   improvement and closes the clearest gap with SwifTeaUI.
3. **R6** — bracketed paste. It prevents a common, user-visible input bug.
4. **R7** — PTY lifecycle and signal hardening. Terminal restoration is a
   trust feature; one bad exit ruins the experience.
5. **R11** — gallery and previews. It converts the component library from
   "documented in source" to "discoverable in one command."

---

## Phase 0 — Make it adoptable (Now)

**Tracked as [`openspec/changes/phase-0-release-hygiene`](../openspec/changes/phase-0-release-hygiene/).**
The `0.1.0` tag is created only after that change merges and the macOS and
Linux CI matrix is green; this roadmap does not claim the release is done.

**Goal:** remove the non-architectural reasons not to use Chai.

### R1 — Add a license

- Add `LICENSE` at the repository root and a license line to `README.md`.
- **Decision:** MIT (adoption-friendly, ecosystem default).

### R2 — CI on macOS and Linux

- GitHub Actions workflow with `macos`, `linux`, and `openspec` jobs:
  - `swift build --build-tests`
  - `swift test`
  - `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`
- Fail on any `warning:` in the build or test logs; there is no allowlist.
- Cache SwiftPM dependencies/builds.
- **Acceptance:** required checks on `main`; the Linux job proves the
  `Glibc` path actually compiles and passes.

### R3 — Release metadata and versioning

- Tag `0.1.0` after this change merges and the CI matrix is green.
- Add `CHANGELOG.md` with the pre-alpha history summarized.
- Document the version policy: `0.x` until the R19 API audit, then SemVer.
- **Acceptance:** `git tag` exists, README installation matches the tag, and
  the changelog links the comparison/roadmap context.

### R4 — Clear the deprecation warnings

- **Complete:** `Progress.viewAs(_:)` was removed and `SpicesTests` calls
  `viewAsStyledText(_:)`; the warning exception is gone.
- **Acceptance met:** `swift test` reports zero warnings on macOS and Linux,
  and AGENTS.md carries no exception.

**Exit criteria for Phase 0:** a new user can legally depend on Chai, CI
proves macOS and Linux, and the warning gate is honest.

---

## Phase 1 — Runtime hardening (Next)

**Goal:** close the operational gaps that appear in real terminal apps.

### R5 — Render invalidation and idle throttle

Today `Renderer.flush()` measures and embeds the tree on every `1/fps` tick,
then skips the write if the diff is empty. That is correct but wasteful on
idle screens.

- Introduce a renderer-owned `needsRender` flag set by:
  `write(_ view:)`, `setCursor(_:)`, resize, `RepaintMsg`, and queued
  `println` lines.
- Return before the measure/embed pass when the flag is clear.
- Treat `.withFPS(n)` as a **maximum cadence**, not a fixed workload.
- Keep explicit repaint paths intact for animations and external changes.
- **Acceptance:**
  - An unchanged 80×24 screen performs no measure/embed work.
  - Spinner/Timer animations still repaint on their messages.
  - Resize, alt-screen entry/exit, cursor moves, and `println` still repaint.
  - New renderer tests pin the skip path; a benchmark records idle CPU.
- **Files:** `Sources/Chai/Renderer/Renderer.swift`,
  `Sources/Chai/Core/Program.swift`.

### R6 — Bracketed paste end-to-end

Bracketed paste is not yet implemented: no code path enables it or parses its
payload. Pasting multi-line text therefore behaves like typed Enter keys.

- Add a `Program.Option` (or default-on with opt-out) for bracketed paste.
- Enable on start and disable on **every** exit path.
- Parse `ESC[200~ … ESC[201~` in `InputParser`/`InputReader`, including
  incomplete sequences across reads.
- Deliver one message per paste (e.g., `PasteMsg` or a `KeyMsg` paste case)
  with UTF-8 validation and a configurable byte cap (recommend 1 MiB).
- **Acceptance:** multi-line paste arrives as one message; a pasted newline
  cannot trigger an `enter` handler; over-cap payloads are rejected or
  truncated deterministically; tests cover empty, UTF-8, and incomplete cases.
- **Files:** `Terminal/InputParser.swift`, `Terminal/InputReader.swift`,
  `Terminal/ANSICodes.swift`, `Core/Program+Options.swift`.

### R7 — Signal and lifecycle hardening

- Handle `SIGHUP` and `SIGQUIT` in addition to `SIGINT`/`SIGTERM`.
- On an external signal: restore terminal state, restore prior dispositions,
  then re-raise the signal so the shell/supervisor sees conventional status.
- Ensure restore runs exactly once across normal quit, `.quit`, thrown errors,
  and signal paths.
- Add a PTY-based lifecycle suite covering:
  - normal quit and typed Ctrl+C
  - `SIGINT`/`SIGTERM`/`SIGHUP`/`SIGQUIT`
  - `SIGWINCH` resize
  - alt-screen enter/exit
  - cursor restore
  - repeated sessions in one process
- **Acceptance:** `stty` and termios state match the pre-launch snapshot after
  every scenario; the suite runs in CI on macOS and Linux.
- **Files:** `Core/Program.swift`, `Terminal/Terminal.swift`,
  `Tests/ChaiTests/ProgramTests.swift`, plus a new PTY harness.

### R8 — Behavior specs for the core runtime

Only `layout-engine` has an OpenSpec capability today; runtime, rendering, and
input behavior live mostly in tests and architecture prose.

- Add capabilities such as `program-runtime`, `terminal-rendering`, and
  `input-handling` (final names decided in the change).
- Specify externally visible behavior: lifecycle, message delivery, command
  execution, diff/repaint guarantees, alt-screen policy, cursor behavior,
  key parsing, paste, and signals.
- Link the capability map in `openspec/README.md` and the relevant sections of
  `ARCHITECTURE.md`.
- **Acceptance:** `openspec validate --all --strict` passes; each new
  requirement has testable scenarios; no implementation detail leaks into
  specs.

**Exit criteria for Phase 1:** a static app consumes no layout work, pasted
text is safe, the terminal is restored on every catchable exit, and core
behavior is specified.

---

## Phase 2 — Terminal breadth and evidence

### R9 — Performance harness and budgets

- Add a small executable or test target that measures:
  - frame build time (measure + embed + diff)
  - bytes written per frame
  - idle CPU on a static screen
  - one-line-change output size
- Record results in CI and fail on regressions beyond a threshold.
- **Acceptance:** a documented baseline, a repeatable command, and at least
  one CI gate for frame-build time and bytes written.

### R10 — Focus management primitives

- Add model-owned focus state and traversal helpers:
  `FocusRing`, `FocusScope`, `.focused(_:)`, forward/backward traversal.
- Support Tab/Shift+Tab routing without hidden global state.
- Add a visible focus style to Spices components.
- **Acceptance:** a form example traverses fields in order, wraps/scopes
  correctly, and restores focus after mutations; tests pin traversal and
  rendering.

### R11 — Component gallery and previews

- Add an `Examples/Gallery` executable that demonstrates every Spices
  component, themes, resizing, and alt-screen behavior.
- Add a preview helper that renders a model/view at a fixed size for tests,
  docs, and screenshots.
- Add snapshot tests for the gallery sections.
- **Acceptance:** `swift run ChaiGallery` works on macOS and Linux; the
  gallery covers every public component; previews are usable from tests.

### R12 — Mouse and focus reporting

- Implement SGR mouse parsing (`ESC[<…M/m`) with coordinates, buttons, and
  modifiers; add `MouseMsg`.
- Add focus-reporting messages and lifecycle enable/disable.
- Keep both opt-in to avoid changing existing input behavior.
- **Acceptance:** click/drag/hover events map to the correct cell; mouse and
  focus state are restored on exit; tests cover boundaries and clipping.

### R13 — Parser fuzz/property tests

- Property-test `InputParser` over arbitrary byte streams:
  - never crashes
  - consumes or holds bytes deterministically
  - never loses bytes across incomplete-sequence boundaries
- Add a bounded fuzz run to CI and a longer local mode.
- **Acceptance:** a documented input corpus plus generated cases pass; any
  counterexample becomes a regression test.

**Exit criteria for Phase 2:** performance is measured, focus and mouse are
usable, and input parsing is provably robust.

---

## Phase 3 — Developer experience

### R14 — Styling and theme ergonomics

- Add chainable text styling that mirrors the styling model without raw ANSI,
  e.g. `Text("Error").fg(.red).bold()`.
- Add a small theme/palette presets layer on top of `Style`/`ColorProfile`.
- Keep `StyledText` as the underlying value type.
- **Acceptance:** the counter/gallery examples use the new modifiers; color
  downsampling still applies; tests cover chained styles.

### R15 — Overlay, Toast/Modal

- `ZStack` overlay container (delivered): participates in the allocation
  engine, shrink-wraps to its largest child, and positions children with a
  combined `Alignment`.
- Remaining: add Toast/Modal/StatusBar components in Spices, built on top of
  `ZStack`.
- **Acceptance:** `ZStack` overlays respect the hard box (delivered);
  Toast/Modal receive focus predictably and restore focus on dismissal.

### R16 — Layout completeness

- Implement the deferred HStack remaining-width allocation candidate.
- Define and test the viewport measurement contract: content may report
  larger than its allocation while painting is clipped.
- Add relevant scenarios to `openspec/specs/layout-engine/spec.md`.
- **Acceptance:** viewport and HStack cases are corpus-pinned; no regression
  in existing allocation rules.

### R17 — Component breadth

- Form controls: Checkbox, Radio, Toggle, Select, Tabs.
- Table: column width policies, selection, focused-row styling.
- List: sections, sticky headers where feasible.
- **Acceptance:** each component is model-driven, tested, and represented in
  the gallery.

### R18 — Published DocC documentation

- Publish DocC to GitHub Pages from CI.
- Add tutorials: first app, layout, styling, components, effects.
- **Acceptance:** docs build in CI with no warnings; public API coverage is
  measurable and linked from README.

---

## Phase 4 — 1.0 readiness

### R19 — API audit

- Audit public symbols, SPI boundaries, and naming consistency.
- Remove or deprecate pre-alpha leftovers with a migration guide.
- Freeze SemVer and publish a 1.0 beta.
- **Acceptance:** a documented API review, a migration guide, and a 1.0 beta
  tag.

---

## Success metrics

| Area | Target |
|------|--------|
| Build health | `swift test` green, zero warnings on macOS and Linux |
| Idle efficiency | < 1% CPU on a static 80×24 screen at the FPS cap |
| Frame latency | p95 frame build < 16 ms on the gallery fixture |
| Diff efficiency | a one-line change writes < 1 KB |
| Lifecycle | PTY suite green on macOS and Linux for every catchable exit |
| Input robustness | bounded fuzz run with no crash or byte loss |
| Onboarding | time-to-first-app < 10 minutes from README |
| API docs | > 90% public-symbol DocC coverage |
| Stability | 1.0 API audit complete, SemVer policy published |

---

## Decision log

| Decision | Status | Notes |
|----------|--------|-------|
| License | **Open** | MIT recommended; Apache-2.0 if patent grant matters |
| CI provider | Proposed | GitHub Actions, macOS + Linux jobs |
| Versioning | Proposed | `0.x` until R19; SemVer afterward |
| Paste default | **Open** | Recommend default-on with opt-out for safety; decide in the change |
| Mouse default | Proposed | Opt-in |
| View identity | Decided | Out of scope; do not add |
| Global runtime | Decided | Out of scope; keep `Program` instance-scoped |

---

## First OpenSpec changes

Phase 0 hygiene is tracked as `phase-0-release-hygiene`; it has no observable
behavior delta and uses `skip_specs: true`. The first behavior changes are:

1. `render-invalidation` — R5.
2. `bracketed-paste` — R6.
3. `terminal-lifecycle-signals` — R7.

Every roadmap initiative starts as an OpenSpec change; there are no
direct-to-`main` edits.

---

## How to execute

All work follows the mandatory OpenSpec workflow
([`../AGENTS.md`](../AGENTS.md),
[`../openspec/README.md`](../openspec/README.md)): propose → review → apply →
archive → merge, inside a single pull request. Behavior work carries a delta
spec; pure refactor, tooling, or documentation work sets `skip_specs: true`.

1. Create the OpenSpec change with `/opsx-propose`.
2. Write the delta spec first; add scenarios for the acceptance criteria above.
3. Implement from `tasks.md`, checking off work as it lands.
4. Keep `swift test` green and the parity corpus untouched unless the layout
   contract intentionally changes.
5. Archive the change inside the same PR before merge: run `/opsx-archive` so
   the delta merges and the change folder moves to `archive/`.
6. Merge the pull request after the archive commit is in it. Direct pushes to
   `main` are prohibited.
