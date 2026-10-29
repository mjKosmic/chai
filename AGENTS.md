# Chai — Agent Contribution Guide

This document tells AI agents how to build, test, and contribute to Chai.
Read `ARCHITECTURE.md` for a full explanation of how the framework works.

---

## Build & Test

```bash
# Build the library and example
swift build

# Run all tests (must pass with zero warnings)
swift test

# Build + test in one shot
swift build && swift test
```

The package uses `swift-tools-version: 6.1`, so the minimum toolchain is **Swift 6.1+** (macOS 14+).
There are no runtime dependencies — do not add any. (`swift-docc-plugin` is declared for build-time DocC generation only.)

---

## Spec-Driven Development (OpenSpec) — Mandatory

**Every change to this repository MUST go through OpenSpec** — features, bug
fixes, refactors, tests, documentation, CI, and release/tooling work. There are
no direct-to-`main` edits. The lifecycle is **propose → review → apply →
archive**:

- Start with `openspec new change <name>` (or `/opsx-propose` in OpenCode,
  `/opsx:propose` in Claude Code).
- Any observable behavior change MUST include a delta spec in the change.
  Specs live in `openspec/specs/<capability>/spec.md` and are the source of
  truth for current behavior.
- A pure refactor, tooling, or documentation change with no observable
  behavior delta MUST set `skip_specs: true` in `.openspec.yaml`; do not invent
  a requirement just to satisfy validation.
- Implement from `tasks.md` and check tasks off as they land.
- Archive the change **inside the same pull request**: run `/opsx-archive` on
  the branch after tasks and validation pass, then merge the PR with the
  implementation, spec merge, and archive move together. Never push directly
  to `main`.
- Validate with `npx -y @fission-ai/openspec@1.15.0 validate --all --strict`.

The canonical artifact layout, capability map, and enforcement rules are in
[`openspec/README.md`](openspec/README.md). `ARCHITECTURE.md` remains the design
of record and `docs/history/VIEW-LAYER-MIGRATION-LOG.md` the migration log.
Keep implementation detail out of specs; specs describe behavior.

### Required CI checks

`.github/workflows/ci.yml` runs the `macos`, `linux`, and `openspec` jobs.
`main` requires all three checks and a pull request; direct pushes to `main`
are not allowed. The `openspec` job runs
`npx -y @fission-ai/openspec@1.15.0 validate --all --strict`. Reviewers must
reject changes without an OpenSpec change.

---

## Repository Layout

```
Sources/Chai/
  Core/        Model.swift  Message.swift  Command.swift  Program.swift  Program+Options.swift
               View.swift  AnyView.swift  ViewBuilder.swift  StructuralViews.swift  ViewOutput.swift
               LayoutTypes.swift  Cursor.swift  Logger.swift  MessageChannel.swift
  Terminal/    ANSICodes.swift  Terminal.swift  InputReader.swift  InputParser.swift
  Renderer/    Renderer.swift  StyledText.swift  CellBuffer.swift  Cell.swift  DisplayWidth.swift  Wrapping.swift
  Layout/      Stacks.swift  Frame.swift  PaddingView.swift  BorderView.swift
               CompositionWrappers.swift  Alignment.swift  Border.swift
  Style/       Style.swift  Style+TextAttributes.swift  Color.swift  ColorProfile.swift
               ColorPalette.swift  ColorUtilities.swift
  Utilities/   TabExpansion.swift
Sources/Spices/   Ready-made components (Menu, SelectableList, TextInput, ...)
Tests/ChaiTests/  ChaiViewTests/  SpicesTests/
  ChaiViewTests/LayoutParity/   corpus + engine spec suites (the parity discipline)
Examples/GroceryList/Sources/main.swift   the acceptance example (centers via .frame(...))
openspec/specs/    behavior specs (source of truth, by capability)
openspec/changes/ active proposals + archive/ for completed changes
```

The layout engine lives across the seam: value types and the `View` SPI
(`_measure(in:)`/`_embed`/`_childViews`/`_flexibility`) are in `Chai/Core/{LayoutTypes,View}.swift`,
the containers in `Chai/Layout/{Stacks,Frame}.swift`, and the renderer flip in
`Chai/Renderer/Renderer.swift`. The SPI is public because custom containers are
a supported extension point; the built-in containers are one consumer. See
`ARCHITECTURE.md` → "The Layout Engine".

---

## Coding Rules

- **Zero external dependencies.** Only Swift stdlib, Foundation, and POSIX APIs.
- **`StrictConcurrency` is enabled.** Every type that crosses a concurrency boundary must be `Sendable`. Production and test targets must build with zero warnings; there is no warning allowlist.
- **No force-unwraps, no `try!`, no `fatalError` in library code.**
- **Value semantics for state.** Application models are `struct`s. Do not introduce classes into the public API without a strong reason.
- **Internal types stay internal.** Do not make implementation details `public` unless they are genuinely part of the user-facing API.
- **Comments describe current behavior.** Do not put phase names, milestone labels, PR numbers, or migration history in source or test comments; keep that evolution in the OpenSpec archive or `docs/history/`.
- **Tests are required.** Every new feature or bug fix must include tests. Use Swift Testing (`@Test`, `#expect`). All existing tests must continue to pass.

---

## Adding a New Feature

