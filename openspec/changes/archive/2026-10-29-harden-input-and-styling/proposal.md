# Proposal

## Why

A full-repository audit found one silent correctness bug, two places where the
behavior contract and the implementation disagree, and several gaps against the
repository's own contribution rules. Linux-console function keys are listed in
the parser's lookup table but can never match, so F1–F5 arrive as literal
letters. Strings containing ANSI bytes are rejected only by a debug assertion
that disappears in release builds. Extended underline style and underline color
work through `Style.render` but are dropped when the same `Style` is applied to
a view. Alongside these, library code contains force-unwraps, the input reader
finishes a stream twice and closes descriptors under a live `select`, and the
architecture documents describe test counts and a deprecation that no longer
exist.

These are behavior contracts, not just code defects, so they must be specified
before they are fixed. The pre-alpha policy applies: no published API signatures
change, so nothing in this change is **BREAKING**.

## What Changes

- **Terminal input decoding.** Linux-console function keys (`ESC[[A` through
  `ESC[[E`) decode to F1–F5 instead of leaking the trailing letter as text.
  The change also records the decoding rules the parser already implements —
  named control characters taking precedence over the generic Ctrl range,
  incomplete sequences being held when more data may follow, and multi-byte
  UTF-8 runs grouping into a single key message — in a new capability.
- **ANSI text in view content.** A string handed to the view layer is sanitized
  at that boundary: complete ANSI escape sequences are removed before the text
  reaches measurement or painting, in debug and release builds alike. The
  debug-only assertion is retired in favor of the defined behavior.
- **Extended underline decoration.** `Style.underlineStyle(_:)` and
  `Style.underlineColor(_:)` are carried as structured cell metadata, so a view
  painted with `.styled(...)` produces the same underline as the equivalent
  inline `Style.styledText(...)` and as `Style.render`.
- **Color capability detection.** `COLORTERM` values are matched
  case-insensitively, so terminals that report `TrueColor` are detected as
  24-bit capable instead of falling back to 16 colors.
- **Hygiene, no observable behavior change.** Remove the two force-unwraps in
  library code, make the input reader thread the sole finisher of its stream,
  close the cancellation descriptors only after the reader thread exits, delete
  unused ANSI constants and dead parser branches, document `Program.run()` as a
  single-use entry point, and correct the stale test counts, warning note, and
  `Progress.viewAs(_:)` statements in `ARCHITECTURE.md` and `AGENTS.md`.

### Non-goals

- Mouse input, bracketed paste, and focus reporting. Their unused ANSI
  constants are removed; decoding those events is a separate capability.
- Any change to layout, measurement, allocation, or the hard-box contract.
- Any change to `Spices`, the `GroceryList` example, or the public API's
  signatures.
- New dependencies or a change to the minimum toolchain.

## Capabilities

### New Capabilities

- `terminal-input`: how raw bytes from the terminal are decoded into key
  messages — control characters, UTF-8 text, CSI, SS3, and Linux-console
  function-key encodings — and how incomplete input is handled.

### Modified Capabilities

- `view-api`: ANSI-encoded text is sanitized at the view-content boundary
  rather than being accepted as literal characters or rejected only in debug
  builds.
- `view-styling`: extended underline style and underline color are carried
  structurally and survive the view-modifier path; color capability detection
  matches `COLORTERM` case-insensitively.

## Impact

- **Chai runtime:** `Terminal/InputParser.swift`, `Terminal/InputReader.swift`,
  `Terminal/ANSICodes.swift`, `Core/ViewOutput.swift`, `Renderer/StyledText.swift`,
  `Renderer/Cell.swift`, `Renderer/CellBuffer.swift`, `Renderer/Renderer.swift`,
  `Style/Style+TextAttributes.swift`, `Style/StyledView.swift`,
  `Style/ColorProfile.swift`, `Core/MessageChannel.swift`, `Core/Program.swift`.
- **Tests:** `Tests/ChaiTests/InputParserTests.swift`, `CellTests.swift`,
  `RendererTests.swift`, `StyledTextTests.swift`, `ProgramTests.swift`;
  `Tests/ChaiViewTests/StyledViewTests.swift`,
  `StyledViewParityTests.swift`, `UnderlineStyleTests.swift`,
  `ColorTests.swift`.
- **Documentation:** `ARCHITECTURE.md` (test counts, warning note),
  `AGENTS.md` (removed symbol), DocC comments on `ViewOutput`, `Cell`,
  `TextAttributes`, and `Program.run()`.
- **Dependencies:** none added or removed.
