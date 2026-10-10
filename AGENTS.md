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

The only Swift toolchain requirement is **Swift 5.9+** (macOS 14+).
There are no external dependencies — do not add any.

---

## Repository Layout

```
Sources/Chai/
  Core/        Model.swift  Message.swift  Command.swift  Program.swift
               View.swift  ViewBuilder.swift  StructuralViews.swift  ViewOutput.swift
  Terminal/    ANSICodes.swift  Terminal.swift  InputReader.swift  InputParser.swift
  Renderer/    Renderer.swift  StyledText.swift  CellBuffer.swift  Cell.swift
Sources/Latte/    Layout, styling, borders, composition (Stacks.swift, ViewOutput+Layout.swift)
Sources/Spices/   Ready-made components (Menu, SelectableList, TextInput, ...)
Tests/ChaiTests/  LatteTests/  SpicesTests/
Examples/GroceryList/Sources/main.swift
```

---

## Coding Rules

- **Zero external dependencies.** Only Swift stdlib, Foundation, and POSIX APIs.
- **`StrictConcurrency` is enabled.** Every type that crosses a concurrency boundary must be `Sendable`. The build must produce zero warnings.
- **No force-unwraps, no `try!`, no `fatalError` in library code.**
- **Value semantics for state.** Application models are `struct`s. Do not introduce classes into the public API without a strong reason.
- **Internal types stay internal.** Do not make implementation details `public` unless they are genuinely part of the user-facing API.
- **Tests are required.** Every new feature or bug fix must include tests. Use Swift Testing (`@Test`, `#expect`). All existing tests must continue to pass.

---

## Adding a New Feature

1. **New message type** — add a `public struct` conforming to `Message` in `Message.swift`.
2. **New command** — add a case to the `Command` enum in `Command.swift` and handle it in `ProgramRunner.execute(_:)` in `Program.swift`.
3. **New ANSI sequence** — add a constant or factory function to the `ANSI` enum in `ANSICodes.swift`.
4. **New key** — add a case to `KeyType` in `Message.swift`, then add the escape sequence mapping to `InputParser.csiTable` or `InputParser.ss3Table`.
5. **New `ProgramOption`** — add a case to `ProgramOption` in `Program.swift` and handle it in `ProgramRunner.run()`.

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
`Renderer` depends on the `TerminalOutput` protocol, not `Terminal` directly. Tests inject a `MockTerminalOutput` that captures output. When writing renderer tests, use this mock — never instantiate a real `Terminal`.

### `canHaveMoreData` controls incomplete-sequence handling
`InputParser.parse(buffer:canHaveMoreData:)` takes a flag that is `true` when the read filled the entire buffer (more bytes may be waiting). When `true`, the parser holds back incomplete escape sequences rather than emitting `.unknown`. Always pass this flag correctly; getting it wrong causes spurious `.unknown` keys or dropped sequences.

### `WindowResizeSignalMsg` is an internal sentinel — the model never sees it
`SignalHandler` cannot access `Terminal`, so it sends `WindowResizeSignalMsg` when `SIGWINCH` fires. `ProgramRunner.handleRendererMessage` intercepts it, queries `terminal.size()`, and sends the real `WindowSizeMsg` to the model. Do not expose `WindowResizeSignalMsg` publicly or deliver it to `model.update`.

### `defer` guarantees terminal restoration
`ProgramRunner.run()` calls `terminal.disableRawMode()` inside a `defer` block. This ensures the terminal is always restored even if an error is thrown mid-run. Do not remove or move this `defer`.

### `Program.run()` returns the final model state
`run()` is `@discardableResult` and returns `M`. This is useful for testing and for programs that want to inspect state after exit. Preserve this return value when modifying `ProgramRunner.run()`.