1. **New message type** — add a `public struct` conforming to `Message` in `Message.swift`.
2. **New command** — add a case to the `Command` enum in `Command.swift` and handle it in `ProgramRunner.execute(_:)` in `Program.swift`.
3. **New ANSI sequence** — add a constant or factory function to the `ANSI` enum in `ANSICodes.swift`.
4. **New key** — add a case to `KeyType` in `Message.swift`, then add the escape sequence mapping to `InputParser.csiTable` or `InputParser.ss3Table`.
5. **New `Program.Option`** — add a case to the `Option` enum in `Program+Options.swift`, then handle it in `ProgramRunner.run()` (startup behaviour) or `ProgramRunner.init` (construction-time configuration such as FPS/logging).

---

## Pitfalls & Nuances

### Named control characters must be matched before the generic Ctrl range
In `InputParser.parseOne`, `0x09` (Tab/Ctrl+I) and `0x0D` (Enter/Ctrl+M) are matched in the named-character `switch` **before** the generic `0x01–0x1A` range. If you add new byte handlers, preserve this ordering or Tab and Enter will be misreported as `ctrl("i")` and `ctrl("m")`.

### `termios.c_cc` cannot be indexed directly in Swift
The `c_cc` field is a fixed-size C tuple. Access it via:
```swift
withUnsafeMutableBytes(of: &t.c_cc) { ptr in
    ptr[Int(VMIN)]  = 1
    ptr[Int(VTIME)] = 0
}
```
Do not attempt direct tuple indexing — it does not compile.

### Never block the Swift cooperative thread pool
`read(2)` on a TTY is blocking. `InputReader` runs it on a dedicated `Thread`, not a `Task`. If you add any other blocking I/O, follow the same pattern. Blocking inside a `Task` will stall the thread pool.

### `Renderer` is an actor — all calls from outside must be `await`ed
`Renderer` serialises its state through Swift's actor model. Calling renderer methods from `ProgramRunner` (which is not actor-isolated) requires `await`. Do not add locks or `nonisolated` workarounds.

### `TerminalOutput` is the testability seam
`Renderer` depends on the `TerminalOutput` protocol, not `Terminal` directly. Tests inject the test-local `MockTerminal` that captures output. When writing renderer tests, use this mock — never instantiate a real `Terminal`.

### `canHaveMoreData` controls incomplete-sequence handling
`InputParser.parse(buffer:canHaveMoreData:)` takes a flag that is `true` when the read filled the entire buffer (more bytes may be waiting). When `true`, the parser holds back incomplete escape sequences rather than emitting `.unknown`. Always pass this flag correctly; getting it wrong causes spurious `.unknown` keys or dropped sequences.

### `WindowResizeSignalMsg` is an internal sentinel — the model never sees it
`SignalHandler` cannot access `Terminal`, so it sends `WindowResizeSignalMsg` when `SIGWINCH` fires. `ProgramRunner.handleRendererMessage` intercepts it, queries `terminal.size()`, and sends the real `WindowSizeMsg` to the model. Do not expose `WindowResizeSignalMsg` publicly or deliver it to `model.update`.

### `defer` guarantees terminal restoration
`ProgramRunner.run()` calls `terminal.disableRawMode()` inside a `defer` block. This ensures the terminal is always restored even if an error is thrown mid-run. Do not remove or move this `defer`.

### `Program.run()` returns the final model state
`run()` is `@discardableResult` and returns `M`. This is useful for testing and for programs that want to inspect state after exit. Preserve this return value when modifying `ProgramRunner.run()`.

### Engine pitfalls (phase-2/4/5 hard-won rules)

1. **Layout operates on child *views*, never on resolved outputs.** Containers must enumerate children via `_childViews()` and call `_measure(in:)` (query) / `_embed` (allocation) on the *views*. The first engine attempt resolved children to `ViewOutput` before measurement — that flattens the tree, bypasses every child's layout overrides, and makes assignment meaningless; it was reverted. Do not reintroduce output-based layout.
2. **Allocation is the contract — and the box (phase 5).** The rect passed to a child's `_embed(into:at:)` **is** the parent's decision and its painting bound. Consequences: (a) `_measure(in:)` is a **pure report** — never treat an answer as binding; a container may overrule it (Fill-by-type, the Text floor); (b) containers must allocate child rects from their own rules and query context, clamped to their own rect, never by re-measuring with a remembered query value (there is none); (c) containers must embed children via `buffer.embed(child, at: rect)`, never `child._embed(into:&buffer,...)` directly — the helper installs the kernel clip that guarantees no paint escapes the rect; (d) `_embed` must not depend on `body` for containers. The test-local `RectEchoView` pins that children observe their *allocated* rect; `HardBoxTests` pins containment. Do not reintroduce query bookkeeping or unclipped child embeds.
3. **The corpus is the engine spec; allocation is the contract.** The eager `_resolveToViewOutput()` path was deleted in P4b, so there is no second renderer: `ParityCorpus` pins one `expectedRows` per case, and every engine change must keep the corpus green — no case is ever skipped. The rect handed to `_embed(into:at:)` is the parent's decision; `_measure(in:)` is a pure report, never binding.
4. **Test-target warnings count against the zero-warning rule.** `swift build` alone does not compile tests. The gate is `swift test` (or `swift build --build-tests`) and zero warnings includes test targets. There is no warning allowlist; `Progress.viewAs(_:)` is deprecated and tests use `viewAsStyledText(_:)`.
